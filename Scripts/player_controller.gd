extends CharacterBody2D

enum PlayerState {
	# normal grounded/mid-air movement mode
	FREEMOVE,
	
	# currently wallsliding
	WALLSLIDE,

	# jump from a wallslide. diminished mid-air control
	WALLJUMP
}

@export_range(0, 10000)
var jump_power = 300
@export_range(0.1, 10)
var jump_length = 0.5
@export_range(0, 10000)
var walk_speed = 200.0
@export_range(0.0, 1.0)
var jump_stop_power = 0.5

const WALL_JUMP_FREEZE_LENGTH := 0.1

# progress of the jump, from 0.0 to 1.0.
# 1.0 means the player just started jumping; 0.0 means the player is not jumping
var _jump_remaining = 0.0
var _wall_jump_freeze = 0.0

var _cur_state := PlayerState.FREEMOVE

func _physics_process(delta: float) -> void:
	var can_jump := (_cur_state == PlayerState.FREEMOVE and is_on_floor()) or (_cur_state == PlayerState.WALLSLIDE and is_on_wall_only())

	if Input.is_action_just_pressed("player_jump") and can_jump:
		print("JUMP!")
		_jump_remaining = 1.0

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
	if Input.is_action_pressed("player_right"):
		move_dir += 1
	if Input.is_action_pressed("player_left"):
		move_dir -= 1
	
	match _cur_state:
		PlayerState.FREEMOVE:
			# apply gravity normal
			velocity += get_gravity() * delta

			# apply movement direction
			velocity.x = move_dir * walk_speed

			if is_on_wall_only() and velocity.y > 0.0:
				_cur_state = PlayerState.WALLSLIDE

		PlayerState.WALLSLIDE:
			if _jump_remaining > 0.0:
				_cur_state = PlayerState.WALLJUMP
				_wall_jump_freeze = WALL_JUMP_FREEZE_LENGTH
				velocity.x = get_wall_normal().x * walk_speed

			elif not is_on_wall_only():
				_cur_state = PlayerState.FREEMOVE
			
			else:
				velocity.y = get_gravity().y * delta * 4.0
				velocity.x = move_dir * walk_speed

		PlayerState.WALLJUMP:
			# apply gravity normal
			velocity += get_gravity() * delta

			# apply movement direction
			# velocity.x = move_dir * walk_speed

			if is_on_wall():
				_jump_remaining = 0.0
				_cur_state = PlayerState.WALLSLIDE

			elif is_on_floor() or _wall_jump_freeze < 0.0:
				_jump_remaining = 0.0
				_cur_state = PlayerState.FREEMOVE
	
	move_and_slide()
