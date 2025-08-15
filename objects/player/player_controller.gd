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
enum MovementState {
	FREEMOVE,
	WALLSLIDE,
	WALLJUMP,
	BOOST,
}
var movement_states : Dictionary[MovementState, MovementStateBase] = {
	MovementState.FREEMOVE: Freemove.new(self),
	MovementState.WALLSLIDE: Wallslide.new(self),
	MovementState.WALLJUMP: Walljump.new(self),
	MovementState.BOOST: Boost.new(self),
}

## A map from player state to acceleration used.
const movement_state_to_acceleration : Dictionary[MovementState, float] = {
	MovementState.FREEMOVE: 3800,
	MovementState.WALLSLIDE: 1400,
	MovementState.WALLJUMP: 450,
	MovementState.BOOST: 450,
}

## A map from player state to damping used.
# TODO: Compute it so that max velocity is same for all.
const movement_state_to_damping: Dictionary[MovementState, float] = {
	MovementState.FREEMOVE: 0.8,
	MovementState.WALLSLIDE: 0.8,
	MovementState.WALLJUMP: 0.98,
	MovementState.BOOST: 0.98,
}

## The start position of the player, where it starts.
@onready var _start_pos : Vector2 = position

## The current state of the player.
var _current_state : MovementState = MovementState.FREEMOVE

## The velocity of the jump at the moment it was pressed. The velocity
## decreases over time, according to the progress of the jump timer.
const _JUMP_POWER : float = 300.0

## The damping of jumping velocity. Useful to control the variable jump height.
const _EARLY_JUMP_DAMP : float = 0.5

## The multiplier limit that forces wall slide speed not to increase indefinitely.
const WALL_SLIDE_SPEED_LIMIT : float = 4.0

## The velocity boost in the x axis, while wall jumping.
const WALL_JUMP_INITIAL_XBOOST : float = 230.0

# Timers
var freemove_coyote_timer := PollTimer.new(0.13)
var walljump_coyote_timer := PollTimer.new(0.13)
var _invincibility_timer := PollTimer.new(2)
var _stun_timer := PollTimer.new(2)
var jump_progress_timer := PollTimer.new(0.5)

var timers : Array[PollTimer] = [
	freemove_coyote_timer,
	walljump_coyote_timer,
	_invincibility_timer,
	_stun_timer,
	jump_progress_timer,
]

## If jumped from or is on some wall, then it is the direction away from the
## wall with player being at the origin.
var wall_away_direction : int = 0

## A variable to track the direction you are facing.
var facing_direction: int = 1

## A variable to track if we are taking damage.
var _can_be_stunned: bool = false

## A variable to track the cardinality of deadly area, the player is in, to know about giving a stun.
var _deadly_area_count: int = 0

## A variable to track if the player was on floor at the previous frame to give a landing sound.
var _was_on_floor : bool = true

## A variable to track if you are stunned.
var stunned : bool = false

## A variable that will state if player has jumped from the floor.
var jumped_from_floor : bool = false

## When this variable is non-zero, the player's velocity will be set to this
## and this variable will be reset afterwards. Intended to be used by code that
## handles boost/spring.
var boost : Vector2 = Vector2.ZERO

@onready var item_crafter := %ItemCrafter

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
	_current_state = MovementState.FREEMOVE
	_deadly_area_count = 0
	facing_direction = 1
	_can_be_stunned = false
	_was_on_floor = true
	jumped_from_floor = false
	
	boost = Vector2.ZERO

	# Deactivating all timers!
	for timer in timers:
		timer.deactivate()

func _on_spring_bounce(bounce_power: float) -> void:
	boost = Vector2(0, -bounce_power)
	jump_progress_timer.deactivate()

func _onbooster_bounce(side_power: float, bounce_power: float) -> void:
	boost = Vector2(side_power * facing_direction, -bounce_power)
	_current_state = MovementState.WALLJUMP #TODO: REMOVE THIS LINE

func _on_item_crafter_bridge_used() -> void:
	velocity.y = 0 # IMO, a valid exception to not be in the update velocites.

func _physics_process(delta: float) -> void:
	_handle_player_controls(delta)
	_handle_player_visuals()
	_update_timers(delta)
	_handle_state_transitions()

func _update_timers(delta: float) -> void:
	for timer in timers:
		timer.update(delta)

