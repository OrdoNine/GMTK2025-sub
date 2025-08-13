extends CharacterBody2D
class_name Player

const DAMAGE_STUN_LENGTH := 2.0
const IFRAME_LENGTH := 3.0 # must be longer than stun length
const COYOTE_JUMP_TIME := 0.13

enum PlayerState {
	FREEMOVE, # normal grounded/mid-air movement mode
	WALLSLIDE, # currently wallsliding
	WALLJUMP, # jump, but with diminished mid-air control
	BOOSTER_JUMP,
	CRAFTING,
}

@export_group("Normal Movement")
@export_range(0, 10000) var jump_power := 300.0
@export_range(0.1, 10)  var jump_length := 0.5
@export_range(0, 10000) var walk_acceleration := 1400.0
@export_range(0, 1)     var speed_damping := 0.92
@export_range(0.0, 1.0) var jump_stop_power := 0.5

@export_group("Wall Slide\\Jump")
@export_range(0, 10000) var wall_slide_speed = 4.0
@export_range(0, 10000) var wall_jump_control_acceleration = 700.0

@export_group("Booster Control")
@export_range(0, 10000) var booster_control_acceleration = 450.0
@export_range(0, 10000) var booster_control_damping := 0.98

const jump_sound := preload("res://assets/sounds/jump.wav")
const landing_sound := preload("res://assets/sounds/land.wav")
const hurt_sound := preload("res://assets/sounds/hurt.wav")
const boost_sound := preload("res://assets/sounds/boost.wav")

var current_state := PlayerState.FREEMOVE
var is_stunned := false

var facing_direction: int = 1 # 1: right, -1: left
var _wall_direction := 0 # direction of the wall the player was on shortly before. 0 means "no wall"

# progress of the jump, from 0.0 to 1.0.
# 1.0 means the player just started jumping; 0.0 means the player is not jumping
var _jump_remaining = 0.0
var _last_move_dir: int = 0 # for tracking if the player wants to get off of a wall slide
var _coyote_jump_timer := 0.0
var _can_jump := false

var _ignore_grounded_on_this_frame: bool = false
var _new_anim := "idle"
var _was_on_floor := true

var _deadly_area_count: int = 0 # for tracking if the player should be taking damage
var is_taking_damage: bool = false

var _stun_timer: float = 0.0
var _iframe_timer: float = 0.0

@onready var _start_pos := position
@onready var tilemap: TileMapLayer = get_node("../Map")

var _active_sounds: Array[AudioStreamPlayer] = []

func _ready() -> void:
	Global.get_game().round_started.connect(game_reset)
	game_reset(true)

# this will reset the entire player state
func game_reset(_new_round: bool):
	position = _start_pos
	velocity = Vector2.ZERO
	
	for snd in _active_sounds:
		snd.queue_free()
	_active_sounds = []
	
	facing_direction = 1
	is_taking_damage = false
	current_state = PlayerState.FREEMOVE
	
	_jump_remaining = 0.0
	_last_move_dir = 1
	_stun_timer = 0.0
	_iframe_timer = 0.0
	_ignore_grounded_on_this_frame = false
	_can_jump = false
	
	_new_anim = "idle"
	_was_on_floor = true
	
	$ItemCrafter.reset()
	reset_physics_interpolation()

func on_entered_deadly_area(_area: Area2D) -> void:
	if _deadly_area_count == 0:
		is_taking_damage = true
		
	_deadly_area_count = _deadly_area_count + 1

func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	
	if _deadly_area_count == 0:
		is_taking_damage = false
	
