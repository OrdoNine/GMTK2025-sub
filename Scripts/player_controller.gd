extends CharacterBody2D
class_name Player

const DAMAGE_STUN_LENGTH := 2.0
const IFRAME_LENGTH := 3.0 # must be longer than stun length
const COYOTE_JUMP_TIME := 0.13

enum PlayerState {
	FREEMOVE, # normal grounded/mid-air movement mode
	WALLSLIDE, # currently wallsliding
	WALLJUMP, # jump from a wallslide. diminished mid-air control
	CRAFTING,
	STUNNED, # control is revoked for a short time when player takes damage
}

@export_group("Normal Movement")
@export_range(0, 10000) var jump_power := 300.0
@export_range(0.1, 10)  var jump_length := 0.5
@export_range(0, 10000) var walk_acceleration := 1400.0
@export_range(0, 1)     var speed_damping := 0.92
@export_range(0.0, 1.0) var jump_stop_power := 0.5

@export_group("Wall Slide, Jump")
@export_range(0, 10000) var wall_slide_speed = 4.0
@export_range(0, 10000) var wall_jump_velocity = 230.0
@export_range(0, 10000) var wall_jump_damping = 0.98
@export_range(0, 10000) var wall_jump_control_acceleration = 450.0

const jump_sound := preload("res://Assets/sounds/jump.wav")
const landing_sound := preload("res://Assets/sounds/land.wav")
const hurt_sound := preload("res://Assets/sounds/hurt.wav")
const crafting_sound := preload("res://Assets/sounds/crafting.wav")
const building_place_sound := preload("res://Assets/sounds/building_place.wav")
const boost_sound := preload("res://Assets/sounds/boost.wav")

var stamina_points: int = 0
var facing_direction: int = 1 # 1: right, -1: left

var is_taking_damage: bool = false

var current_state := PlayerState.FREEMOVE

# progress of the jump, from 0.0 to 1.0.
# 1.0 means the player just started jumping; 0.0 means the player is not jumping
var _jump_remaining = 0.0
var _last_move_dir: int = 0 # for tracking if the player wants to get off of a wall slide
var _coyote_jump_timer := 0.0
var _wall_direction := 0 # direction of the wall the player was on shortly before. 0 means "no wall"
var _deadly_area_count: int = 0 # for tracking if the player should be taking damage
var _stun_timer: float = 0.0
var _iframe_timer: float = 0.0
var _ignore_grounded_on_this_frame: bool = false
var _new_anim := "idle"
var _was_on_floor := true

@onready var _start_pos := position
@onready var tilemap: TileMapLayer = get_node("../Map")

const _prefab_bomb = preload("res://Objects/realized-items/bomb/bomb.tscn")
const _prefab_inverse_bomb = preload("res://Objects/realized-items/inverse_bomb/inverse_bomb.tscn")
const _prefab_bridge_maker = preload("res://Objects/realized-items/bridge/bridge.tscn")
const _prefab_spring = preload("res://Objects/realized-items/spring/spring.tscn")
const _prefab_horiz_spring = preload("res://Objects/realized-items/horiz_spring/horiz_spring.tscn")

var _item_craft_progress = null
var _active_bridge_maker: Node2D = null
var _active_item_key := KEY_NONE
var _crafting_sound_player: AudioStreamPlayer
var _active_sounds: Array[AudioStreamPlayer] = []

func begin_item_craft(time: float, points: int, prefab: PackedScene):
	_crafting_sound_player.play()
	
	_item_craft_progress = {
		time_remaining = time,
		wait_length = time,
		points = points,
		prefab = prefab
	}

func finish_item_craft():
	var inst: Node2D = _item_craft_progress.prefab.instantiate()
	inst.global_position = global_position
	add_sibling(inst)
	inst.activate()
	stamina_points -= _item_craft_progress.points
	
	_item_craft_progress = null
	_active_item_key = KEY_NONE
	play_sound(building_place_sound)
	_crafting_sound_player.stop()

func deactivate_item_craft():
	_item_craft_progress = null
	_active_item_key = KEY_NONE
	_crafting_sound_player.stop()

func _ready() -> void:
	Global.game_new_loop.connect(game_reset)
	game_reset()
	
	# create crafting sound player
	_crafting_sound_player = AudioStreamPlayer.new()
	_crafting_sound_player.stream = crafting_sound
	add_child(_crafting_sound_player)

# this will reset the entire player state
func game_reset():
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
	
	_item_craft_progress = null
	_active_bridge_maker = null
	_active_item_key = KEY_NONE
	_new_anim = "idle"
	_was_on_floor = true

func on_entered_deadly_area(_area: Area2D) -> void:
	if _deadly_area_count == 0:
		is_taking_damage = true
		
	_deadly_area_count = _deadly_area_count + 1

func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	
	if _deadly_area_count == 0:
		is_taking_damage = false

func deactivate_active_item():
	if _active_bridge_maker != null:
		_active_bridge_maker.deactivate()
		_active_bridge_maker = null

func meets_stamina_requirement(c: int) -> bool:
	return stamina_points >= c

