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
	BOOST,
}

## A map from player state to acceleration used.
const player_state_to_acceleration : Dictionary[PlayerState, float] = {
	PlayerState.FREEMOVE: 3800,
	PlayerState.WALLSLIDE: 1400,
	PlayerState.WALLJUMP: 450,
	PlayerState.BOOST: 450,
}

## A map from player state to damping used.
# TODO: Compute it so that max velocity is same for all.
const player_state_to_damping: Dictionary[PlayerState, float] = {
	PlayerState.FREEMOVE: 0.8,
	PlayerState.WALLSLIDE: 0.8,
	PlayerState.WALLJUMP: 0.98,
	PlayerState.BOOST: 0.98,
}

## The start position of the player, where it starts.
@onready var _start_pos : Vector2 = position

## The current state of the player.
var _current_state : PlayerState = PlayerState.FREEMOVE :
	set(x):
		if x != _current_state:
			if Input.is_key_pressed(KEY_T):
				print("T PRESSED!")
			if OS.is_debug_build():
				print(PlayerState.keys()[_current_state], " -> ", PlayerState.keys()[x])
			_current_state = x

## The previous state of the player.
var _previous_state : PlayerState = PlayerState.FREEMOVE

## The velocity of the jump at the moment it was pressed. The velocity
## decreases over time, according to the progress of the jump timer.
const _JUMP_POWER : float = 300.0	

## The time it takes for the player to complete a jump.
const _JUMP_LENGTH : float = 0.5

## The damping of jumping velocity. Useful to control the variable jump height.
const _EARLY_JUMP_DAMP : float = 0.5

## The multiplier limit that forces wall slide speed not to increase indefinitely.
const _WALL_SLIDE_SPEED_LIMIT : float = 4.0

## The velocity boost in the x axis, while wall jumping.
const _WALL_JUMP_INITIAL_XBOOST : float = 230.0

## If jumped from or is on some wall, then it is the direction away from the
## wall with player being at the origin.
var _wall_away_direction : int = 0

## A variable to track the direction you are facing.
var _facing_direction: int = 1

## A variable to track if we are taking damage.
var _can_be_stunned: bool = false

## A variable to track the cardinality of deadly area, the player is in, to know about giving a stun.
var _deadly_area_count: int = 0

## A variable to track if the player was on floor at the previous frame to give a landing sound.
var _was_on_floor : bool = true

## A variable to track if you are stunned.
var _stunned : bool = false

## When this variable is non-zero, the player's velocity will be set to this
## and this variable will be reset afterwards. Intended to be used by code that
## handles boost/spring.
var _boost : Vector2 = Vector2.ZERO

# Functions that you wouldn't touch.
func on_entered_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count + 1
	if _deadly_area_count > 0:
		_can_be_stunned = true

func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	if _deadly_area_count <= 0:
		_can_be_stunned = false

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
	
	_boost = Vector2.ZERO

	# Deactivating all timers!
	for timer in Global.PLAYER_TIMERS:
		Global.deactivate_timer(timer)

func _on_spring_bounce(bounce_power: float) -> void:
	_boost = Vector2(0, bounce_power)
	Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)

func _on_booster_bounce(side_power: float, bounce_power: float) -> void:
	_boost = Vector2(side_power * _facing_direction, -bounce_power)
	_current_state = PlayerState.WALLJUMP #TODO: REMOVE THIS LINE

func _on_item_crafter_bridge_used() -> void:
	velocity.y = 0 # IMO, a valid exception to not be in the update velocites.

func _physics_process(delta: float) -> void:
	_handle_player_controls(delta)
	_handle_player_visuals()
	_update_timers(delta)
	_previous_state = _current_state
	_handle_state_transitions()

func _update_timers(delta: float) -> void:
	for timer in Global.PLAYER_TIMERS:
		if timer == Global.TimerType.JUMP_PROGRESS:
			Global.update_timer(timer, delta / _JUMP_LENGTH)
			continue
		Global.update_timer(timer, delta)

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
func _update_player_velocities(move_dir: int, delta: float) -> void:
	var acceleration : float = player_state_to_acceleration[_current_state]
	var damping : float = player_state_to_damping[_current_state]
	
	match _current_state:
		PlayerState.FREEMOVE:
			var can_jump_from_floor = is_on_floor()
			if can_jump_from_floor:
				Global.deactivate_timer(Global.TimerType.WALLJUMP_COYOTE)
				Global.activate_timer(Global.TimerType.COYOTE)

			if _should_jump():
				if Global.is_timer_active(Global.TimerType.COYOTE):
					Global.play(Global.Sound.JUMP) # Play the jump sound.
					Global.activate_timer(Global.TimerType.JUMP_PROGRESS) # Activate the timer.

				if Global.is_timer_active(Global.TimerType.WALLJUMP_COYOTE):
					velocity.x = _wall_away_direction * _WALL_JUMP_INITIAL_XBOOST # Gives the xboost
					Global.play(Global.Sound.JUMP) # Play the jump sound.
					Global.activate_timer(Global.TimerType.JUMP_PROGRESS) # Activate the timer.

			_update_jump_if_needed(delta)

			velocity += get_gravity() * delta
			
			velocity.x += acceleration * move_dir * delta
			velocity.x *= damping
			
			if %ItemCrafter.is_item_active_or_crafting() or _stunned:
				velocity.x = 0
		PlayerState.WALLSLIDE:
			Global.activate_timer(Global.TimerType.COYOTE)

			if move_dir != _wall_away_direction:
				velocity.x = -_wall_away_direction
				Global.activate_timer(Global.TimerType.WALLJUMP_COYOTE)

			if _should_jump():
				_facing_direction = _wall_away_direction
				velocity.x = _wall_away_direction * _WALL_JUMP_INITIAL_XBOOST
				Global.activate_timer(Global.TimerType.JUMP_PROGRESS) # Activate the timer.
				Global.play(Global.Sound.JUMP) # Play the jump sound.

			velocity += get_gravity() * delta

			var max_y_vel = get_gravity().y * _WALL_SLIDE_SPEED_LIMIT * delta
			if velocity.y > max_y_vel:
				velocity.y = max_y_vel
		PlayerState.WALLJUMP:
			_update_jump_if_needed(delta)

			velocity += get_gravity() * delta

			velocity.x += acceleration * move_dir * delta
			velocity.x *= damping

			if %ItemCrafter.is_item_active_or_crafting() or _stunned:
				velocity.x = 0
		PlayerState.BOOST:
			if _boost != Vector2.ZERO:
				velocity = _boost
				_boost = Vector2.ZERO

			velocity += get_gravity() * delta
			
			velocity.x += acceleration * move_dir * delta
			velocity.x *= damping

