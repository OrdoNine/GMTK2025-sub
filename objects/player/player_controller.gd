extends CharacterBody2D
class_name Player

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

## The current state of the player.
var current_state := PlayerState.FREEMOVE

## The previous state of the player.
var previous_state : PlayerState = PlayerState.FREEMOVE

# Timers
## The time which is given after the moment you no longer can jump, in which you may jump anyway.
## Example: If you failed the last moment jump by a millisecond, you are still fine and we'll let you jump.
const _COYOTE_JUMP_TIME := 0.13

## A variable to track the time since the last moment, you no longer could jump.
var _coyote_jump_timer := 0.0

## The time after you got stunned, where you stay stunned.
const _STUN_LENGTH := 2.0

## A variable to track time from the last moment you got stunned.
var _stun_timer: float = 0.0

## The time after death when you are invincible to spikes and such.
const _INVINCIBILITY_LENGTH := 2.0

## A variable to track time from the last time you got hurt from a spike. Animation Purposes
var _invincibility_timer: float = 0.0


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

## A variable telling if you have just jumped, this frame.
var just_jumped : bool = false

## A variable telling if you have just jumped from a wall, this frame.
var just_jumped_from_wall : bool = false

## If jumped from or is on some wall, then it is the direction away from the wall with player being at the origin.
var _wall_away_direction : int = 0

## A map from player state to acceleration used.
const player_state_to_acceleration : Dictionary[PlayerState, float] = {
	PlayerState.FREEMOVE: 3800,
	PlayerState.WALLSLIDE: 1400,
	PlayerState.WALLJUMP: 450,
	PlayerState.CRAFTING: 0,
	PlayerState.STUNNED: 0.
}

## A map from player state to damping used.
const player_state_to_damping: Dictionary[PlayerState, float] = {
	PlayerState.FREEMOVE: 0.8,
	PlayerState.WALLSLIDE: 0.8,
	PlayerState.WALLJUMP: 0.98,
	PlayerState.CRAFTING: 0,
	PlayerState.STUNNED: 0,
}

## A variable to track the direction you are facing.
var facing_direction: int = 1

## A variable to track if we are taking damage.
var _can_be_stunned: bool = false

## A variable to track the cardinality of deadly area, the player is in, to know about giving a stun.
var _deadly_area_count: int = 0

## A variable to track if the player was on floor at the previous frame to give a landing sound.
var _was_on_floor := true

## The start position of the player, where it starts.
@onready var _start_pos := position

# Functions that you wouldn't touch. Increase the counter below whenever you touch it. A session may be considered a touch.
# No. of sessions that someone touched this is: 0
func _ready() -> void:
	Global.get_game().round_started.connect(game_reset)
	game_reset()
func game_reset():
	position = _start_pos
	velocity = Vector2.ZERO
	
	facing_direction = 1
	_can_be_stunned = false
	current_state = PlayerState.FREEMOVE
	
	_jump_remaining = 0.0
	_stun_timer = 0.0
	_invincibility_timer = 0.0
	
	_was_on_floor = true
	
	%ItemCrafter.reset()
func on_entered_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count + 1
	if _deadly_area_count > 0:
		_can_be_stunned = true
func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	if _deadly_area_count <= 0:
		_can_be_stunned = false
func spring_bounce_callback(bounce_power: float) -> void:
	_jump_remaining = 0.0
	velocity.y = -bounce_power
	SoundManager.play(SoundManager.Sound.BOOST)
func horiz_spring_bounce_callback(bounce_power: float, side_power: float) -> void:
	velocity.x = side_power * facing_direction
	velocity.y = -bounce_power
	current_state = PlayerState.WALLJUMP
	SoundManager.play(SoundManager.Sound.BOOST)
func _physics_process(delta: float) -> void:
	_handle_player_controls(delta)
	_handle_player_visuals()
	_handle_player_sounds()
	
	# Updating timer.
	_stun_timer = move_toward(_stun_timer, 0, delta)
	_invincibility_timer = move_toward(_invincibility_timer, 0, delta)
	_coyote_jump_timer = move_toward(_coyote_jump_timer, 0.0, delta)
func _process(delta: float) -> void:
	previous_state = current_state
	_handle_state_transitions()
func kill() -> void:
	Global.get_game().player_lives -= 1
	
	if Global.get_game().player_lives == 0:
		print("Game over")
		#Global.get_game().game_state = Global.GameState.GAME_OVER
		
	else:
		print("Normal death")
		#Global.game_state = Global.GameState.DEATH
func _handle_flight(flight: bool, delta: float):
	if !flight: return false
	
	const fly_speed := 1200.0
	var speed = fly_speed * delta
	
	var x_dir := int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))
	position.x += x_dir * speed
	
	var y_dir := int(Input.is_action_pressed("player_down")) - int(Input.is_action_pressed("player_up"))
	position.y += y_dir * speed

	return true

