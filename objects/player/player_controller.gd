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

## The start position of the player, where it starts.
@onready var _start_pos : Vector2 = position

## The current state of the player.
var _current_state : PlayerState = PlayerState.FREEMOVE

## The previous state of the player.
var _previous_state : PlayerState = PlayerState.FREEMOVE

## The constant ratio of velocity.y and jump_remaining.
## Bigger the magnitude, Bigger the jump.
const _JUMP_POWER : float = 300.0

## The time it takes for the player to complete a jump.
const _JUMP_LENGTH : float = 0.5

## The damping of jumping velocity. Useful to control the variable jump height.
const _EARLY_JUMP_DAMP : float = 0.5

## The multiplier limit that forces wall slide speed not to increase indefinitely.
const _WALL_SLIDE_SPEED_LIMIT : float = 4.0

## The velocity boost in the x axis, while wall jumping.
const _WALL_JUMP_INITIAL_XBOOST : float = 230.0

## If jumped from or is on some wall, then it is the direction away from the wall with player being at the origin.
var _wall_away_direction : int = 0

## A variable to track the direction you are facing.
var _facing_direction: int = 1

## A variable to track if we are taking damage.
var _can_be_stunned: bool = false

## A variable to track the cardinality of deadly area, the player is in, to know about giving a stun.
var _deadly_area_count: int = 0

## A variable to track if the player was on floor at the previous frame to give a landing sound.
var _was_on_floor : bool = true

# One Time Signals
## A variable telling if you have just jumped, this frame.
var _just_jumped : bool = false

## A variable telling if you have just jumped from a wall, this frame.
var _just_jumped_from_wall : bool = false

## A variable telling you just used a spring.
var _just_used_spring : bool = false

## A variable telling you just used a booster.
var _just_used_booster : bool = false

## A variable telling you just used a bridge
var _just_used_bridge : bool = false

# Functions that you wouldn't touch. Increase the counter below whenever you touch it. A session may be considered a touch.
# No. of sessions that someone touched this is: 0
func _ready() -> void:
	Global.get_game().round_started.connect(game_reset)
	game_reset(true)
func game_reset(_new_round : bool) -> void:
	position = _start_pos
	velocity = Vector2.ZERO

	%ItemCrafter.reset()

	# Reseting all player variables
	_current_state = PlayerState.FREEMOVE
	_previous_state = PlayerState.FREEMOVE
	_deadly_area_count = 0
	_facing_direction = 1
	_can_be_stunned = false
	_was_on_floor = true
	
	_reset_one_use_sigals()

	# Deactivating all timers!
	for timer in Global.PLAYER_TIMERS:
		Global.deactivate_timer(timer)
func on_entered_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count + 1
	if _deadly_area_count > 0:
		_can_be_stunned = true
func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	if _deadly_area_count <= 0:
		_can_be_stunned = false
func _on_spring_bounce() -> void:
	Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)
	_just_used_spring = true
func _on_booster_bounce() -> void:
	_just_used_booster = true
	_current_state = PlayerState.WALLJUMP
func _physics_process(delta: float) -> void:
	_handle_player_controls(delta)
	_handle_player_visuals()
	_handle_player_sounds()
	_update_timers(delta)
	_reset_one_use_sigals()
func _reset_one_use_sigals() -> void:
	_just_jumped = false
	_just_jumped_from_wall = false
	_just_used_spring = false
	_just_used_booster = false
	_just_used_bridge = false
func _update_timers(delta: float) -> void:
	for timer in Global.PLAYER_TIMERS:
		if timer == Global.TimerType.JUMP_PROGRESS:
			Global.update_timer(timer, delta / _JUMP_LENGTH)
			continue
		Global.update_timer(timer, delta)
func _process(delta: float) -> void:
	_previous_state = _current_state
	_handle_state_transitions()
func kill() -> void:
	Global.get_game().player_lives -= 1
	
	if Global.get_game().player_lives == 0:
		print("Game over")
		#Global.get_game().game_state = Global.GameState.GAME_OVER
		
	else:
		print("Normal death")
		#Global.game_state = Global.GameState.DEATH
func _handle_flight(flight: bool, delta: float) -> bool:
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
	if _can_be_stunned and not Global.is_timer_active(Global.TimerType.STUN) \
	and not Global.is_timer_active(Global.TimerType.INVINCIBILITY)\
	and _current_state != PlayerState.STUNNED:
		Global.activate_timer(Global.TimerType.STUN)
		_current_state = PlayerState.STUNNED
		%ItemCrafter.enabled = false
		return
	match _current_state:
		PlayerState.FREEMOVE:
			if is_on_floor():
				_wall_away_direction = 0
			var move_dir = _compute_move_dir()
			if move_dir != 0:
				_facing_direction = move_dir
				if is_on_wall_only():
					_wall_away_direction = sign(get_wall_normal().x)
					_facing_direction = _wall_away_direction 
					_current_state = PlayerState.WALLSLIDE
		PlayerState.WALLSLIDE:
			if not is_on_wall_only():
				_current_state = PlayerState.FREEMOVE
			if _just_jumped_from_wall:
				_current_state = PlayerState.WALLJUMP
		PlayerState.WALLJUMP:
			if is_on_wall_only():
				Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)
				_wall_away_direction = sign(get_wall_normal().x)
				_facing_direction = _wall_away_direction 
				_current_state = PlayerState.WALLSLIDE
			elif is_on_floor():
				Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)
				_current_state = PlayerState.FREEMOVE
		PlayerState.CRAFTING:
			if Global.is_timer_active(Global.TimerType.CRAFTING):
				_current_state = PlayerState.FREEMOVE
		PlayerState.STUNNED:
			if not Global.is_timer_active(Global.TimerType.STUN) and _current_state == PlayerState.STUNNED:
				Global.activate_timer(Global.TimerType.INVINCIBILITY)
				_current_state = PlayerState.FREEMOVE
				%ItemCrafter.enabled = true