func kill() -> void:
	Global.get_game().player_lives -= 1
	
	#if Global.get_game().player_lives == 0:
		#print("Game over")
		##Global.get_game().game_state = Global.GameState.GAME_OVER
		#
	#else:
		#print("Normal death")
		##Global.game_state = Global.GameState.DEATH

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
	var acceleration : float = movement_state_to_acceleration[_current_state]
	var damping : float = movement_state_to_damping[_current_state]
	movement_states[_current_state].update(move_dir, acceleration, damping, delta)

## This method handles state transitions. It is only for checking things and changing states.[br]
## Everything in this must be related to changing player state. And nothing outside this method
## should be related to state transitions.
func _handle_state_transitions() -> void:
	# TODO: Move this shit out from here.
	# TODO: So much mental load!!
	# Handling Stun
	if _should_stun() and not stunned:
		stunned = true
		%ItemCrafter.enabled = false
		Global.play(Global.Sound.HURT)
		_stun_timer.activate()

	if stunned and not _stun_timer.is_active:
		stunned = false
		_invincibility_timer.activate()
		_current_state = MovementState.FREEMOVE
		%ItemCrafter.enabled = true
		return

	if boost != Vector2.ZERO and _current_state != MovementState.BOOST:
		_current_state = MovementState.BOOST
		jump_progress_timer.deactivate()
		return

	match _current_state:
		MovementState.FREEMOVE:
			if is_on_floor():
				wall_away_direction = 0

			if should_jump():
				if walljump_coyote_timer.is_active:
					walljump_coyote_timer.deactivate()
					_current_state = MovementState.WALLJUMP

			var move_dir = _compute_move_dir()
			if move_dir != 0:
				facing_direction = move_dir
				if is_on_wall_only():
					wall_away_direction = sign(get_wall_normal().x)
					facing_direction = wall_away_direction 
					_current_state = MovementState.WALLSLIDE

		MovementState.WALLSLIDE:
			if stunned or not is_on_wall_only():
				_current_state = MovementState.FREEMOVE
			if jump_progress_timer.is_active and not jumped_from_floor:
				_current_state = MovementState.WALLJUMP

		MovementState.WALLJUMP:
			if is_on_wall_only():
				jump_progress_timer.deactivate()
				wall_away_direction = sign(get_wall_normal().x)
				facing_direction = wall_away_direction
				_current_state = MovementState.WALLSLIDE
			elif is_on_floor():
				jump_progress_timer.deactivate()
				_current_state = MovementState.FREEMOVE

		MovementState.BOOST:
			if is_on_wall_only():
				wall_away_direction = sign(get_wall_normal().x)
				facing_direction = wall_away_direction 
				_current_state = MovementState.WALLSLIDE
			elif is_on_floor():
				_current_state = MovementState.FREEMOVE

## Moves player based on inputs and states.
func _handle_player_controls(delta: float) -> void:
	if _handle_flight(OS.is_debug_build() && Input.is_key_pressed(KEY_SHIFT), delta):
		return

	var is_control_revoked : bool = %ItemCrafter.is_crafting()
	if is_control_revoked:
		return

	var move_dir : int = _compute_move_dir()
	if move_dir != 0 and _current_state != MovementState.WALLSLIDE:
		facing_direction = move_dir
	
	_update_player_velocities(move_dir, delta)
	
	# If you landed, then play the land sound.
	var just_landed = not _was_on_floor and is_on_floor()
	if just_landed:
		Global.play(Global.Sound.LAND)

	_was_on_floor = is_on_floor()
	move_and_slide()

## Returns if you should jump without coyote stuff
func should_jump():
	return Input.is_action_just_pressed("player_jump") and not stunned

func update_jump_if_needed() -> void:
	if jump_progress_timer.is_active and not stunned:
		var continue_jumping : bool = Input.is_action_pressed("player_jump") and not is_on_ceiling()
		if continue_jumping:
			velocity.y = -_JUMP_POWER * jump_progress_timer.get_progress_ratio()
		else:
			velocity.y *= _EARLY_JUMP_DAMP
			jump_progress_timer.deactivate()

