extends CharacterBody2D

const WALL_JUMP_FREEZE_LENGTH := 0.1
const DAMAGE_STUN_LENGTH := 2.0
const IFRAME_LENGTH := 2.75 # must be longer than stun length

enum PlayerState {
	FREEMOVE, # normal grounded/mid-air movement mode
	WALLSLIDE, # currently wallsliding
	WALLJUMP, # jump from a wallslide. diminished mid-air control
	STUNNED, # control is revoked for a short time when player takes damage
}

@export_group("Normal Movement")
@export_range(0, 10000) var jump_power := 300.0
@export_range(0.1, 10)  var jump_length := 0.5
@export_range(0, 10000) var walk_acceleration := 1400.0
@export_range(0, 1)     var speed_damping := 0.92
@export_range(0.0, 1.0) var jump_stop_power := 0.5

@export_group("Wall Slide, Jump")
@export_range(0, 10000) var wall_slide_speed = 4.0
@export_range(0, 10000) var wall_jump_velocity = 230.0
@export_range(0, 10000) var wall_jump_damping = 0.98
@export_range(0, 10000) var wall_jump_control_acceleration = 450.0

var move_direction: int = 1 # 1: right, -1: left
var stamina_points: int = 0

# TODO: don't store time remaining in player
var round_time: int = 40
var time_remaining: float
var is_taking_damage: bool = false

# progress of the jump, from 0.0 to 1.0.
# 1.0 means the player just started jumping; 0.0 means the player is not jumping
var _jump_remaining = 0.0
var _wall_jump_freeze = 0.0
var _cur_state := PlayerState.FREEMOVE
var _temp_construction_area: Area2D
var _last_move_dir: int = 0
var _deadly_area_count: int = 0
var _stun_timer: float = 0.0
var _iframe_timer: float = 0.0
@onready var _start_pos := position
@onready var _tilemap: TileMapLayer = get_node("../TileMap")

const _prefab_bomb = preload("res://Objects/realized-items/bomb/bomb.tscn")
const _prefab_inverse_bomb = preload("res://Objects/realized-items/inverse_bomb/inverse_bomb.tscn")
const _prefab_bridge_maker = preload("res://Objects/realized-items/bridge/bridge.tscn")

var _active_bridge_maker: Node2D = null
var _active_item_key := KEY_NONE

func _ready() -> void:
	time_remaining = round_time

func game_reset():
	position = _start_pos
	round_time -= 2
	time_remaining = round_time
	
func on_entered_deadly_area(_area: Area2D) -> void:
	if _deadly_area_count == 0:
		print("OUCH!")
		is_taking_damage = true
		
	_deadly_area_count = _deadly_area_count + 1

func on_exited_deadly_area(_area: Area2D) -> void:
	_deadly_area_count = _deadly_area_count - 1
	
	if _deadly_area_count == 0:
		print("no more ouchies")
		is_taking_damage = false

func deactivate_active_item():
	if _active_bridge_maker != null:
		print("release bridge maker")
		_active_bridge_maker.deactivate()
		_active_bridge_maker = null

func meets_stamina_requirement(c: int) -> bool:
	return OS.is_debug_build() or stamina_points >= c

func _input(event: InputEvent) -> void:
	if _cur_state != PlayerState.STUNNED:
		if event is InputEventKey and not event.is_echo():
			if _active_bridge_maker == null:
				# 1 key: craft bomb
				if event.pressed and event.keycode == KEY_1 and meets_stamina_requirement(3):
					var inst: Node2D = _prefab_bomb.instantiate()
					inst.global_position = global_position
					add_sibling(inst)
					inst.activate()
					stamina_points -= 3
					
				# 2 key: slime bomb
				if event.pressed and event.keycode == KEY_2 and meets_stamina_requirement(3):
					var inst: Node2D = _prefab_inverse_bomb.instantiate()
							
					inst.global_position = global_position
					add_sibling(inst)
					inst.activate()
					stamina_points -= 3
					
				# 3 key: bridge marker (if airborne)
				elif event.pressed and event.keycode == KEY_3 and not is_on_floor() and meets_stamina_requirement(3):
					# place bridge maker if not on floor
					velocity.x = 0.0
					var inst: Node2D = _prefab_bridge_maker.instantiate()
					
					# place bridge maker on the center of the cell below the player
					var player_bottom: Vector2i = global_position + Vector2.DOWN * $CollisionShape2D.shape.size.y / 2.0
					inst.global_position = _tilemap.to_global(_tilemap.map_to_local(_tilemap.local_to_map(_tilemap.to_local(player_bottom)) + Vector2i(0, 1)))
					add_sibling(inst)
					inst.activate()
					stamina_points -= 3
					
					_active_bridge_maker = inst
					_active_item_key = event.keycode
			
			elif _active_bridge_maker != null and event.is_released() and event.keycode == _active_item_key:
				deactivate_active_item()

