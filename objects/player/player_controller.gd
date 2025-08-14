# TODO:
# - rewrite the timer system
# - Fix walljump accel/damping (it's too slippery)
# - fix all the bugs with animations:
#   - head hitting.
#   - crafting animation.
#	- being able to turn around while stunned.
#   - being stunned while touching a wall will make you alternate facing
#     direction on every frame.
#   - being stunned does not make you hop up a little.
# - i think the stun check is messier because in pkrewrite, all it did was
#   disable jumping and movement, but in this code there's like a stun check in
#   something not related to movement? That doesn't seem good.
# - get rid of this completely and make it use my structure because this did
#   not click with me when i started editing it, unlike what you assumed would
#   happen.
# - use my code in pkrewrite which is already fully working so that we can stop
#   focusing on rewriting code that already works perfectly fine and actually
#   work on the game. yes i would like to have to jump across two different
#   methods while editing the code for each state, it is very helpful and
#   intuitive for reading and editing. it is just too complex and indirect for
#   state transitions to be permitted to be triggered from the actual state
#   code themselves, and instead i need to separate that to happen only within
#   a separate and (almost) independent function. it is folly to think physics
#   code is inherently intertwined with state transitions.
extends CharacterBody2D
class_name Player

# Constructs
## Consists of various states of Player according to which different actions happen in the script.
enum PlayerState {
	FREEMOVE, ## Normal grounded/mid-air movement
	WALLSLIDE, ## Wallsliding
	WALLJUMP, ## Jump from a wallslide, having diminished mid-air control.
	BOOST, ## Airborne after touching a booster, having heavily diminished mid-air contorl.
}

const PollTimer = preload("res://scripts/poll_timer.gd")

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

## The velocity of the jump at the moment it was pressed. The velocity
## decreases over time, according to the progress of the jump timer.
const _JUMP_POWER : float = 300.0

## The time it takes for the player to complete a jump.
const _JUMP_LENGTH : float = 0.5

## The damping of jumping velocity. Useful to control the variable jump height.
const _EARLY_JUMP_DAMP : float = 0.5

## The multiplier limit that forces wall slide speed not to increase indefinitely.
const _WALL_SLIDE_SPEED_LIMIT : float = 4.0

## The acceleration value of the player's X movement while wall-jumping.
## Higher values mean it is easier to control.
const _WALL_JUMP_CONTROL_ACCELERATION: float = 700.0

const COYOTE_TIME_LENGTH: float = 0.13
const IFRAME_LENGTH: float = 1.00
const STUN_LENGTH: float = 2.00
const MAX_JUMP_LENGTH: float = 0.5

## The current state of the player.
var _current_state : PlayerState = PlayerState.FREEMOVE

## The previous state of the player.
var _previous_state : PlayerState = PlayerState.FREEMOVE

## If jumped from or is on some wall, then it is the direction away from the
## wall with player being at the origin.
var _wall_away_direction : int = 0

## A variable to track the direction you are facing.
var _facing_direction: int = 1

## The number of hazard hitboxes that the player is currently touching.
var _deadly_area_count: int = 0

## If the player was on a floor on the previous frame. Used to play a landing
## sound.
var _was_on_floor : bool = true

var _stunned : bool = false

## When this variable is non-zero, the player's velocity will be set to this
## and this variable will be reset afterwards. Intended to be used by code that
## handles boost/spring.
var _boost : Vector2 = Vector2.ZERO

## for some reason
## get_time_of(jump_progress) == get_activation_time_of(jump_progress) is not
## working so i'm just going to make a new variable and besides it looked ugly
## anyway. this is a flag set from update_velocities to signal it is trying
## to do a walljump while wallsliding (not coyote time wall-jump).
var _walljump_request := false


# timers
var _coyote_timer := PollTimer.new(COYOTE_TIME_LENGTH)
var _iframe_timer := PollTimer.new(IFRAME_LENGTH)
var _stun_timer   := PollTimer.new(STUN_LENGTH)
var _jump_timer   := PollTimer.new(MAX_JUMP_LENGTH)
var _walljump_coyote_timer := PollTimer.new(COYOTE_TIME_LENGTH)
var _timer_list: Array[PollTimer] = [
	_coyote_timer,
	_iframe_timer,
	_stun_timer,
	_jump_timer
]

@onready var _start_pos : Vector2 = position

func _ready() -> void:
	Global.get_game().round_started.connect(game_reset)
	game_reset(true)


func _physics_process(delta: float) -> void:
	_handle_player_controls(delta)
	_handle_player_visuals()
	_update_timers(delta)
	_previous_state = _current_state
	_handle_state_transitions()


