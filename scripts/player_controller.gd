extends CharacterBody2D
class_name Player

# Asset Links
# TODO: Sound Manager so that we don't have to load sounds here!
const _jump_sound := preload("res://assets/sounds/jump.wav")
const _landing_sound := preload("res://assets/sounds/land.wav")
const _hurt_sound := preload("res://assets/sounds/hurt.wav")
const _crafting_sound := preload("res://assets/sounds/crafting.wav")
const _building_place_sound := preload("res://assets/sounds/building_place.wav")
const _boost_sound := preload("res://assets/sounds/boost.wav")

const _prefab_bomb = preload("res://objects/realized-items/bomb/bomb.tscn")
const _prefab_inverse_bomb = preload("res://objects/realized-items/inverse_bomb/inverse_bomb.tscn")
const _prefab_bridge_maker = preload("res://objects/realized-items/bridge/bridge.tscn")
const _prefab_spring = preload("res://objects/realized-items/spring/spring.tscn")
const _prefab_horiz_spring = preload("res://objects/realized-items/horiz_spring/horiz_spring.tscn")

# Constructs
## Consists of various states of Player according to which different actions happen in the script.
enum PlayerState {
	## normal grounded/mid-air movement mode
	FREEMOVE, 
	## currently wallsliding
	WALLSLIDE,
	## jump from a wallslide. diminished mid-air control
	WALLJUMP,
	## crafting a powerup
	CRAFTING,
	## control is revoked for a short time when player takes damage
	STUNNED,
}

## The current state of the player.
var current_state := PlayerState.FREEMOVE

# Variables # TODO: Order and move variables. The current one is based on guesswork, ngl
# Movement related variables & constants
## The time which is given after the moment you no longer can jump, in which you may jump anyway.
## Example: If you failed the last moment jump by a millisecond, you are still fine and we'll let you jump.
const _COYOTE_JUMP_TIME := 0.13

## A variable to track the time since the last moment, you no longer could jump.
var _cayote_jump_timer := 0.0

@export_group("Normal Movement")
## The constant ratio of velocity.y and jump_remaining.
## Bigger the magnitude, Bigger the jump.
@export_range(0, 10000) var _jump_power := 300.0

## The time it takes for the player to complete a jump.
@export_range(0.1, 10)  var _jump_length := 0.5

## Acceleration in FreeMove. Normal Movements and Jumping from floor.
@export_range(0, 10000) var _walk_acceleration := 1400.0

## Friction in FreeMove. Normal Movements and Jumping from floor.
@export_range(0, 1)     var _speed_damping := 0.92

## The damping of jumping velocity. Useful to control the variable jump height.
@export_range(0.0, 1.0) var _early_jump_damp := 0.5

@export_group("Wall Slide, Jump")

## The multiplier limit that forces wall slide speed not to increase indefinitely.
@export_range(0, 10000) var _wall_slide_speed_limit = 4.0

## The velocity in the x axis, while jumping from a wall.
@export_range(0, 10000) var _wall_jump_x_velocity = 230.0

## Friction in Wall Jump. Movements in air, while jumping from a wall.
@export_range(0, 10000) var _wall_jump_damping = 0.98

## Acceleration in Wall Jump. Movements in air, while jumping from a wall.
@export_range(0, 10000) var _wall_jump_acceleration = 450.0

## Remaining Percentage of Jump Remaining. 0: Jump has been completed. 1: Jump has not been completed.
var _jump_remaining = 0.0

## Records the last direction
var _last_move_dir: int = 0

## If jumped from or is on some wall, then it is the direction away from the wall.
var _wall_direction := 0 # direction of the wall the player was on shortly before. 0 means "no wall"

# Animation related variables & constants

## The time after death when you are invincible to spikes and such.
const _INVINCIBILITY_FRAMES_LENGTH := 3.0 # must be longer than stun length # TODO: Fix its dependency on _DAMAGE_STUN_LENGTH