func _process(_delta: float) -> void:
	var status_text: Label = get_node("Camera2D/Status")
	status_text.text = "Stamina: %s\nTime remaining: %10.2f" % [stamina_points, time_remaining]

func _physics_process(delta: float) -> void:
	# lose state when player runs out of time
	if not OS.is_debug_build():
		if time_remaining <= 0.0: return
	
	time_remaining -= delta
	
	if _active_bridge_maker != null and not _active_bridge_maker.active:
		_active_bridge_maker = null
	
	if is_taking_damage and _iframe_timer <= 0.0:
		_stun_timer = DAMAGE_STUN_LENGTH
		_iframe_timer = IFRAME_LENGTH
		_cur_state = PlayerState.STUNNED
		velocity = Vector2(0, -200)
		deactivate_active_item()
	
	_iframe_timer = move_toward(_iframe_timer, 0, delta)

	var can_jump := (_cur_state == PlayerState.FREEMOVE and is_on_floor()) or (_cur_state == PlayerState.WALLSLIDE and is_on_wall_only())
	if _active_bridge_maker != null:
		can_jump = false

	if Input.is_action_just_pressed("player_jump") and can_jump:
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
	
	if _active_bridge_maker == null:
		if Input.is_action_pressed("player_right"):
			move_dir += 1
		if Input.is_action_pressed("player_left"):
			move_dir -= 1
	
	match _cur_state:
		PlayerState.FREEMOVE:
			# apply gravity normally
			velocity += get_gravity() * delta

			# apply movement direction
			# velocity.x = move_toward(velocity.x, walk_speed * move_dir, walk_acceleration * delta);
			velocity.x += walk_acceleration * move_dir * delta
			velocity.x *= speed_damping

			if is_on_wall_only() and move_dir != 0:
				_jump_remaining = 0.0
				_cur_state = PlayerState.WALLSLIDE
		
		PlayerState.STUNNED:
			# apply gravity normally
			velocity += get_gravity() * delta
			
			# damping
			velocity.x *= speed_damping
			
			_stun_timer = move_toward(_stun_timer, 0, delta)
			if _stun_timer <= 0.0:
				_cur_state = PlayerState.FREEMOVE
		
		PlayerState.WALLSLIDE:
			move_direction = 1 if get_wall_normal().x > 0.0 else -1

			if _jump_remaining > 0.0:
				_cur_state = PlayerState.WALLJUMP
				_wall_jump_freeze = WALL_JUMP_FREEZE_LENGTH
				
				velocity.x = move_direction * wall_jump_velocity
			
			elif not is_on_wall_only():
				_cur_state = PlayerState.FREEMOVE
			
			else:
				var max_y_vel: float = get_gravity().y * delta * wall_slide_speed
				velocity += get_gravity() * delta
				
				if velocity.y > max_y_vel:
					velocity.y = max_y_vel
				
				if move_dir != _last_move_dir and move_dir != 0:
					velocity.x += walk_acceleration * move_dir * delta
					velocity.x *= speed_damping
				else:
					velocity.x = -move_direction * 100.0 # please stay on the wall

		PlayerState.WALLJUMP:
			# apply gravity normally
			velocity += get_gravity() * delta
			
			# apply movement direction
			# velocity.x = move_dir * walk_speed
			
			if is_on_wall_only():
				_jump_remaining = 0.0
				_cur_state = PlayerState.WALLSLIDE
				velocity.x = -get_wall_normal().x * 100.0 # please stay on the wall
				
			elif is_on_floor() or _wall_jump_freeze < 0.0:
				_jump_remaining = 0.0
				_cur_state = PlayerState.FREEMOVE
				
			else:
				velocity.x += move_dir * wall_jump_control_acceleration * delta
				velocity.x *= wall_jump_damping
	
	_last_move_dir = move_dir
	move_and_slide()