func _process(_delta):
	pass


func on_entered_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count + 1


func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1


func game_reset(_new_round : bool) -> void:
	position = _start_pos
	velocity = Vector2.ZERO

	%ItemCrafter.reset()

	# Reseting all player variables
	_current_state = PlayerState.FREEMOVE
	_previous_state = PlayerState.FREEMOVE
	_deadly_area_count = 0
	_facing_direction = 1
	_was_on_floor = true
	_boost = Vector2.ZERO

	# Deactivating all timers!
	for timer in _timer_list:
		timer.deactivate()


func _on_spring_bounce(bounce_power: float) -> void:
	_boost = Vector2(0, -bounce_power)
	_jump_timer.deactivate()


func _on_booster_bounce(side_power: float, bounce_power: float) -> void:
	_boost = Vector2(side_power * _facing_direction, -bounce_power)
	_current_state = PlayerState.WALLJUMP #TODO: REMOVE THIS LINE


func _on_item_crafter_bridge_used() -> void:
	velocity.y = 0 # IMO, a valid exception to not be in the update velocites.


func _update_timers(delta: float) -> void:
	for timer in _timer_list:
		timer.update(delta)


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
	
	var x_dir := (
			int(Input.is_action_pressed("player_right")) -
			int(Input.is_action_pressed("player_left")))
	position.x += x_dir * speed
	
	var y_dir := (
			int(Input.is_action_pressed("player_down")) - 
			int(Input.is_action_pressed("player_up")))
	position.y += y_dir * speed

	return true


# formula to obtain the maximum velocity given an acceleration (a) and a
# damping factor (k):
#	(this is the velocity function. v0 is the initial velocity)
#	(x is the integer number of frames that have elapsed since init velocity)
#	v(x) = v0*k^x + sum(n=1, x, a*k^n)
#	
#	lim v(x) as x -> inf = a / (1 - k) - a, as:
#		- sum(n=0, x, a*k^n) is a geometric series.
#		  the limit of this series is a / (1 - k). subtract a to remove the n=0
#		  term.
#		- v0*k^x approaches 0 if 0 <= k < 1. if k < 0, limit does not exist. if
#		- k >= 1, limit approaches infinity.
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
		player_state_to_acceleration[PlayerState.FREEMOVE],
		player_state_to_damping[PlayerState.FREEMOVE])
	
	var wall_jump_damping := calc_damping_from_limit(
		normal_movement_limit,
		_WALL_JUMP_CONTROL_ACCELERATION)
	
	return wall_jump_damping


# Functions that you actually might need to touch
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


func transition_to_walljump():
	assert(_wall_away_direction != 0)
	var snd := Global.play(Global.Sound.JUMP)
	if snd:
		snd.pitch_scale = 1.0 + randf() * 0.1
	
	_jump_timer.activate()
	_walljump_coyote_timer.deactivate()
	var eject_velocity := calc_velocity_limit(
		_WALL_JUMP_CONTROL_ACCELERATION / Engine.physics_ticks_per_second,
		calc_walljump_damping())
	
	_facing_direction = _wall_away_direction
	velocity.x = _wall_away_direction * eject_velocity
	_current_state = PlayerState.WALLJUMP
	return


## This method handles state transitions. It is only for checking things and changing states.[br]
## Everything in this must be related to changing player state. And nothing outside this method
## should be related to state transitions.
func _handle_state_transitions() -> void:
	# Handling Stun
	if _should_stun() and not _stunned:
		_stunned = true
		%ItemCrafter.enabled = false
		Global.play(Global.Sound.HURT)
		_stun_timer.activate()

	if _stunned and not _stun_timer.is_active:
		_stunned = false
		_iframe_timer.activate()
		_current_state = PlayerState.FREEMOVE
		%ItemCrafter.enabled = true
		return

	if _boost != Vector2.ZERO and _current_state != PlayerState.BOOST:
		_current_state = PlayerState.BOOST
		_jump_timer.deactivate()
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
			
			# if the player is on or have very recently exited a wall
			# (coyote time), then initiate the walljump. the initial x velocity
			# of the walljump will be the maximum x velocity of it.
			if Input.is_action_just_pressed("player_jump") and \
					_walljump_coyote_timer.is_active:
				transition_to_walljump()
		
		PlayerState.WALLSLIDE:
			var moving_toward_wall := _compute_move_dir() != -_wall_away_direction
			
			if _walljump_request:
				print("to walljump")
				transition_to_walljump()
			
			elif _stunned or not is_on_wall_only() or moving_toward_wall:
				_walljump_coyote_timer.activate()
				_current_state = PlayerState.FREEMOVE
		
		PlayerState.WALLJUMP:
			if is_on_wall_only() and _compute_move_dir() == -sign(get_wall_normal().x):
				print("walljump->wallslide")
				_jump_timer.deactivate()
				_wall_away_direction = sign(get_wall_normal().x)
				_facing_direction = _wall_away_direction
				_current_state = PlayerState.WALLSLIDE
			elif is_on_floor():
				print("walljump->onfloor")
				_jump_timer.deactivate()
				_current_state = PlayerState.FREEMOVE
		
		PlayerState.BOOST:
			if is_on_wall_only():
				_wall_away_direction = sign(get_wall_normal().x)
				_facing_direction = _wall_away_direction
				_current_state = PlayerState.WALLSLIDE
			elif is_on_floor():
				_current_state = PlayerState.FREEMOVE
	
	_walljump_request = false