# formula to obtain the maximum velocity given an acceleration (a) and a damping factor (k):
#	(this is the velocity function. v0 is the initial velocity)
#	(x is the integer number of frames that have elapsed since initial velocity)
#	v(x) = v0*k^x + sum(n=1, x, a*k^n)
#	
#	lim v(x) as x -> inf = a / (1 - k) - a, as:
#		- sum(n=0, x, a*k^n) is a geometric series.
#		  the limit of this series is a / (1 - k). subtract a to remove the n=0 term.
#		- v0*k^x approaches 0 if 0 <= k < 1. if k < 0, limit does not exist. if k >= 1, limit
#		  approaches infinity.
func calc_velocity_limit(acceleration: float, damping: float) -> float:
	if damping >= 1.0:
		push_error("velocity limit approaches infinity")
		return INF
	
	if damping < 0.0:
		push_error("velocity limit does not exist")
		return NAN
	
	return acceleration / (1.0 - damping) - acceleration

func calc_damping_from_limit(limit: float, acceleration: float) -> float:
	return -acceleration / (limit + acceleration) + 1.0

func calc_walljump_damping() -> float:
	# i want the maximum velocity of this state to be the same as
	# that of the normal movement mode, but with a different
	# acceleration.
	var normal_movement_limit := calc_velocity_limit(
		walk_acceleration,
		speed_damping)
	
	var wall_jump_daming := calc_damping_from_limit(
		normal_movement_limit,
		wall_jump_control_acceleration)
	
	return wall_jump_daming

func update_movement(delta: float) -> void:
	var item_crafter := $ItemCrafter
	if is_stunned:
		_can_jump = false
		_coyote_jump_timer = 0
		_jump_remaining = 0
	
	if _can_jump:
		_coyote_jump_timer = COYOTE_JUMP_TIME
		
	# begin jump
	if Input.is_action_just_pressed("player_jump") and _coyote_jump_timer > 0.0:
		var sound := play_sound(jump_sound)
		sound.pitch_scale = 1.0 + randf() * 0.1
		_jump_remaining = 1.0
		
		# if the player is on or have very recently exited a wall (coyote time),
		# then initiate the walljump. the initial x velocity of the walljump
		# will be the maximum x velocity of it.
		if _wall_direction != 0:
			var wall_jump_max_velocity = calc_velocity_limit(
				wall_jump_control_acceleration * delta,
				calc_walljump_damping())
			
			current_state = PlayerState.WALLJUMP
			facing_direction = _wall_direction
			velocity.x = _wall_direction * wall_jump_max_velocity
			_ignore_grounded_on_this_frame = true

	# for the entire duration of the jump, set y velocity to a factor of jump_power,
	# tapering off the longer the jump button is held.
	# once the jump button is released, stop the jump and dampen the y velocity. makes it
	# easier to control the height of the jumps
	var is_jumping: bool = _jump_remaining > 0.0
	if Input.is_action_pressed("player_jump") and not is_on_ceiling():
		if is_jumping:
			velocity.y = -jump_power * _jump_remaining
			_jump_remaining = move_toward(_jump_remaining, 0.0, delta / jump_length)
	else:
		if is_jumping:
			velocity.y *= jump_stop_power
		_jump_remaining = 0.0
	
	# calculate move direction
	var move_dir := 0
	var is_control_revoked: bool = item_crafter.is_active_or_crafting or is_stunned
	if not is_control_revoked:
		if Input.is_action_pressed("player_right"):
			move_dir += 1
		if Input.is_action_pressed("player_left"):
			move_dir -= 1
	
	# update physics stuff based on current state
	# its a basic state machine
	velocity += get_gravity() * delta
	_can_jump = false
	update_state(move_dir, delta)
	
	_last_move_dir = move_dir
	_was_on_floor = is_on_floor()
	_coyote_jump_timer = move_toward(_coyote_jump_timer, 0.0, delta)
	
	move_and_slide()