# Functions that you actually might need to touch
## This method handles state transitions. It is only for checking things and changing states.[br]
## Everything in this must be related to changing player state. And nothing outside this method
## should be related to state transitions.
func _handle_state_transitions():
	match current_state:
		PlayerState.FREEMOVE:
			if is_on_floor():
				_wall_away_direction = 0
			var move_dir = compute_move_dir()
			if move_dir != 0:
				facing_direction = move_dir
				if is_on_wall_only():
					_wall_away_direction = sign(get_wall_normal().x)
					facing_direction = _wall_away_direction 
					current_state = PlayerState.WALLSLIDE
			if _can_be_stunned and _stun_timer <= 0 and _invincibility_timer <= 0:
				_stun_timer = _STUN_LENGTH
				current_state = PlayerState.STUNNED
		PlayerState.WALLSLIDE:
			if not is_on_wall_only():
				current_state = PlayerState.FREEMOVE
			if just_jumped_from_wall:
				current_state = PlayerState.WALLJUMP
			if _can_be_stunned and _stun_timer <= 0 and _invincibility_timer <= 0:
				_stun_timer = _STUN_LENGTH
				current_state = PlayerState.STUNNED
		PlayerState.WALLJUMP:
			if is_on_wall_only():
				_jump_remaining = 0
				_wall_away_direction = sign(get_wall_normal().x)
				facing_direction = _wall_away_direction 
				current_state = PlayerState.WALLSLIDE
			elif is_on_floor():
				_jump_remaining = 0
				current_state = PlayerState.FREEMOVE
			if _can_be_stunned and _stun_timer <= 0 and _invincibility_timer <= 0:
				_stun_timer = _STUN_LENGTH
				current_state = PlayerState.STUNNED
		PlayerState.CRAFTING:
			if %ItemCrafter.crafting_timer == 0:
				current_state = PlayerState.FREEMOVE
			if _can_be_stunned and _stun_timer <= 0 and _invincibility_timer <= 0:
				_stun_timer = _STUN_LENGTH
				current_state = PlayerState.STUNNED
		PlayerState.STUNNED:
			if _stun_timer <= 0.0 and current_state == PlayerState.STUNNED:
				_invincibility_timer = _INVINCIBILITY_LENGTH
				current_state = PlayerState.FREEMOVE

## Moves player based on inputs and states.
func _handle_player_controls(delta: float) -> void:
	if _handle_flight(OS.is_debug_build() && Input.is_key_pressed(KEY_SHIFT), delta):
		return

	var is_control_revoked : bool = %ItemCrafter.is_crafting()
	if is_control_revoked:
		return

	var move_dir : int = compute_move_dir()
	if move_dir != 0 and current_state != PlayerState.WALLSLIDE:
		facing_direction = move_dir
	
	_handle_jump_and_fall(delta)
	_handle_horizontal_motion(move_dir, delta)
	
	_was_on_floor = is_on_floor()
	move_and_slide()

## Moves player in Y axis based on inputs and states.
func _handle_jump_and_fall(delta: float) -> void:
	if _can_jump():
		_coyote_jump_timer = _COYOTE_JUMP_TIME
	
	var should_jump : bool = Input.is_action_just_pressed("player_jump") and _coyote_jump_timer > 0.0
	if should_jump:
		just_jumped = true
		_jump_remaining = 1.0

		if current_state == PlayerState.WALLSLIDE:
			facing_direction = _wall_away_direction
			just_jumped_from_wall = true

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

## Moves player in X axis based on inputs and states.
func _handle_horizontal_motion(move_dir: int, delta: float) -> void:
	if %ItemCrafter.is_item_active_or_crafting():
		velocity.x = 0
		return

	if current_state == PlayerState.WALLSLIDE and (move_dir == 0 or move_dir == -_wall_away_direction):
		velocity.x = -_wall_away_direction
		return
	
	var acceleration : float = player_state_to_acceleration[current_state]
	var damping : float = player_state_to_damping[current_state]

	if current_state == PlayerState.WALLJUMP and just_jumped_from_wall:
		just_jumped_from_wall = false
		velocity.x = _wall_away_direction * _wall_jump_initial_xboost
	
	velocity.x += acceleration * move_dir * delta
	velocity.x *= damping

## Returns if player can jump in the current frame.
func _can_jump() -> bool:
	var can_move_and_is_on_floor : bool = current_state == PlayerState.FREEMOVE and is_on_floor()
	var on_wall : bool = current_state == PlayerState.WALLSLIDE
	var using_powerup : bool = %ItemCrafter.is_item_active_or_crafting()
	return (can_move_and_is_on_floor or on_wall) and not using_powerup

## Returns the direction where player should face in accordance with the inputs.
func compute_move_dir() -> int:
	if %ItemCrafter.is_item_active_or_crafting():
		return 0
	return int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))

## Handles how player looks
func _handle_player_visuals():
	visible = true
	var sprite = $AnimatedSprite2D
	var animation = "idle" if compute_move_dir() == 0 else "run"
	
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
	
	if current_state == PlayerState.STUNNED:
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		modulate = Color(1.0, 0.0, 0.0) if t < 0.5 else Color(1.0, 1.0, 1.0)
		return
	modulate = Color(1.0, 1.0, 1.0)
		
	# flash visible/invisible while iframes are active
	if _invincibility_timer > 0.0:
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		visible = t < 0.5
	
	# crafting animation will stretch out the player a little bit
	# stretching increases as it gets closer to being finishedD
	if %ItemCrafter.crafting_timer > 0:
		var t: float = 1.0 - %ItemCrafter.crafting_timer / %ItemCrafter.CRAFTING_TIME
		sprite.scale = Vector2(
			pow(2, t * 0.4),
			pow(2, -t * 0.4)
		)
	else:
		sprite.scale = Vector2.ONE

## Handles sounds made by player.
func _handle_player_sounds():
	if not _was_on_floor and is_on_floor():
		%SoundManager.play(SoundManager.Sound.LAND)
	if just_jumped:
		%SoundManager.play(SoundManager.Sound.JUMP)
		just_jumped = false
	if previous_state != PlayerState.STUNNED and current_state == PlayerState.STUNNED:
		%SoundManager.play(SoundManager.Sound.HURT)
