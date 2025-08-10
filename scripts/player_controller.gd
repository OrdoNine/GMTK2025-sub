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
## Consists of various states of Player according to which different actions happen in the script. [br]
## Variants:[br]
## FREEMOVE: normal grounded/mid-air movement mode[br]
## WALLSLIDE: currently wallsliding[br]
## WALLJUMP: jump from a wallslide. diminished mid-air control[br]
## CRAFTING: crafting a powerup[br]
## STUNNED: control is revoked for a short time when player takes damage[br]
enum PlayerState {
	FREEMOVE,
	WALLSLIDE,
	WALLJUMP,
	CRAFTING,
	STUNNED,
}

enum PowerupType {
	BOOSTER,
	SPRING,
	BOMB,
	BRIDGE
}

## The current state of the player.
var current_state := PlayerState.FREEMOVE

## The previous state of the player.
var previous_state : PlayerState = PlayerState.FREEMOVE

# Movement related variables & constants
## The time which is given after the moment you no longer can jump, in which you may jump anyway.
## Example: If you failed the last moment jump by a millisecond, you are still fine and we'll let you jump.
const _COYOTE_JUMP_TIME := 0.13

## A variable to track the time since the last moment, you no longer could jump.
var _coyote_jump_timer := 0.0

@export_group("Normal Movement")
## The constant ratio of velocity.y and jump_remaining.
## Bigger the magnitude, Bigger the jump.
@export_range(0, 10000) var _jump_power := 300.0

## The time it takes for the player to complete a jump.
@export_range(0.1, 10)  var _jump_length := 0.5

## The damping of jumping velocity. Useful to control the variable jump height.
@export_range(0.0, 1.0) var _early_jump_damp := 0.5

## The multiplier limit that forces wall slide speed not to increase indefinitely.
@export_range(0, 10000) var _wall_slide_speed_limit = 4.0

## The velocity boost in the x axis, while wall jumping.
@export_range(0, 10000) var _wall_jump_initial_xboost = 230.0

## Remaining Percentage of Jump Remaining. 0: Jump has been completed. 1: Jump has not been completed.
var _jump_remaining = 0.0

## If jumped from or is on some wall, then it is the direction away from the wall with player being at the origin.
var _wall_away_direction : int = 0

## A map from player state to acceleration used.
var _player_state_to_acceleration : Dictionary[PlayerState, float] = {
	PlayerState.FREEMOVE: 3800,
	PlayerState.WALLSLIDE: 1400,
	PlayerState.WALLJUMP: 450,
	PlayerState.CRAFTING: 0,
	PlayerState.STUNNED: 0.
}

## A map from player state to damping used.
var _player_state_to_damping: Dictionary[PlayerState, float] = {
	PlayerState.FREEMOVE: 0.8,
	PlayerState.WALLSLIDE: 0.8,
	PlayerState.WALLJUMP: 0.98,
	PlayerState.CRAFTING: 0,
	PlayerState.STUNNED: 0,
}

# Other variables and constants. Mysterious ngl. why the f*** there are so many variables.
## A stream player for crafting sound separately. (So that you could stop the crafting sound early)
var _crafting_sound_player: AudioStreamPlayer

## A array of sounds that are played.
var _active_sounds: Array[AudioStreamPlayer] = []

## The time after you got stunned, where you stay stunned.
const _STUN_LENGTH := 2.0

## A variable to track time from the last moment you got stunned.
var _stun_timer: float = 0.0

## The time after death when you are invincible to spikes and such.
const _INVINCIBILITY_FRAMES_LENGTH := 3.0 # must be longer than stun length # TODO: Fix its dependency on _STUN_LENGTH

## A variable to track time from the last time you got hurt from a spike. Animation Purposes
var _invincibility_frames_timer: float = 0.0

## A variable to track the number of slimes in your inventory.
var slimes_collected: int = 0

