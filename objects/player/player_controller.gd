extends CharacterBody2D
class_name Player

## A enum stating the possible boosts, the player can have.
enum BoostFrom {
	SPRING,
	BOOSTER
}

const FREEMOVE_ACCEL: float = 3800
const FREEMOVE_DAMPING: float = 0.8
const WALLJUMP_ACCEL: float = 700.0
const BOOST_ACCEL: float = 450
const BOOST_DAMPING: float = 0.98
const EATEN_KNOCKBACK_POWER: float = 200.0

var WALLJUMP_DAMPING: float = calc_damping_from_limit(calc_velocity_limit(FREEMOVE_ACCEL, FREEMOVE_DAMPING), WALLJUMP_ACCEL)

## The velocity of the jump at the moment it was pressed. The velocity
## decreases over time, according to the progress of the jump timer.
const JUMP_POWER : float = 300.0

## The damping applied to the jumping velocity when it stops. Makes it easier
## to control the variable jump height.
const JUMP_STOP_DAMP : float = 0.5

## The multiplier limit that forces wall slide speed not to increase
## indefinitely.
const WALL_SLIDE_SPEED_LIMIT : float = 4.0

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

## When this variable is not-null, the player's velocity will be set to it's said velocity
## and this variable will be reset afterwards. Intended to be used by code that
## handles boost/spring.
var boost : Variant = null

## A temporary value intended for one and only use of only resetting
## the velocity of the player on the use of bridge once.
var just_checked_item_is_active = false

@onready var item_crafter := %ItemCrafter
@onready var _start_pos : Vector2 = position

func _ready() -> void:
	Global.get_game().round_started.connect(game_reset)
	game_reset(true)


func take_damage(kb_vel: Vector2):
	stunned = true
	item_crafter.enabled = false
	Global.play(Global.Sound.HURT)
	_stun_timer.activate()
	
	velocity = kb_vel


## Every tick, player and the associated timers are updated here.
func _physics_process(delta: float) -> void:
	# Begin stun
	var should_stun = _deadly_area_count > 0 and not _invincibility_timer.is_active
	if should_stun and not stunned:
		take_damage(Vector2(0, -200))
	
	# Exit stun
	if stunned and not _stun_timer.is_active:
		stunned = false
		_invincibility_timer.activate()
		_current_state = FreeMove.new(self)
		item_crafter.enabled = true
	
	var do_fly : bool = Input.is_key_pressed(KEY_SHIFT) and Global.get_game_process().has_debug_freedom()
	if _handle_flight(do_fly, delta):
		return

	# Freeze the player while they are crafting
	if item_crafter.is_crafting():
		velocity = Vector2.ZERO
		jump_progress_timer.deactivate()
		move_direction = 0
		return

	# Apply any requested boosts
	if boost != null:
		velocity = boost.vel
		if boost.from == BoostFrom.BOOSTER:
			_current_state = Boost.new(self)
		boost = null

	move_direction = (
		int(Input.is_action_pressed("player_right")) -
		int(Input.is_action_pressed("player_left"))
	)

	if item_crafter.is_item_active() and item_crafter.item_id == "bridge":
		velocity.x = 0
		move_direction = 0
		if not just_checked_item_is_active:
			velocity.y = 0
			just_checked_item_is_active = true
	else:
		just_checked_item_is_active = false
	
	if stunned:
		move_direction = 0
	
	_current_state.update_physics(delta)
	
	# If you landed, then play the land sound.
	var just_landed = not _was_on_floor and is_on_floor()
	if just_landed:
		Global.play(Global.Sound.LAND)

	# Compute the next frame
	_was_on_floor = is_on_floor()
	move_and_slide()
	
	# Update transition
	var new_state := _current_state.update_transition()
	if new_state != null:
		_current_state = new_state
	
	# Update timers
	for timer in timers:
		timer.update(delta)


## Every tick the visuals of the players are updated here.
func _process(_dt: float) -> void:
	visible = true
	var sprite = $AnimatedSprite2D
	
	var animation := "idle"
	if is_on_floor():
		animation = "idle" if move_direction == 0 else "run"
	else:
		if velocity.y > 0:
			animation = "jump"
		else:
			animation = "fall"
	
	# ew, is
	if _current_state is WallSlide:
		animation = "wallslide"
	
	if stunned:
		animation = "hurt"
	
	if item_crafter.is_crafting():
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


## The player is reset here.
## [param _new_round] should be true if new round is starting!
func game_reset(_new_round : bool) -> void:
	position = _start_pos
	velocity = Vector2.ZERO

	item_crafter.reset()

	# Reseting all player variables
	_current_state = FreeMove.new(self)
	_deadly_area_count = 0
	facing_direction = 1
	_was_on_floor = true
	
	boost = null

	# Deactivating all timers!
	for timer in timers:
		timer.deactivate()


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


func kill(knockback_dir: Vector2) -> void:
	Global.get_game().player_lives -= 1
	take_damage(knockback_dir * EATEN_KNOCKBACK_POWER)
	
	# switch to boost state to diminish damping
	_current_state = Boost.new(self)


# formula to obtain the maximum velocity given an acceleration (a) and a
# damping factor (k):
#	(this is the velocity function. v0 is the initial velocity)
#	(x is the integer number of frames that have elapsed since initial velocity)
#	v(x) = v0*k^x + sum(n=1, x, a*k^n)
#	
#	lim v(x) as x -> inf = a / (1 - k) - a, as:
#		- sum(n=0, x, a*k^n) is a geometric series.
#		  the limit of this series is a / (1 - k). subtract a to remove the n=0
#		  term.
#		- v0*k^x approaches 0 if 0 <= k < 1. if k < 0, limit does not exist. if
#		  k >= 1, limit approaches infinity.
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