## A variable to track time from the last time you got hurt from a spike. Animation Purposes
var _invincibility_frames_timer: float = 0.0

var _new_anim := "idle"

# Other variables and constants. Mysterious ngl. why the f*** there are so many variables.
## A stream player for crafting sound separately. (So that you could stop the crafting sound early)
var _crafting_sound_player: AudioStreamPlayer

## A array of sounds that are played.
var _active_sounds: Array[AudioStreamPlayer] = []

## The time after you got stunned, where you stay stunned.
const _DAMAGE_STUN_LENGTH := 2.0

## A variable to track time from the last moment you got stunned.
var _stun_timer: float = 0.0

## A variable to track the number of slimes in your inventory.
var slimes_collected: int = 0

## A variable to track the direction you are facing. # TODO: Check if you can somehow merge this and move_dir
var facing_direction: int = 1 # 1: right, -1: left

## A variable to track if we are taking damage. # TODO: Check if you could remove this variable.
var is_taking_damage: bool = false

## A variable to track the cardinality of deadly area, the player is in, to know about giving a stun.
var _deadly_area_count: int = 0

## A variable that is supposed to be removing walk friction while using booster. # TODO: Check if you can somehow remove this.
var _ignore_grounded_on_this_frame: bool = false

## A variable to track if the player was on floor at the previous frame to give a landing sound.
var _was_on_floor := true

## The start position of the player, where it starts.
@onready var _start_pos := position

## The tilemap of blocks. # TODO: Check if you can remove it completely.
@onready var tilemap: TileMapLayer = get_node("../Map")

## I dunno tbqh. Supposedly a dict of random item_craft_progress related bullshit.
var _item_craft_progress = null

## Reference to the active bridgemaker. # TODO: Check if i can remove this
var _active_bridge_maker: Node2D = null

## Tracking the event key of the active item to shut it up, afterwards if necessary.
## TODO: Check if you can remove it.
var _active_item_key := KEY_NONE

# Public Functions # TODO: Needs REWRITE!!!
func on_entered_deadly_area(_area: Area2D) -> void:
	if _deadly_area_count == 0:
		is_taking_damage = true
		
	_deadly_area_count = _deadly_area_count + 1
func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	
	if _deadly_area_count == 0:
		is_taking_damage = false
func spring_bounce_callback(bounce_power: float) -> void:
	_jump_remaining = 0.0
	velocity.y = -bounce_power
	_ignore_grounded_on_this_frame = true
	_play_sound(_boost_sound)
func horiz_spring_bounce_callback(bounce_power: float, side_power: float) -> void:
	velocity.x = side_power * facing_direction
	velocity.y = -bounce_power
	current_state = PlayerState.WALLJUMP
	_ignore_grounded_on_this_frame = true
	_play_sound(_boost_sound)
func kill() -> void:
	Global.player_lives -= 1
	Global.game_state = Global.GameState.GAME_OVER if Global.player_lives == 0 else Global.GameState.DEATH;

# Private Functions
func _ready() -> void: # TODO: Rewrite
	Global.game_new_loop.connect(_game_reset)
	_game_reset(true)
	
	# create crafting sound player
	_crafting_sound_player = AudioStreamPlayer.new()
	_crafting_sound_player.stream = _crafting_sound
	add_child(_crafting_sound_player)