## A variable to track the direction you are facing.
var facing_direction: int = 1

## A variable to track if we are taking damage. # TODO: Check if you could remove this variable.
var _can_be_stunned: bool = false

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
var _active_powerup_key := KEY_NONE

var keys_to_powerup : Dictionary[Key, PowerupType] = {
	KEY_1: PowerupType.BOMB,
	KEY_2: PowerupType.BRIDGE,
	KEY_3: PowerupType.SPRING,
	KEY_4: PowerupType.BOOSTER
}

var powerup_to_slime_cost : Dictionary[PowerupType, int] = {
	PowerupType.BOMB: 5,
	PowerupType.BRIDGE: 8,
	PowerupType.SPRING: 6,
	PowerupType.BOOSTER: 6,
}

var just_jumped : bool = false
var just_jumped_from_wall : bool = false

# Public Functions # TODO: Needs REWRITE!!!
func on_entered_deadly_area(_area: Area2D) -> void:
	if _deadly_area_count == 0:
		_can_be_stunned = true
		
	_deadly_area_count = _deadly_area_count + 1
func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	
	if _deadly_area_count == 0:
		_can_be_stunned = false

func spring_bounce_callback(bounce_power: float) -> void:
	_jump_remaining = 0.0
	velocity.y = -bounce_power
	_play_sound(_boost_sound)

func horiz_spring_bounce_callback(bounce_power: float, side_power: float) -> void:
	velocity.x = side_power * facing_direction
	velocity.y = -bounce_power
	current_state = PlayerState.WALLJUMP
	_ignore_grounded_on_this_frame = true
	_play_sound(_boost_sound)

func kill() -> void:
	Global.player_lives -= 1
	Global.game_state = Global.GameState.GAME_OVER if Global.player_lives == 0 else Global.GameState.DEATH

# Private Functions
func _ready() -> void: # TODO: Rewrite
	Global.game_new_loop.connect(_game_reset)
	_game_reset(true)
	
	# create crafting sound player
	_crafting_sound_player = AudioStreamPlayer.new()
	_crafting_sound_player.stream = _crafting_sound
	add_child(_crafting_sound_player)

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or event.is_echo(): return
	if current_state == PlayerState.STUNNED: return
	
	var items_are_active : bool = _active_bridge_maker != null or _item_craft_progress != null
	if not items_are_active and event.is_released() and event.keycode == _active_powerup_key:
		_stop_powerups_if_using()
		return
	
	if not event.pressed: return
	var powerup = keys_to_powerup.get(event.keycode)
	if powerup == null: return
	if slimes_collected < powerup_to_slime_cost[powerup]: return
	_active_powerup_key = event.keycode
	_use_powerup(powerup)

func _physics_process(delta: float) -> void:
	_handle_player_items(delta)
	_handle_player_controls(delta)
	_handle_player_visuals()
	_handle_player_sounds()

func _process(delta: float) -> void:
	if Global.time_remaining <= 0:
		kill()
	
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
			
			_invincibility_frames_timer = move_toward(_invincibility_frames_timer, 0, delta)
			
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
	current_state = PlayerState.FREEMOVE
	_active_powerup_key = KEY_NONE
	_play_sound(_building_place_sound)
	_crafting_sound_player.stop()

func _game_reset(_new_round: bool):
	position = _start_pos
	velocity = Vector2.ZERO
	
	for snd in _active_sounds:
		snd.queue_free()
	_active_sounds = []
	
	facing_direction = 1
	_can_be_stunned = false
	current_state = PlayerState.FREEMOVE
	
	_jump_remaining = 0.0
	_stun_timer = 0.0
	_invincibility_frames_timer = 0.0
	_ignore_grounded_on_this_frame = false
	
	_item_craft_progress = null
	_active_bridge_maker = null
	_active_powerup_key = KEY_NONE
	_was_on_floor = true

func _meets_stamina_requirement(c: int) -> bool:
	return slimes_collected >= c