# this is for crafting stuff
func _input(event: InputEvent) -> void:
	if current_state != PlayerState.STUNNED:
		if event is InputEventKey and not event.is_echo():
			if _active_bridge_maker == null and _item_craft_progress == null:
				# 1 key: craft bomb
				if event.pressed and event.keycode == KEY_1 and meets_stamina_requirement(5):
					_active_item_key = event.keycode
					begin_item_craft(0.5, 5, _prefab_bomb)
					
				# slime bomb
				# if event.pressed and event.keycode == KEY_2 and meets_stamina_requirement(3):
				# 	_active_item_key = event.keycode
				# 	begin_item_craft(0.5, 3, _prefab_inverse_bomb)
					
				# 2 key: bridge marker (if airborne)
				elif event.pressed and event.keycode == KEY_2 and not is_on_floor() and meets_stamina_requirement(8):
					# place bridge maker if not on floor
					velocity.x = 0.0
					var inst: Node2D = _prefab_bridge_maker.instantiate()
					
					# place bridge maker on the center of the cell below the player
					var player_bottom: Vector2i = global_position + Vector2.DOWN * $CollisionShape2D.shape.size.y / 2.0
					inst.global_position = get_position_of_tile((get_tiled_pos_of(player_bottom) + Vector2i(0, 1)))
					add_sibling(inst)
					inst.activate()
					stamina_points -= 8
					
					_active_bridge_maker = inst
					_active_item_key = event.keycode
				
				# 3 key: spring
				elif event.pressed and event.keycode == KEY_3 and meets_stamina_requirement(6):
					_active_item_key = event.keycode
					begin_item_craft(0.5, 6, _prefab_spring)
					
				# 4 key: horiz spring
				elif event.pressed and event.keycode == KEY_4 and meets_stamina_requirement(6):
					_active_item_key = event.keycode
					begin_item_craft(0.5, 6, _prefab_horiz_spring)
			
			elif event.is_released() and event.keycode == _active_item_key:
				if _active_bridge_maker != null:
					deactivate_active_item()
					
				if _item_craft_progress != null:
					deactivate_item_craft()

func get_tiled_pos_of(pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(pos))

func get_position_of_tile(coord: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(coord))