func update_slippery_jump_state(
		accel: float, damping: float,
		move_dir: float, delta: float) -> void:
	_new_anim = "jump"
	var do_wall_pull_force := false
	
	# wallslide transition
	if not _ignore_grounded_on_this_frame:
		if is_on_wall_only() and move_dir == sign(-get_wall_normal().x):
			_jump_remaining = 0.0
			current_state = PlayerState.WALLSLIDE
			do_wall_pull_force = true
		
		# freemove transition
		elif is_on_floor():
			_jump_remaining = 0.0
			current_state = PlayerState.FREEMOVE
			var sound := play_sound(landing_sound)
			if sound:
				sound.pitch_scale = 1.0 + randf() * 0.2
	
	# diminished mid-air control
	if not do_wall_pull_force:
		velocity.x += move_dir * accel * delta
		velocity.x *= damping
	
	# please stay on the wall
	else:
		velocity.x = -get_wall_normal().x * 100.0

func update_state(move_dir: float, delta: float) -> void:
	var item_crafter := $ItemCrafter
	
	# could possibly use dynamic dispatch instead of this match statement,
	# but i feel like that is over-engineering. would be preferable though if
	# the code gets complex enough.
	match current_state:
		PlayerState.FREEMOVE:
			_can_jump = is_on_floor()
			
			velocity.x += walk_acceleration * move_dir * delta
			velocity.x *= speed_damping
			
			if is_on_floor():
				# unset data for wall-jump coyote time
				_wall_direction = 0
				_new_anim = "idle" if move_dir == 0 else "run"
				
				# play landing sound when player touches the floor
				if not _was_on_floor:
					var sound := play_sound(landing_sound)
					if sound:
						sound.pitch_scale = 1.0 + randf() * 0.2
			else:
				_new_anim = "jump" if velocity.y > 0 else "fall"
			
			if move_dir != 0:
				facing_direction = move_dir
				
				# transition into wallslide when moving towards a wall
				if is_on_wall_only() and sign(get_wall_normal().x) == -move_dir:
					current_state = PlayerState.WALLSLIDE
		
		PlayerState.CRAFTING:
			_new_anim = "hurt"
			
			velocity.x = 0.0
			if not item_crafter.active_item:
				velocity.y = 0.0
			
			if not item_crafter.is_active_or_crafting:
				current_state = PlayerState.FREEMOVE
		
		PlayerState.WALLSLIDE:
			_new_anim = "wallslide"
			_can_jump = is_on_wall_only()
			
			_wall_direction = sign(get_wall_normal().x)
			facing_direction = -_wall_direction
			_coyote_jump_timer = COYOTE_JUMP_TIME
			
			# no longer on wall, transition into freemove
			if not is_on_wall_only() or move_dir != -_wall_direction:
				velocity.x = 0.0
				current_state = PlayerState.FREEMOVE
				
			# wall sliding
			else:
				# maintain maximum y velocity while wall sliding
				var max_y_vel: float = get_gravity().y * delta * wall_slide_speed
				if velocity.y > max_y_vel:
					velocity.y = max_y_vel
				
				# if player wants to move away from the wall, do so here
				#if move_dir != -_wall_direction:
					#velocity.x += walk_acceleration * move_dir * delta
					#velocity.x *= speed_damping
					
				# for some reason i need to apply a force towards the wall to
				# make it so it's not like 0.00001 pixels away from the wall and
				# thus counts it as no longer on the wall.
				velocity.x = -_wall_direction * 100.0 # please stay on the wall

		PlayerState.WALLJUMP:
			# i want the maximum velocity of this state to be the same as
			# that of the normal movement mode, but with a different
			# acceleration.
			var damping := calc_walljump_damping()
			
			update_slippery_jump_state(
				wall_jump_control_acceleration, damping,
				move_dir, delta)
		
		PlayerState.BOOSTER_JUMP:
			update_slippery_jump_state(
				booster_control_acceleration, booster_control_damping,
				move_dir, delta)