func _update_player_velocities(move_dir: int, delta: float) -> void:
	var acceleration : float = player_state_to_acceleration[_current_state]
	var damping : float = player_state_to_damping[_current_state]
	
	match _current_state:
		PlayerState.FREEMOVE:
			var can_jump = is_on_floor()
			if can_jump:
				_coyote_timer.activate()
			
			if is_on_floor():
				_walljump_coyote_timer.deactivate()

			if not _stunned and (
					Input.is_action_just_pressed("player_jump")
					and _coyote_timer.is_active
			):
				var snd := Global.play(Global.Sound.JUMP)
				if snd:
					snd.pitch_scale = 1.0 + randf() * 0.1
				_coyote_timer.deactivate()
				_jump_timer.activate()
			
			_update_jump(delta)
			
			velocity += get_gravity() * delta
			
			velocity.x += acceleration * move_dir * delta
			velocity.x *= damping
			
			if %ItemCrafter.is_item_active_or_crafting() or _stunned:
				velocity.x = 0
		
		PlayerState.WALLSLIDE:
			_coyote_timer.activate()
			_update_jump(delta)

			#if move_dir != _wall_away_direction:
			velocity.x = -_wall_away_direction * 100.0

			var should_jump : bool = Input.is_action_just_pressed("player_jump")
			if should_jump:
				var dt := 1.0 / Engine.physics_ticks_per_second
				var eject_velocity := calc_velocity_limit(
						_WALL_JUMP_CONTROL_ACCELERATION * dt,
						calc_walljump_damping())
				
				_facing_direction = _wall_away_direction
				velocity.x = _wall_away_direction * eject_velocity
				
				_jump_timer.activate()
				_walljump_request = true

			velocity += get_gravity() * delta

			var max_y_vel = get_gravity().y * _WALL_SLIDE_SPEED_LIMIT * delta
			if velocity.y > max_y_vel:
				velocity.y = max_y_vel
		
		PlayerState.WALLJUMP:
			_update_jump(delta)

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


# for the entire duration of the jump, set y velocity to a factor of jump_power,
# tapering off the longer the jump button is held.
# once the jump button is released, stop the jump and dampen the y velocity. makes it
# easier to control the height of the jumps
func _update_jump(delta: float) -> void:
	if _jump_timer.is_active and not _stunned:
		if Input.is_action_pressed("player_jump") and not is_on_ceiling():
			# continue jumping
			velocity.y = -_JUMP_POWER * _jump_timer.get_progress_ratio()
		else:
			# stop jump
			velocity.y *= _EARLY_JUMP_DAMP
			_jump_timer.deactivate()


## Returns if you should stun the player
func _should_stun() -> bool:
	var stunned = _stun_timer.is_active
	var invincible = _iframe_timer.is_active
	return _deadly_area_count > 0 and not stunned and not invincible


func _compute_move_dir() -> int:
	if %ItemCrafter.is_item_active_or_crafting():
		return 0
	return int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))


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
	if _iframe_timer.is_active:
		var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
		visible = t < 0.5

	# crafting animation will stretch out the player a little bit
	# stretching increases as it gets closer to being finishedD
	if Global.is_timer_active(Global.TimerType.CRAFTING):
		var t := (Global.get_time_of(Global.TimerType.CRAFTING) /
				Global.get_activation_time_of(Global.TimerType.CRAFTING))
		t = 1.0 - t
		
		sprite.scale = Vector2(
			pow(2, t * 0.4),
			pow(2, -t * 0.4)
		)
	else:
		sprite.scale = Vector2.ONE