## Returns if you should stun the player
func _should_stun() -> bool:
	var notstunned = not _stun_timer.is_active
	var not_invincible = not _invincibility_timer.is_active
	return _can_be_stunned and notstunned and not_invincible

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

	if _current_state == MovementState.WALLSLIDE:
		animation = "wallslide"

	if stunned:
		animation = "hurt"

	if sprite.animation != animation:
		sprite.animation = animation
		sprite.play()

	if facing_direction != 0:
		sprite.flip_h = facing_direction < 0
	
	if stunned:
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		modulate = Color(1.0, 0.0, 0.0) if t < 0.5 else Color(1.0, 1.0, 1.0)
		return
	modulate = Color(1.0, 1.0, 1.0)

	# flash visible/invisible while iframes are active
	if _invincibility_timer.is_active:
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		visible = t < 0.5

	# crafting animation will stretch out the player a little bit
	# stretching increases as it gets closer to being finishedD
	if %ItemCrafter._crafting_timer.is_active:
		var t: float = 1.0 - %ItemCrafter._crafting_timer.get_progress_ratio()
		sprite.scale = Vector2(
			pow(2, t * 0.4),
			pow(2, -t * 0.4)
		)
	else:
		sprite.scale = Vector2.ONE


class MovementStateBase:
	var player_handle : Player
	
	func _init(player: Player):
		player_handle = player
	
	func enter(_from: MovementState):
		pass
	
	func exit():
		pass
	
	func update(dir: int, acc: float, damp: float, dt: float):
		pass

class Freemove extends MovementStateBase:
	func update(dir: int, acc: float, damp: float, dt: float):
		var can_jump_from_floor = player_handle.is_on_floor()
		if can_jump_from_floor:
			player_handle.walljump_coyote_timer.deactivate()
			player_handle.freemove_coyote_timer.activate()

		if player_handle.should_jump():
			if player_handle.freemove_coyote_timer.is_active:
				Global.play(Global.Sound.JUMP) # Play the jump sound.
				player_handle.jump_progress_timer.activate() # Activate the timer.
				player_handle.jumped_from_floor = true

			if player_handle.walljump_coyote_timer.is_active:
				player_handle.velocity.x = player_handle.wall_away_direction * player_handle.WALL_JUMP_INITIAL_XBOOST # Gives the xboost
				Global.play(Global.Sound.JUMP) # Play the jump sound.
				player_handle.jump_progress_timer.activate() # Activate the timer.
				player_handle.jumped_from_floor = false

		player_handle.update_jump_if_needed()

		player_handle.velocity += player_handle.get_gravity() * dt
		
		player_handle.velocity.x += acc * dir * dt
		player_handle.velocity.x *= damp
		
		if player_handle.item_crafter.is_item_active_or_crafting() or player_handle.stunned:
			player_handle.velocity.x = 0
class Wallslide extends MovementStateBase:
	func update(dir: int, acc: float, damp: float, dt: float):
		if dir != player_handle.wall_away_direction:
			player_handle.velocity.x = -player_handle.wall_away_direction
			player_handle.walljump_coyote_timer.activate()

		if player_handle.should_jump():
			player_handle.facing_direction = player_handle.wall_away_direction
			player_handle.velocity.x = player_handle.wall_away_direction * player_handle.WALL_JUMP_INITIAL_XBOOST
			player_handle.jump_progress_timer.activate() # Activate the timer.
			Global.play(Global.Sound.JUMP) # Play the jump sound.
			player_handle.jumped_from_floor = false
		elif player_handle.jump_progress_timer.is_active:
			player_handle.update_jump_if_needed()

		player_handle.velocity += player_handle.get_gravity() * dt

		var max_y_vel = player_handle.get_gravity().y * player_handle.WALL_SLIDE_SPEED_LIMIT * dt
		if player_handle.velocity.y > max_y_vel:
			player_handle.velocity.y = max_y_vel
class Walljump extends MovementStateBase:
	func update(dir: int, acc: float, damp: float, dt: float):
		player_handle.update_jump_if_needed()

		player_handle.velocity += player_handle.get_gravity() * dt

		player_handle.velocity.x += acc * dir * dt
		player_handle.velocity.x *= damp

		if player_handle.item_crafter.is_item_active_or_crafting() or player_handle.stunned:
			player_handle.velocity.x = 0
class Boost extends MovementStateBase:
	func update(dir: int, acc: float, damp: float, dt: float):
		if player_handle.boost != Vector2.ZERO:
			player_handle.velocity = player_handle.boost
			player_handle.boost = Vector2.ZERO

		player_handle.velocity += player_handle.get_gravity() * dt
		
		player_handle.velocity.x += acc * dir * dt
		player_handle.velocity.x *= damp