func _physics_process(delta: float) -> void:
	# debug fly
	if OS.is_debug_build() and Input.is_key_pressed(KEY_SHIFT):
		const fly_speed := 1200.0
		if Input.is_action_pressed("player_right"):
			position.x += fly_speed * delta
		if Input.is_action_pressed("player_left"):
			position.x -= fly_speed * delta
		if Input.is_action_pressed("player_up"):
			position.y -= fly_speed * delta
		if Input.is_action_pressed("player_down"):
			position.y += fly_speed * delta
		
		return
	
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	var item_crafter := $ItemCrafter
	
	_new_anim = "idle"
	
	if item_crafter.is_active_or_crafting:
		current_state = PlayerState.CRAFTING
	
	if is_taking_damage and _iframe_timer <= 0.0:
		take_damage()
		
	item_crafter.enabled = !is_stunned
	_iframe_timer = move_toward(_iframe_timer, 0, delta)
	
	update_movement(delta)
	
	if is_stunned:
		_new_anim = "hurt"
		_stun_timer = move_toward(_stun_timer, 0, delta)
		if _stun_timer == 0.0:
			is_stunned = false
	
	_ignore_grounded_on_this_frame = false

# process is for updating visuals
func _process(_delta: float) -> void:
	var sprite := $AnimatedSprite2D
	
	# update sprite animation
	sprite.flip_h = facing_direction < 0
	if sprite.animation != _new_anim:
		sprite.play(_new_anim)
	
	# update some procedural animations
	# 1. flash red when the player is stunned
	# 2. flash visible/invisible while iframes are active
	# 3. crafting animation
	if is_stunned:
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		modulate = Color(1.0, 0.0, 0.0) if t < 0.5 else Color(1.0, 1.0, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0)
		
		# flash visible/invisible while iframes are active
		if _iframe_timer > 0.0:
			var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
			visible = t < 0.5
		else:
			visible = true
		
		# crafting animation will stretch out the player a little bit
		# stretching increases as it gets closer to being finished
		var item_craft_progress = $ItemCrafter.item_craft_progress
		if item_craft_progress != null:
			var t: float = 1.0 - item_craft_progress.time_remaining / item_craft_progress.wait_length
			sprite.scale = Vector2(
				pow(2, t * 0.4),
				pow(2, -t * 0.4)
			)
		else:
			sprite.scale = Vector2.ONE

func spring_bounce_callback(bounce_power: float) -> void:
	_jump_remaining = 0.0
	velocity.y = -bounce_power
	_ignore_grounded_on_this_frame = true
	play_sound(boost_sound)
	
func horiz_spring_bounce_callback(bounce_power: float, side_power: float) -> void:
	velocity.x = side_power * facing_direction
	velocity.y = -bounce_power
	current_state = PlayerState.BOOSTER_JUMP
	
	_ignore_grounded_on_this_frame = true
	play_sound(boost_sound)

func take_damage() -> void:
	_stun_timer = DAMAGE_STUN_LENGTH
	_iframe_timer = IFRAME_LENGTH
	is_stunned = true
	current_state = PlayerState.FREEMOVE
	velocity = Vector2(0, -200)
	
	_jump_remaining = 0.0
	_coyote_jump_timer = 0.0
	_can_jump = false
	
	play_sound(hurt_sound)

func kill() -> void:
	Global.player_lives -= 1
	
	if Global.player_lives == 0:
		print("Game over")
		Global.game_state = Global.GameState.GAME_OVER
		
	else:
		print("Normal death")
		Global.game_state = Global.GameState.DEATH

func play_sound(stream: AudioStream) -> AudioStreamPlayer:
	if stream == null: return
	
	var audio_source := AudioStreamPlayer.new()
	audio_source.stream = stream
	add_child(audio_source)
	
	audio_source.play()
	_active_sounds.push_back(audio_source)
	
	audio_source.finished.connect(func():
		audio_source.queue_free()
		var idx = _active_sounds.find(audio_source)
		if idx != -1:
			_active_sounds.remove_at(idx)
	)
	
	return audio_source