func on_entered_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count + 1


func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1


func _on_spring_bounce(bounce_power: float) -> void:
	boost = {}
	boost.vel = Vector2(velocity.x, -bounce_power)
	boost.from = BoostFrom.SPRING
	jump_progress_timer.deactivate()


func _on_booster_bounce(side_power: float, bounce_power: float) -> void:
	boost = {}
	boost.vel = Vector2(side_power * facing_direction, -bounce_power)
	boost.from = BoostFrom.BOOSTER


class MovementStateBase:
	var player: Player
	
	func _init(p_player: Player):
		player = p_player
	
	
	func enter() -> void:
		pass
	
	
	func exit() -> void:
		pass
	
	
	func update_physics(_dt: float) -> void:
		pass
	
	
	func update_transition() -> MovementStateBase:
		return null


## normal grounded/mid-air movement mode
class FreeMove extends MovementStateBase:
	func should_jump() -> bool:
		return not player.item_crafter.is_item_active_or_crafting()\
				and Input.is_action_just_pressed("player_jump")\
				and not player.stunned
	
	
	func update_physics(dt: float):
		if player.is_on_floor():
			# activate coyote timer if player is able to jump
			player.walljump_coyote_timer.deactivate()
			player.freemove_coyote_timer.activate()
			
			player.wall_away_direction = 0

		if should_jump():
			# handle normal jump
			if player.freemove_coyote_timer.is_active:
				Global.play(Global.Sound.JUMP)
				player.jump_progress_timer.activate()
			
			# handle coyote-time walljump
			if player.walljump_coyote_timer.is_active:
				var eject_velocity := player.calc_velocity_limit(
						player.WALLJUMP_ACCEL / Engine.physics_ticks_per_second,
						player.WALLJUMP_DAMPING
				)
				
				player.velocity.x = player.wall_away_direction * eject_velocity
				Global.play(Global.Sound.JUMP)
				player.jump_progress_timer.activate()

		player.velocity += player.get_gravity() * dt
		player.update_jump_if_needed()
		
		const acc := FREEMOVE_ACCEL
		const damp := FREEMOVE_DAMPING
		player.velocity.x += acc * player.move_direction * dt
		player.velocity.x *= damp
		
		if player.move_direction != 0:
			player.facing_direction = player.move_direction
	
	
	func update_transition():
		# handle coyote-time walljump
		if should_jump():
			if player.walljump_coyote_timer.is_active:
				player.walljump_coyote_timer.deactivate()
				return WallJump.new(player)
		
		# transition to walljump
		var wall_dir := signi(int(player.get_wall_normal().x))
		if player.is_on_wall_only() and player.move_direction == -wall_dir:
			player.wall_away_direction = wall_dir
			player.facing_direction = player.wall_away_direction 
			return WallSlide.new(player)


## currently wallsliding
class WallSlide extends MovementStateBase:
	var transition_to_walljump := false
	var transition_to_wallslide := false
	
	func update_physics(dt: float):
		# some walls act inconsistently/broken. i assume this is due to floating
		# point error. I push the player towards the wall while they are
		# wallsliding to fix this issue.
		player.velocity.x = -player.wall_away_direction * 100
		player.walljump_coyote_timer.activate()
		
		if player.move_direction != player.wall_away_direction:
			transition_to_wallslide = true
		
		# begin wall jump
		var should_jump : bool = not player.item_crafter.is_item_active_or_crafting()\
						and Input.is_action_just_pressed("player_jump")\
						and not player.stunned
		if should_jump:
			# NOTE: Maybe don't compute it often if you are pretty darn sure that
			# Engine.physics_ticks_per_second is not going to change.
			var eject_velocity := player.calc_velocity_limit(
					player.WALLJUMP_ACCEL / Engine.physics_ticks_per_second,
					player.WALLJUMP_DAMPING
			)
			
			player.facing_direction = player.wall_away_direction
			player.velocity.x = player.wall_away_direction * eject_velocity
			player.jump_progress_timer.activate()
			Global.play(Global.Sound.JUMP)
			transition_to_walljump = true
		
		else:
			player.update_jump_if_needed()
		
		player.velocity += player.get_gravity() * dt
		
		var max_y_vel = player.get_gravity().y * player.WALL_SLIDE_SPEED_LIMIT * dt
		if player.velocity.y > max_y_vel:
			player.velocity.y = max_y_vel
	
	
	func update_transition():
		if transition_to_walljump:
			return WallJump.new(player)
		
		var move_away := player.move_direction == player.wall_away_direction
		if player.stunned or not player.is_on_wall_only() or move_away:
			return FreeMove.new(player)


## jump from a wallslide. diminished mid-air control
class WallJump extends MovementStateBase:
	func update_physics(dt: float):
		player.update_jump_if_needed()

		player.velocity += player.get_gravity() * dt

		const acc := WALLJUMP_ACCEL
		var damp := player.WALLJUMP_DAMPING
		player.velocity.x += acc * player.move_direction * dt
		player.velocity.x *= damp
	
	
	func update_transition():
		var wall_dir := signi(int(player.get_wall_normal().x))
		if player.is_on_wall_only() and player.move_direction == -wall_dir:
			player.jump_progress_timer.deactivate()
			player.wall_away_direction = wall_dir
			player.facing_direction = player.wall_away_direction
			return WallSlide.new(player)
		elif player.is_on_floor():
			player.jump_progress_timer.deactivate()
			return FreeMove.new(player)


## in mid-air from a booster. reduced air control to allow velocity to
## dampen at a slower rate.
class Boost extends MovementStateBase:
	func update_physics(dt: float):
		player.velocity += player.get_gravity() * dt
		player.update_jump_if_needed() # i like this trick
		
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