func _input(event: InputEvent) -> void:
	if event is not InputEventKey or event.is_echo(): return;
	if current_state == PlayerState.STUNNED: return;
	
	# TODO: Gotta come back here again. So coupled AAH
	if _active_bridge_maker == null and _item_craft_progress == null:
		# 1 key: craft bomb
		if event.pressed and event.keycode == KEY_1 and _meets_stamina_requirement(5):
			_active_item_key = event.keycode
			_begin_item_craft(0.5, 5, _prefab_bomb)
			
		# slime bomb # TODO: Think about this code's existence
		# if event.pressed and event.keycode == KEY_2 and _meets_stamina_requirement(3):
		# 	_active_item_key = event.keycode
		# 	_begin_item_craft(0.5, 3, _prefab_inverse_bomb)
			
		# 2 key: bridge marker (if airborne)
		elif event.pressed and event.keycode == KEY_2 and not is_on_floor() and _meets_stamina_requirement(8):
			# place bridge maker if not on floor
			velocity.x = 0.0
			_active_bridge_maker = _prefab_bridge_maker.instantiate()
			
			# place bridge maker on the center of the cell below the player
			var player_bottom: Vector2i = global_position + Vector2.DOWN * $CollisionShape2D.shape.size.y / 2.0
			_active_bridge_maker.global_position = _get_position_of_tile((_get_tiled_pos_of(player_bottom) + Vector2i(0, 1)))
			add_sibling(_active_bridge_maker)
			_active_bridge_maker.activate()
			slimes_collected -= 8
			
			_active_item_key = event.keycode
		
		# 3 key: spring
		elif event.pressed and event.keycode == KEY_3 and _meets_stamina_requirement(6):
			_active_item_key = event.keycode
			_begin_item_craft(0.5, 6, _prefab_spring)
			
		# 4 key: horiz spring
		elif event.pressed and event.keycode == KEY_4 and _meets_stamina_requirement(6):
			_active_item_key = event.keycode
			_begin_item_craft(0.5, 6, _prefab_horiz_spring)
	elif event.is_released() and event.keycode == _active_item_key:
		if _active_bridge_maker != null:
			_deactivate_active_item()
			
		if _item_craft_progress != null:
			_deactivate_item_craft()
func _physics_process(delta: float) -> void:
	# debug fly # THE WHAT? didn't know this existed # TODO: Check out this section later. idk, the codebase aah...
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
	# DKP: Ok so is that really necessary?
	if _active_bridge_maker != null and not _active_bridge_maker.active:
		_active_bridge_maker = null
	
	# update item craft progress
	if _item_craft_progress != null:
		current_state = PlayerState.CRAFTING
		_item_craft_progress.time_remaining -= delta
		if _item_craft_progress.time_remaining <= 0.0:
			_finish_item_craft()
	
	# taking damage
	if is_taking_damage and _invincibility_frames_timer <= 0.0:
		_stun_timer = _DAMAGE_STUN_LENGTH
		_invincibility_frames_timer = _INVINCIBILITY_FRAMES_LENGTH
		current_state = PlayerState.STUNNED
		velocity = Vector2(0, -200)
		_deactivate_active_item()
		_item_craft_progress = null
		_play_sound(_hurt_sound)
	
	# update iframe time
	_invincibility_frames_timer = move_toward(_invincibility_frames_timer, 0, delta)

	_update_movement(delta)
	
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
	
	%GamePlayUI.stamina_points = slimes_collected
	
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
			if _invincibility_frames_timer > 0.0:
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

# Accessory Functions
func _begin_item_craft(time: float, points: int, prefab: PackedScene):
	_crafting_sound_player.play()
	
	_item_craft_progress = {
		time_remaining = time,
		wait_length = time,
		points = points,
		prefab = prefab
	}
func _finish_item_craft():
	var inst: Node2D = _item_craft_progress.prefab.instantiate()
	inst.global_position = global_position
	add_sibling(inst)
	inst.activate()
	slimes_collected -= _item_craft_progress.points
	
	_item_craft_progress = null
	_active_item_key = KEY_NONE
	_play_sound(_building_place_sound)
	_crafting_sound_player.stop()
func _deactivate_item_craft():
	_item_craft_progress = null
	_active_item_key = KEY_NONE
	_crafting_sound_player.stop()
func _game_reset(_new_round: bool):
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
	_invincibility_frames_timer = 0.0
	_ignore_grounded_on_this_frame = false
	
	_item_craft_progress = null
	_active_bridge_maker = null
	_active_item_key = KEY_NONE
	_new_anim = "idle"
	_was_on_floor = true
