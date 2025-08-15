extends CharacterBody2D
class_name Player

const FREEMOVE_ACCEL: float = 3800
const FREEMOVE_DAMPING: float = 0.8
const WALLJUMP_ACCEL: float = 450
const WALLJUMP_DAMPING: float = 0.98
const BOOST_ACCEL: float = 450
const BOOST_DAMPING: float = 0.98

## The velocity of the jump at the moment it was pressed. The velocity
## decreases over time, according to the progress of the jump timer.
const JUMP_POWER : float = 300.0

## The damping applied to the jumping velocity when it stops. Makes it easier
## to control the variable jump height.
const JUMP_STOP_DAMP : float = 0.5

## The multiplier limit that forces wall slide speed not to increase indefinitely.
const WALL_SLIDE_SPEED_LIMIT : float = 4.0

## The velocity boost in the x axis, while wall jumping.
const WALL_JUMP_INITIAL_XBOOST : float = 230.0

## The current state of the player.
var _current_state: MovementStateBase = FreeMove.new(self)

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

## The direction the player is currently moving based on their inputs.[br]
## 1 is right, -1 is left, and 0 is neutral.
var move_direction: int = 0

## The number of hazards the character is currently overlapping with.
var _deadly_area_count: int = 0

## True if the player was on floor on the previous frame. Used for playing the
## landing sound.
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
@onready var _start_pos : Vector2 = position

func _ready() -> void:
	Global.get_game().round_started.connect(game_reset)
	game_reset(true)


func _physics_process(delta: float) -> void:
	_handle_player_controls(delta)
	_handle_player_visuals()
	_update_timers(delta)
	_handle_state_transitions()


func game_reset(_new_round : bool) -> void:
	position = _start_pos
	velocity = Vector2.ZERO

	%ItemCrafter.reset()

	# Reseting all player variables
	_current_state = FreeMove.new(self)
	_deadly_area_count = 0
	facing_direction = 1
	_was_on_floor = true
	jumped_from_floor = false
	
	boost = Vector2.ZERO

	# Deactivating all timers!
	for timer in timers:
		timer.deactivate()


func _update_timers(delta: float) -> void:
	for timer in timers:
		timer.update(delta)


## This method handles state transitions. It is only for checking things and
## changing states.[br]
## Everything in this must be related to changing player state. Nothing outside
## this method should be related to state transitions.
func _handle_state_transitions() -> void:
	# TODO: Move this shit out from here. So much mental load!!
	# Handling Stun
	if _should_stun() and not stunned:
		stunned = true
		%ItemCrafter.enabled = false
		Global.play(Global.Sound.HURT)
		_stun_timer.activate()

	if stunned and not _stun_timer.is_active:
		stunned = false
		_invincibility_timer.activate()
		_current_state = FreeMove.new(self)
		%ItemCrafter.enabled = true
		return

	if boost != Vector2.ZERO:
		_current_state = Boost.new(self)
		jump_progress_timer.deactivate()
		return
	
	var new_state := _current_state.update_transition()
	if new_state != null:
		_current_state = new_state


## Moves player based on inputs and states.
func _handle_player_controls(delta: float) -> void:
	var do_fly := OS.is_debug_build() && Input.is_key_pressed(KEY_SHIFT)
	if _handle_flight(do_fly, delta):
		return
	
	move_direction = (
		int(Input.is_action_pressed("player_right")) -
		int(Input.is_action_pressed("player_left"))
	)

	var is_control_revoked : bool = %ItemCrafter.is_crafting()
	if is_control_revoked:
		move_direction = 0
		return

	if %ItemCrafter.is_item_active_or_crafting():
		move_direction = 0
	
	_current_state.update_physics(delta)
	
	# If you landed, then play the land sound.
	var just_landed = not _was_on_floor and is_on_floor()
	if just_landed:
		Global.play(Global.Sound.LAND)

	_was_on_floor = is_on_floor()
	move_and_slide()


func _handle_flight(flight: bool, delta: float) -> bool:
	if !flight: return false
	
	const fly_speed := 1200.0
	var speed = fly_speed * delta
	
	var x_dir := int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"))
	position.x += x_dir * speed
	
	var y_dir := int(Input.is_action_pressed("player_down")) - int(Input.is_action_pressed("player_up"))
	position.y += y_dir * speed

	return true


## Returns if you should jump without coyote stuff
func should_jump():
	return Input.is_action_just_pressed("player_jump") and not stunned


func update_jump_if_needed() -> void:
	if jump_progress_timer.is_active and not stunned:
		var continue_jumping : bool = \
				Input.is_action_pressed("player_jump") \
				and not is_on_ceiling()
		
		if continue_jumping:
			velocity.y = -JUMP_POWER * jump_progress_timer.get_progress_ratio()
		else:
			velocity.y *= JUMP_STOP_DAMP
			jump_progress_timer.deactivate()


## Returns if you should stun the player
func _should_stun() -> bool:
	var stunned = _stun_timer.is_active
	var invincible = _invincibility_timer.is_active
	return _deadly_area_count > 0 and not stunned and not invincible


## Handles how player looks
func _handle_player_visuals() -> void:
	visible = true
	var sprite = $AnimatedSprite2D
	var item_crafter = $ItemCrafter
	
	var animation = "idle" if move_direction == 0 else "run"
	
	if velocity.y > 0:
		animation = "jump"
	elif velocity.y < 0:
		animation = "fall"
	
	# ew, is
	if _current_state is WallSlide:
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
	if item_crafter._crafting_timer.is_active:
		var t: float = 1.0 - item_crafter._crafting_timer.get_progress_ratio()
		sprite.scale = Vector2(
			pow(2, t * 0.4),
			pow(2, -t * 0.4)
		)
	else:
		sprite.scale = Vector2.ONE