func _get_tiled_pos_of(pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(pos))

func _get_position_of_tile(coord: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(coord))

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

func _use_powerup(powerup: PowerupType):
	match powerup:
		PowerupType.BOMB:
			_begin_item_craft(0.5, 5, _prefab_bomb)
		PowerupType.BRIDGE:
			if is_on_floor(): return
			# place bridge maker if not on floor
			velocity.x = 0.0
			_active_bridge_maker = _prefab_bridge_maker.instantiate()
			
			# place bridge maker on the center of the cell below the player
			var player_bottom: Vector2i = global_position + Vector2.DOWN * $CollisionShape2D.shape.size.y / 2.0
			_active_bridge_maker.global_position = _get_position_of_tile((_get_tiled_pos_of(player_bottom) + Vector2i(0, 1)))
			add_sibling(_active_bridge_maker)
			_active_bridge_maker.activate()
			slimes_collected -= 8
		PowerupType.BOOSTER:
			_begin_item_craft(0.5, 6, _prefab_horiz_spring)
		PowerupType.SPRING:
			_begin_item_craft(0.5, 6, _prefab_spring)
		_:
			push_error("You cannot use the ", PowerupType.keys()[powerup], " as there is no code for it's usage!")

func _stop_powerups_if_using():
	# Deactivate bridge, if any
	if _active_bridge_maker != null:
		_active_bridge_maker.deactivate()
		_active_bridge_maker = null
	
	# Stop Item Craft, if any
	_item_craft_progress = null
	_active_powerup_key = KEY_NONE
	_crafting_sound_player.stop()

func _handle_player_sounds():
	if not _was_on_floor and is_on_floor():
		_play_sound(_landing_sound)
	if just_jumped:
		_play_sound(_jump_sound)
		just_jumped = false
	if previous_state != PlayerState.STUNNED and current_state == PlayerState.STUNNED:
		_play_sound(_hurt_sound)

func _handle_player_controls(delta: float) -> void:
	var move_dir := int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))
	
	if _handle_flight(OS.is_debug_build() && Input.is_key_pressed(KEY_SHIFT), delta): return
	
	var is_control_revoked := _active_bridge_maker != null or _item_craft_progress != null
	if is_control_revoked: return

	if move_dir != 0 and current_state != PlayerState.WALLSLIDE: facing_direction = move_dir
	previous_state = current_state
	
	_update_state(move_dir, delta)
	_handle_jump_and_fall(delta)
	_handle_horizontal_motion(move_dir, delta)
	
	_was_on_floor = is_on_floor()
	move_and_slide()

func _update_state(move_dir: int, delta: float):
	match current_state:
		PlayerState.FREEMOVE:
			if is_on_floor():
				_wall_away_direction = 0
			if move_dir != 0:
				facing_direction = move_dir
				if is_on_wall_only():
					_wall_away_direction = sign(get_wall_normal().x)
					facing_direction = _wall_away_direction 
					current_state = PlayerState.WALLSLIDE
		PlayerState.WALLSLIDE:
			if not is_on_wall_only():
				current_state = PlayerState.FREEMOVE
			if just_jumped_from_wall:
				current_state = PlayerState.WALLJUMP
		PlayerState.WALLJUMP:
			if is_on_wall_only():
				_jump_remaining = 0
				_wall_away_direction = sign(get_wall_normal().x)
				facing_direction = _wall_away_direction 
				current_state = PlayerState.WALLSLIDE
			elif is_on_floor():
				_jump_remaining = 0
				current_state = PlayerState.FREEMOVE
		PlayerState.CRAFTING:
			pass
		PlayerState.STUNNED:
			_stun_timer = move_toward(_stun_timer, 0, delta)
			if _stun_timer <= 0.0 and current_state == PlayerState.STUNNED:  
				current_state = PlayerState.FREEMOVE