func _deactivate_active_item():
	if _active_bridge_maker != null:
		_active_bridge_maker.deactivate()
		_active_bridge_maker = null
func _meets_stamina_requirement(c: int) -> bool:
	return slimes_collected >= c
func _get_tiled_pos_of(pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(pos))
func _get_position_of_tile(coord: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(coord))
func _update_movement(delta: float) -> void:
	var can_jump := (current_state == PlayerState.FREEMOVE and is_on_floor()) or (current_state == PlayerState.WALLSLIDE and is_on_wall_only());
	if _active_bridge_maker != null:
		can_jump = false

	if can_jump:
		_cayote_jump_timer = _COYOTE_JUMP_TIME
	# begin jump
	if Input.is_action_just_pressed("player_jump") and _cayote_jump_timer > 0.0:
		var sound := _play_sound(_jump_sound)
		sound.pitch_scale = 1.0 + randf() * 0.1
		_jump_remaining = 1.0
		
		if _wall_direction != 0:
			current_state = PlayerState.WALLJUMP
			facing_direction = _wall_direction
			velocity.x = _wall_direction * _wall_jump_x_velocity
			_ignore_grounded_on_this_frame = true

	# for the entire duration of the jump, set y velocity to a factor of _jump_power,
	# tapering off the longer the jump button is held.
	# once the jump button is released, stop the jump and dampen the y velocity. makes it
	# easier to control the height of the jumps
	var is_jumping: bool = _jump_remaining > 0.0
	if Input.is_action_pressed("player_jump") and not is_on_ceiling():
		if _jump_remaining > 0.0:
			velocity.y = -_jump_power * _jump_remaining
			_jump_remaining = move_toward(_jump_remaining, 0.0, delta / _jump_length)
	else:
		if is_jumping:
			velocity.y *= _early_jump_damp
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
			# velocity.x = move_toward(velocity.x, walk_speed * move_dir, _walk_acceleration * delta);
			velocity.x += move_dir * (_walk_acceleration * delta)
			velocity.x *= _speed_damping
			
			if is_on_floor():
				_wall_direction = 0
				_new_anim = "idle" if move_dir == 0 else "run"
				
				if not _was_on_floor:
					var sound := _play_sound(_landing_sound)
					if sound:
						sound.pitch_scale = 1.0 + randf() * 0.2
			else:
				_new_anim = "jump" if velocity.y > 0 else "fall"
			
			if move_dir != 0:
				facing_direction = move_dir
				if is_on_wall_only():
					current_state = PlayerState.WALLSLIDE
		
		PlayerState.STUNNED:
			_new_anim = "hurt"
			
			# apply gravity normally
			velocity += get_gravity() * delta
			
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
			facing_direction = _wall_direction
			_cayote_jump_timer = _COYOTE_JUMP_TIME
			
			# no longer on wall, transition into freemove
			if not is_on_wall_only():
				current_state = PlayerState.FREEMOVE
				
			# wall sliding
			else:
				# maintain maximum y velocity while wall sliding
				var max_y_vel: float = get_gravity().y * delta * _wall_slide_speed_limit
				velocity += get_gravity() * delta
				
				if velocity.y > max_y_vel:
					velocity.y = max_y_vel
				
				# if player wants to move away from the wall, do so here
				if move_dir != _last_move_dir and move_dir != 0:
					velocity.x += _walk_acceleration * move_dir * delta
					velocity.x *= _speed_damping
					
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
				var sound := _play_sound(_landing_sound)
				if sound:
					sound.pitch_scale = 1.0 + randf() * 0.2
			else:
				velocity.x += move_dir * _wall_jump_acceleration * delta
				velocity.x *= _wall_jump_damping
	_last_move_dir = move_dir
	_was_on_floor = is_on_floor()
	_cayote_jump_timer = move_toward(_cayote_jump_timer, 0.0, delta)
	
	move_and_slide()
func _play_sound(stream: AudioStream) -> AudioStreamPlayer:
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