## This method handles state transitions. It is only for checking things and changing states.[br]
## Everything in this must be related to changing player state. And nothing outside this method
## should be related to state transitions.
func _handle_state_transitions() -> void:
	# TODO: Move this shit out from here.
	# TODO: So much mental load!!
	# Handling Stun
	if _should_stun() and not _stunned:
		_stunned = true
		%ItemCrafter.enabled = false
		Global.play(Global.Sound.HURT)
		Global.activate_timer(Global.TimerType.STUN)

	if _stunned and not Global.is_timer_active(Global.TimerType.STUN):
		_stunned = false
		Global.activate_timer(Global.TimerType.INVINCIBILITY)
		_current_state = PlayerState.FREEMOVE
		%ItemCrafter.enabled = true
		return

	if _boost != Vector2.ZERO and _current_state != PlayerState.BOOST:
		_current_state = PlayerState.BOOST
		Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)
		return

	match _current_state:
		PlayerState.FREEMOVE:
			if is_on_floor():
				_wall_away_direction = 0

			if _should_jump():
				if Global.is_timer_active(Global.TimerType.WALLJUMP_COYOTE):
					Global.deactivate_timer(Global.TimerType.WALLJUMP_COYOTE)
					_current_state = PlayerState.WALLJUMP

			var move_dir = _compute_move_dir()
			if move_dir != 0:
				_facing_direction = move_dir
				if is_on_wall_only():
					_wall_away_direction = sign(get_wall_normal().x)
					_facing_direction = _wall_away_direction 
					_current_state = PlayerState.WALLSLIDE
		PlayerState.WALLSLIDE:
			if Global.is_timer_active(Global.TimerType.JUMP_PROGRESS):
				_current_state = PlayerState.WALLJUMP
			if _stunned or not is_on_wall_only():
				_current_state = PlayerState.FREEMOVE
		PlayerState.WALLJUMP:
			if is_on_wall_only():
				Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)
				_wall_away_direction = sign(get_wall_normal().x)
				_facing_direction = _wall_away_direction
				_current_state = PlayerState.WALLSLIDE
			elif is_on_floor():
				Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)
				_current_state = PlayerState.FREEMOVE
		PlayerState.BOOST:
			if is_on_wall_only():
				_wall_away_direction = sign(get_wall_normal().x)
				_facing_direction = _wall_away_direction 
				_current_state = PlayerState.WALLSLIDE
			elif is_on_floor():
				_current_state = PlayerState.FREEMOVE

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
	
	_update_player_velocities(move_dir, delta)
	
	# If you landed, then play the land sound.
	var just_landed = not _was_on_floor and is_on_floor()
	if just_landed:
		Global.play(Global.Sound.LAND)

	_was_on_floor = is_on_floor()
	move_and_slide()

## Returns if you should jump without coyote stuff
func _should_jump():
	return Input.is_action_just_pressed("player_jump") and not _stunned

func _update_jump_if_needed(delta: float) -> void:
	if Global.is_timer_active(Global.TimerType.JUMP_PROGRESS) and not _stunned:
		var continue_jumping : bool = Input.is_action_pressed("player_jump") and not is_on_ceiling()
		if continue_jumping:
			velocity.y = -_JUMP_POWER * Global.get_time_of(Global.TimerType.JUMP_PROGRESS)
		else:
			velocity.y *= _EARLY_JUMP_DAMP
			Global.deactivate_timer(Global.TimerType.JUMP_PROGRESS)

## Returns if you should stun the player
func _should_stun() -> bool:
	var not_stunned = not Global.is_timer_active(Global.TimerType.STUN)
	var not_invincible = not Global.is_timer_active(Global.TimerType.INVINCIBILITY)
	return _can_be_stunned and not_stunned and not_invincible

## Returns the direction where player should face in accordance with the inputs.
func _compute_move_dir() -> int:
	if %ItemCrafter.is_item_active_or_crafting():
		return 0
	return int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))

## Handles how player looks
func _handle_player_visuals() -> void:
	visible = true
	var sprite = $AnimatedSprite2D
	var animation = "idle" if _compute_move_dir() == 0 else "run"
	
	if velocity.y > 0:
		animation = "jump"
	elif velocity.y < 0:
		animation = "fall"

	if _current_state == PlayerState.WALLSLIDE:
		animation = "wallslide"

	if _stunned:
		animation = "hurt"

	if sprite.animation != animation:
		sprite.animation = animation
		sprite.play()

	if _facing_direction != 0:
		sprite.flip_h = _facing_direction < 0
	
	if _stunned:
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