func kill() -> void:
	Global.get_game().player_lives -= 1
	
	#if Global.get_game().player_lives == 0:
		#print("Game over")
		##Global.get_game().game_state = Global.GameState.GAME_OVER
		#
	#else:
		#print("Normal death")
		##Global.game_state = Global.GameState.DEATH


func on_entered_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count + 1


func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1


func _on_spring_bounce(bounce_power: float) -> void:
	boost = Vector2(0, -bounce_power)
	jump_progress_timer.deactivate()


func _onbooster_bounce(side_power: float, bounce_power: float) -> void:
	boost = Vector2(side_power * facing_direction, -bounce_power)


func _on_item_crafter_bridge_used() -> void:
	velocity.y = 0 # IMO, a valid exception to not be in the update velocites.


class MovementStateBase:
	var player: Player
	
	func _init(p_player: Player):
		player = p_player
	
	
	func enter() -> void:
		pass
	
	
	func exit() -> void:
		pass
	
	
	func update_physics(dt: float) -> void:
		pass
	
	
	func update_transition() -> MovementStateBase:
		return null


## normal grounded/mid-air movement mode
class FreeMove extends MovementStateBase:
	func update_physics(dt: float):
		var can_jump_from_floor = player.is_on_floor()
		if can_jump_from_floor:
			player.walljump_coyote_timer.deactivate()
			player.freemove_coyote_timer.activate()

		if player.should_jump():
			if player.freemove_coyote_timer.is_active:
				Global.play(Global.Sound.JUMP)
				player.jump_progress_timer.activate()
				player.jumped_from_floor = true

			if player.walljump_coyote_timer.is_active:
				player.velocity.x = player.wall_away_direction * \
						player.WALL_JUMP_INITIAL_XBOOST
				Global.play(Global.Sound.JUMP)
				player.jump_progress_timer.activate()
				player.jumped_from_floor = false

		player.update_jump_if_needed()

		player.velocity += player.get_gravity() * dt
		
		const acc := FREEMOVE_ACCEL
		const damp := FREEMOVE_DAMPING
		player.velocity.x += acc * player.move_direction * dt
		player.velocity.x *= damp
		
		if player.item_crafter.is_item_active_or_crafting() or player.stunned:
			player.velocity.x = 0
	
	
	func update_transition():
		if player.is_on_floor():
			player.wall_away_direction = 0

		if player.should_jump():
			if player.walljump_coyote_timer.is_active:
				player.walljump_coyote_timer.deactivate()
				return WallJump.new(player)

		if player.move_direction != 0:
			player.facing_direction = player.move_direction
			
			if player.is_on_wall_only():
				player.wall_away_direction = sign(player.get_wall_normal().x)
				player.facing_direction = player.wall_away_direction 
				return WallSlide.new(player)


## currently wallsliding
class WallSlide extends MovementStateBase:
	func update_physics(dt: float):
		if player.move_direction != player.wall_away_direction:
			player.velocity.x = -player.wall_away_direction
			player.walljump_coyote_timer.activate()

		if player.should_jump():
			player.facing_direction = player.wall_away_direction
			player.velocity.x = player.wall_away_direction * \
					player.WALL_JUMP_INITIAL_XBOOST
			player.jump_progress_timer.activate() # Activate the timer.
			Global.play(Global.Sound.JUMP) # Play the jump sound.
			player.jumped_from_floor = false
		elif player.jump_progress_timer.is_active:
			player.update_jump_if_needed()

		player.velocity += player.get_gravity() * dt

		var max_y_vel = player.get_gravity().y * player.WALL_SLIDE_SPEED_LIMIT * dt
		if player.velocity.y > max_y_vel:
			player.velocity.y = max_y_vel
	
	
	func update_transition():
		if player.stunned or not player.is_on_wall_only():
			return FreeMove.new(player)
		if player.jump_progress_timer.is_active and not player.jumped_from_floor:
			return WallJump.new(player)


## jump from a wallslide. diminished mid-air control
class WallJump extends MovementStateBase:
	func update_physics(dt: float):
		player.update_jump_if_needed()

		player.velocity += player.get_gravity() * dt

		const acc := WALLJUMP_ACCEL
		const damp := WALLJUMP_DAMPING
		player.velocity.x += acc * player.move_direction * dt
		player.velocity.x *= damp

		if player.item_crafter.is_item_active_or_crafting() or player.stunned:
			player.velocity.x = 0
	
	
	func update_transition():
		if player.is_on_wall_only():
				player.jump_progress_timer.deactivate()
				player.wall_away_direction = sign(player.get_wall_normal().x)
				player.facing_direction = player.wall_away_direction
				return WallSlide.new(player)
		elif player.is_on_floor():
			player.jump_progress_timer.deactivate()
			return FreeMove.new(player)


## in mid-air from a booster. reduced air control to allow velocity to
## dampen at a slower rate.
class Boost extends MovementStateBase:
	func update_physics(dt: float):
		if player.boost != Vector2.ZERO:
			player.velocity = player.boost
			player.boost = Vector2.ZERO

		player.velocity += player.get_gravity() * dt
		
		const acc := BOOST_ACCEL
		const damp := BOOST_DAMPING
		player.velocity.x += acc * player.move_direction * dt
		player.velocity.x *= damp
	
	
	func update_transition():
		if player.is_on_wall_only():
			player.wall_away_direction = sign(player.get_wall_normal().x)
			player.facing_direction = player.wall_away_direction 
			return WallSlide.new(player)
		elif player.is_on_floor():
			return FreeMove.new(player)