func update_movement(delta: float) -> void:
	var can_jump := (current_state == PlayerState.FREEMOVE and is_on_floor()) or (current_state == PlayerState.WALLSLIDE and is_on_wall_only());
	if _active_bridge_maker != null:
		can_jump = false
	
	if can_jump:
		_coyote_jump_timer = COYOTE_JUMP_TIME
		
	# begin jump
	if Input.is_action_just_pressed("player_jump") and _coyote_jump_timer > 0.0:
		var sound := play_sound(jump_sound)
		sound.pitch_scale = 1.0 + randf() * 0.1
		_jump_remaining = 1.0
		
		if _wall_direction != 0:
			current_state = PlayerState.WALLJUMP
			facing_direction = _wall_direction
			velocity.x = _wall_direction * wall_jump_velocity
			_ignore_grounded_on_this_frame = true

	# for the entire duration of the jump, set y velocity to a factor of jump_power,
	# tapering off the longer the jump button is held.
	# once the jump button is released, stop the jump and dampen the y velocity. makes it
	# easier to control the height of the jumps
	var is_jumping: bool = _jump_remaining > 0.0
	if Input.is_action_pressed("player_jump") and not is_on_ceiling():
		if _jump_remaining > 0.0:
			velocity.y = -jump_power * _jump_remaining
			_jump_remaining = move_toward(_jump_remaining, 0.0, delta / jump_length)
	else:
		if is_jumping:
			velocity.y *= jump_stop_power
		_jump_remaining = 0.0
	
	# calculate move direction
	var move_dir := 0
	var is_control_revoked := _active_bridge_maker != null or _item_craft_progress != null
	if not is_control_revoked:
		if Input.is_action_pressed("player_right"):
			move_dir += 1
		if Input.is_action_pressed("player_left"):
			move_dir -= 1
	
	# update physics stuff based on current state
	# its a basic state machine
	match current_state:
		PlayerState.FREEMOVE:
			# apply gravity normally
			velocity += get_gravity() * delta

			# apply movement direction
			# velocity.x = move_toward(velocity.x, walk_speed * move_dir, walk_acceleration * delta);
			velocity.x += walk_acceleration * move_dir * delta
			velocity.x *= speed_damping
			
			if is_on_floor():
				_wall_direction = 0
				_new_anim = "idle" if move_dir == 0 else "run"
				
				if not _was_on_floor:
					var sound := play_sound(landing_sound)
					if sound:
						sound.pitch_scale = 1.0 + randf() * 0.2
			else:
				_new_anim = "jump"
			
			if move_dir != 0:
				facing_direction = move_dir
				if is_on_wall_only():
					_jump_remaining = 0.0
					current_state = PlayerState.WALLSLIDE
		
		PlayerState.STUNNED:
			_new_anim = "hurt"
			
			# apply gravity normally
			velocity += get_gravity() * delta
			
			# damping
			velocity.x *= speed_damping
			
			_stun_timer = move_toward(_stun_timer, 0, delta)
			if _stun_timer <= 0.0:
				current_state = PlayerState.FREEMOVE
		
		PlayerState.CRAFTING:
			_new_anim = "hurt"
			velocity = Vector2.ZERO
			
			if _item_craft_progress == null:
				current_state = PlayerState.FREEMOVE
		
		PlayerState.WALLSLIDE:
			_new_anim = "wallslide"
			
			_wall_direction = sign(get_wall_normal().x)
			facing_direction = -_wall_direction
			_coyote_jump_timer = COYOTE_JUMP_TIME
				
			# no longer on wall, transition into freemove
			if not is_on_wall_only():
				current_state = PlayerState.FREEMOVE
				
			# wall sliding
			else:
				# maintain maximum y velocity while wall sliding
				var max_y_vel: float = get_gravity().y * delta * wall_slide_speed
				velocity += get_gravity() * delta
				
				if velocity.y > max_y_vel:
					velocity.y = max_y_vel
				
				# if player wants to move away from the wall, do so here
				if move_dir != _last_move_dir and move_dir != 0:
					velocity.x += walk_acceleration * move_dir * delta
					velocity.x *= speed_damping
					
				# otherwise... ideally, do nothing. but for some reason i need
				# to apply a force towards the wall to make it so it's not like 
				# 0.0001 pixels away from the wall and thus counts it as no longer
				# on the wall.
				else:
					velocity.x = -_wall_direction * 100.0 # please stay on the wall

		PlayerState.WALLJUMP:
			_new_anim = "jump"
			
			# apply gravity normally
			velocity += get_gravity() * delta
			
			# apply movement direction
			# velocity.x = move_dir * walk_speed
			
			if is_on_wall_only() and not _ignore_grounded_on_this_frame:
				_jump_remaining = 0.0
				current_state = PlayerState.WALLSLIDE
				velocity.x = -get_wall_normal().x * 100.0 # please stay on the wall
				
			elif is_on_floor() and not _ignore_grounded_on_this_frame:
				_jump_remaining = 0.0
				current_state = PlayerState.FREEMOVE
				var sound := play_sound(landing_sound)
				if sound:
					sound.pitch_scale = 1.0 + randf() * 0.2
				
			else:
				velocity.x += move_dir * wall_jump_control_acceleration * delta
				velocity.x *= wall_jump_damping
	
	_last_move_dir = move_dir
	_was_on_floor = is_on_floor()
	_coyote_jump_timer = move_toward(_coyote_jump_timer, 0.0, delta)
	
	move_and_slide()

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
	_new_anim = "idle"
	
	# if bridge maker is no longer active, then deactivate the tracking of it
	if _active_bridge_maker != null and not _active_bridge_maker.active:
		_active_bridge_maker = null
	
	# update item craft progress
	if _item_craft_progress != null:
		current_state = PlayerState.CRAFTING
		_item_craft_progress.time_remaining -= delta
		if _item_craft_progress.time_remaining <= 0.0:
			finish_item_craft()
	
	# taking damage
	if is_taking_damage and _iframe_timer <= 0.0:
		_stun_timer = DAMAGE_STUN_LENGTH
		_iframe_timer = IFRAME_LENGTH
		current_state = PlayerState.STUNNED
		velocity = Vector2(0, -200)
		deactivate_active_item()
		_item_craft_progress = null
		play_sound(hurt_sound)
	
	# update iframe time
	_iframe_timer = move_toward(_iframe_timer, 0, delta)

	update_movement(delta)
	
	# update sprite animation
	sprite.flip_h = facing_direction < 0
	if sprite.animation != _new_anim:
		sprite.play(_new_anim)
		
	_ignore_grounded_on_this_frame = false
	
func _process(_delta: float) -> void:
	if Global.time_remaining <= 0:
		kill();
	
	if Input.is_action_just_pressed("escape"):
		if Global.ignore_escape:
			Global.ignore_escape = false
		else:
			Global.game_state = Global.GameState.PAUSE
	
	%GamePlayUI.stamina_points = stamina_points
	
	# update some animation
	# 1. flash red when the player is stunned
	# 2. flash visible/invisible while iframes are active
	# 3. crafting animation
	match current_state:
		# flash red when player is stunned
		PlayerState.STUNNED:
			var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
			modulate = Color(1.0, 0.0, 0.0) if t < 0.5 else Color(1.0, 1.0, 1.0)
			
		_:
			modulate = Color(1.0, 1.0, 1.0)
			
			# flash visible/invisible while iframes are active
			if _iframe_timer > 0.0:
				var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
				visible = t < 0.5
			else:
				visible = true
			
			# crafting animation will stretch out the player a little bit
			# stretching increases as it gets closer to being finished
			var sprite := $AnimatedSprite2D
			if _item_craft_progress != null:
				var t: float = 1.0 - _item_craft_progress.time_remaining / _item_craft_progress.wait_length
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
	current_state = PlayerState.WALLJUMP
	_ignore_grounded_on_this_frame = true
	play_sound(boost_sound)
		
func kill() -> void:
	game_reset();
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