func _handle_jump_and_fall(delta: float) -> void:
	if _can_jump(): _coyote_jump_timer = _COYOTE_JUMP_TIME
	
	var should_jump : bool = Input.is_action_just_pressed("player_jump") and _coyote_jump_timer > 0.0
	if should_jump:
		just_jumped = true
		_jump_remaining = 1.0

		if current_state == PlayerState.WALLSLIDE:
			facing_direction = _wall_away_direction
			just_jumped_from_wall = true

	_coyote_jump_timer = move_toward(_coyote_jump_timer, 0.0, delta)
	if _jump_remaining > 0.0:
		var jump_stopped_early : bool = not Input.is_action_pressed("player_jump") or is_on_ceiling()
		if jump_stopped_early:
			velocity.y *= _early_jump_damp
			_jump_remaining = 0.0
		else:
			velocity.y = -_jump_power * _jump_remaining
	
	velocity += get_gravity() * delta
	_jump_remaining = move_toward(_jump_remaining, 0.0, delta / _jump_length)
	
	if current_state == PlayerState.WALLSLIDE:
		var max_y_vel = get_gravity().y * _wall_slide_speed_limit * delta
		if velocity.y > max_y_vel: velocity.y = max_y_vel

func _handle_horizontal_motion(move_dir: int, delta: float) -> void:
	if current_state == PlayerState.WALLSLIDE and (move_dir == 0 or move_dir == -_wall_away_direction):
		velocity.x = -_wall_away_direction
		return
	
	var acceleration : float = _player_state_to_acceleration[current_state]
	var damping : float = _player_state_to_damping[current_state]

	if current_state == PlayerState.WALLJUMP and just_jumped_from_wall:
		just_jumped_from_wall = false
		velocity.x = _wall_away_direction * _wall_jump_initial_xboost
	
	velocity.x += acceleration * move_dir * delta
	velocity.x *= damping

func _handle_flight(flight: bool, delta: float):
	if !flight: return false
	
	const fly_speed := 1200.0
	var speed = fly_speed * delta
	
	var x_dir := int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))
	position.x += x_dir * speed
	
	var y_dir := int(Input.is_action_pressed("player_down")) - int(Input.is_action_pressed("player_up"))
	position.y += y_dir * speed

	return true

## Computes if the player is able to jump with member variable and methods.
func _can_jump() -> bool:
	var can_move_and_is_on_floor : bool = current_state == PlayerState.FREEMOVE and is_on_floor()
	var on_wall : bool = current_state == PlayerState.WALLSLIDE
	var not_making_bridge : bool = _active_bridge_maker == null
	return (can_move_and_is_on_floor or on_wall) and not_making_bridge

func _handle_player_visuals():
	var sprite = $AnimatedSprite2D
	var animation = "idle" if velocity.x == 0 else "run"
	
	if velocity.y > 0:
		animation = "jump"
	elif velocity.y < 0:
		animation = "fall"

	if current_state == PlayerState.WALLSLIDE:
		animation = "wallslide"

	if current_state == PlayerState.STUNNED:
		animation = "hurt"

	if sprite.animation != animation:
		sprite.animation = animation
		sprite.play()

	if facing_direction != 0:
		sprite.flip_h = facing_direction < 0

func _handle_player_items(delta: float):
	if _active_bridge_maker != null and not _active_bridge_maker.active:
		_active_bridge_maker = null

	if _item_craft_progress != null:
		current_state = PlayerState.CRAFTING
		_item_craft_progress.time_remaining -= delta
		if _item_craft_progress.time_remaining <= 0.0:
			_finish_item_craft()

	if _can_be_stunned and _invincibility_frames_timer <= 0.0:
		_stun_timer = _STUN_LENGTH
		_invincibility_frames_timer = _INVINCIBILITY_FRAMES_LENGTH
		current_state = PlayerState.STUNNED
		velocity = Vector2(0, -200)
		_stop_powerups_if_using()