## Moves player based on inputs and states.
func _handle_player_controls(delta: float) -> void:
	if _handle_flight(OS.is_debug_build() && Input.is_key_pressed(KEY_SHIFT), delta):
		return

	var is_control_revoked : bool = %ItemCrafter.is_crafting()
	if is_control_revoked:
		return

	var move_dir : int = _compute_move_dir()
	if move_dir != 0 and _current_state != PlayerState.WALLSLIDE:
		_facing_direction = move_dir
	
	_handle_jump_and_fall(delta)
	_handle_horizontal_motion(move_dir, delta)
	
	_was_on_floor = is_on_floor()
	move_and_slide()

## Moves player in Y axis based on inputs and states.
func _handle_jump_and_fall(delta: float) -> void:
	if _just_used_spring:
		velocity.y = -Spring.BOUNCE_POWER
		return
	elif _just_used_booster:
		velocity.y = -Booster.BOUNCE_POWER
		return
	elif _just_used_bridge:
		velocity.y = 0
		print("used bridge")
		return

	if _can_jump():
		Global.activate_timer(Global.TimerType.COYOTE)
	
	var should_jump : bool = Input.is_action_just_pressed("player_jump") and Global.is_timer_active(Global.TimerType.COYOTE)
	if should_jump:
		_just_jumped = true
		Global.activate_timer(Global.TimerType.JUMP_PROGRESS)

		if _current_state == PlayerState.WALLSLIDE:
			_facing_direction = _wall_away_direction
			_just_jumped_from_wall = true

	if Global.is_timer_active(Global.TimerType.JUMP_PROGRESS):
		var jump_stopped_early : bool = not Input.is_action_pressed("player_jump") or is_on_ceiling()
		if jump_stopped_early:
			velocity.y *= _EARLY_JUMP_DAMP
			Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)
		else:
			velocity.y = -_JUMP_POWER * Global.get_time_of(Global.TimerType.JUMP_PROGRESS)

	velocity += get_gravity() * delta

	if _current_state == PlayerState.WALLSLIDE:
		var max_y_vel = get_gravity().y * _WALL_SLIDE_SPEED_LIMIT * delta
		if velocity.y > max_y_vel: velocity.y = max_y_vel

## Moves player in X axis based on inputs and states.
func _handle_horizontal_motion(move_dir: int, delta: float) -> void:
	if %ItemCrafter.is_item_active_or_crafting():
		velocity.x = 0
		return

	if _current_state == PlayerState.WALLSLIDE and (move_dir == 0 or move_dir == -_wall_away_direction):
		velocity.x = -_wall_away_direction
		return
	
	if _just_used_booster:
		velocity.x = Booster.SIDE_POWER * _facing_direction
		return
	
	var acceleration : float = player_state_to_acceleration[_current_state]
	var damping : float = player_state_to_damping[_current_state]

	if _current_state == PlayerState.WALLJUMP and _just_jumped_from_wall:
		velocity.x = _wall_away_direction * _WALL_JUMP_INITIAL_XBOOST
	
	velocity.x += acceleration * move_dir * delta
	velocity.x *= damping

## Returns if player can jump in the current frame.
func _can_jump() -> bool:
	var can_move_and_is_on_floor : bool = _current_state == PlayerState.FREEMOVE and is_on_floor()
	var on_wall : bool = _current_state == PlayerState.WALLSLIDE
	var using_powerup : bool = %ItemCrafter.is_item_active_or_crafting()
	return (can_move_and_is_on_floor or on_wall) and not using_powerup

## Returns the direction where player should face in accordance with the inputs.
func _compute_move_dir() -> int:
	if %ItemCrafter.is_item_active_or_crafting():
		return 0
	return int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))

## Handles how player looks
func _handle_player_visuals():
	visible = true
	var sprite = $AnimatedSprite2D
	var animation = "idle" if _compute_move_dir() == 0 else "run"
	
	if velocity.y > 0:
		animation = "jump"
	elif velocity.y < 0:
		animation = "fall"

	if _current_state == PlayerState.WALLSLIDE:
		animation = "wallslide"

	if _current_state == PlayerState.STUNNED:
		animation = "hurt"

	if sprite.animation != animation:
		sprite.animation = animation
		sprite.play()

	if _facing_direction != 0:
		sprite.flip_h = _facing_direction < 0
	
	if _current_state == PlayerState.STUNNED:
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		modulate = Color(1.0, 0.0, 0.0) if t < 0.5 else Color(1.0, 1.0, 1.0)
		return
	modulate = Color(1.0, 1.0, 1.0)
		
	# flash visible/invisible while iframes are active
	if Global.is_timer_active(Global.TimerType.INVINCIBILITY):
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		visible = t < 0.5
	
	# crafting animation will stretch out the player a little bit
	# stretching increases as it gets closer to being finishedD
	if Global.is_timer_active(Global.TimerType.CRAFTING):
		var t: float = 1.0 - Global.get_time_of(Global.TimerType.CRAFTING) / Global.get_activation_time_of(Global.TimerType.CRAFTING)
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
	if _just_jumped:
		%SoundManager.play(SoundManager.Sound.JUMP)
	if _previous_state != PlayerState.STUNNED and _current_state == PlayerState.STUNNED:
		%SoundManager.play(SoundManager.Sound.HURT)
	if _just_used_spring or _just_used_booster:
		%SoundManager.play(SoundManager.Sound.BOOST)


func _on_item_crafter_bridge_used() -> void:
	_just_used_bridge = true
