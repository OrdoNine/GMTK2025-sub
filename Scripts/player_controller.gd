extends CharacterBody2D
class_name Player

const WALL_JUMP_FREEZE_LENGTH := 0.1
const DAMAGE_STUN_LENGTH := 2.0
const IFRAME_LENGTH := 2.75 # must be longer than stun length

enum PlayerState {
	FREEMOVE, # normal grounded/mid-air movement mode
	WALLSLIDE, # currently wallsliding
	WALLJUMP, # jump from a wallslide. diminished mid-air control
	CRAFTING,
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

var is_taking_damage: bool = false

# progress of the jump, from 0.0 to 1.0.
# 1.0 means the player just started jumping; 0.0 means the player is not jumping
var _jump_remaining = 0.0
var _wall_jump_freeze = 0.0
var current_state := PlayerState.FREEMOVE
var construction_area: Area2D
var _last_move_dir: int = 0
var _deadly_area_count: int = 0
var _stun_timer: float = 0.0
var _iframe_timer: float = 0.0
@onready var _start_pos := position
@onready var tilemap: TileMapLayer = get_node("../TileMap")

const _prefab_bomb = preload("res://Objects/realized-items/bomb/bomb.tscn")
const _prefab_inverse_bomb = preload("res://Objects/realized-items/inverse_bomb/inverse_bomb.tscn")
const _prefab_bridge_maker = preload("res://Objects/realized-items/bridge/bridge.tscn")
const _prefab_spring = preload("res://Objects/realized-items/spring/spring.tscn")

var _item_craft_progress = null
var _active_bridge_maker: Node2D = null
var _active_item_key := KEY_NONE

func begin_item_craft(time: float, points: int, prefab: PackedScene):
	_item_craft_progress = {
		time_remaining = time,
		points = points,
		prefab = prefab
	}

func finish_item_craft():
	print("finish item craft")
	
	var inst: Node2D = _item_craft_progress.prefab.instantiate()
	inst.global_position = global_position
	add_sibling(inst)
	inst.activate()
	stamina_points -= _item_craft_progress.points
	
	_item_craft_progress = null
	_active_item_key = KEY_NONE

func _on_game_gamemode_changed(_from_state: Global.GameState, state: Global.GameState) -> void:
	get_tree().paused = (state == Global.GameState.PAUSE) or (state == Global.GameState.DEATH);

func _ready() -> void:
	Global.gamemode_changed.connect(_on_game_gamemode_changed)
	game_reset();

func game_reset():
	position = _start_pos

func _process(_delta: float) -> void:
	if Global.time_remaining <= 0:
		kill();
	
	if Input.is_action_just_pressed("escape"):
		if Global.ignore_escape:
			Global.ignore_escape = false
		else:
			Global.game_state = Global.GameState.PAUSE
	
	%GamePlayUI.stamina_points = stamina_points
	
	match current_state:
		# flash red when player is stunned
		
		PlayerState.STUNNED:
			var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
			modulate = Color(1.0, 0.0, 0.0) if t < 0.5 else Color(1.0, 1.0, 1.0)
			
		_:
			modulate = Color(1.0, 1.0, 1.0)
			
			# flash visible/invisible while iframes are active
			if _iframe_timer > 0.0:
				var t = fmod(Time.get_ticks_msec() / 128.0, 1.0)
				visible = t < 0.5
			else:
				visible = true
			
			var sprite := $Sprite2D
			if _item_craft_progress != null:
				sprite.scale = Vector2(1.3, 0.7)
			else:
				sprite.scale = Vector2.ONE

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
	return stamina_points >= c

func _input(event: InputEvent) -> void:
	if current_state != PlayerState.STUNNED:
		if event is InputEventKey and not event.is_echo():
			if _active_bridge_maker == null and _item_craft_progress == null:
				# 1 key: craft bomb
				if event.pressed and event.keycode == KEY_1 and meets_stamina_requirement(5):
					_active_item_key = event.keycode
					begin_item_craft(0.5, 5, _prefab_bomb)
					
				# 2 key: slime bomb
				if event.pressed and event.keycode == KEY_2 and meets_stamina_requirement(3):
					_active_item_key = event.keycode
					begin_item_craft(0.5, 3, _prefab_inverse_bomb)
					
				# 3 key: bridge marker (if airborne)
				elif event.pressed and event.keycode == KEY_3 and not is_on_floor() and meets_stamina_requirement(8):
					# place bridge maker if not on floor
					velocity.x = 0.0
					var inst: Node2D = _prefab_bridge_maker.instantiate()
					
					# place bridge maker on the center of the cell below the player
					var player_bottom: Vector2i = global_position + Vector2.DOWN * $CollisionShape2D.shape.size.y / 2.0
					inst.global_position = get_position_of_tile((get_tiled_pos_of(player_bottom) + Vector2i(0, 1)))
					add_sibling(inst)
					inst.activate()
					stamina_points -= 8
					
					_active_bridge_maker = inst
					_active_item_key = event.keycode
				
				# 4 key: spring
				elif event.pressed and event.keycode == KEY_4 and meets_stamina_requirement(6):
					_active_item_key = event.keycode
					begin_item_craft(0.5, 6, _prefab_spring)
			
			elif event.is_released() and event.keycode == _active_item_key:
				if _active_bridge_maker != null:
					deactivate_active_item()
					
				if _item_craft_progress != null:
					print("cancel item craft")
					_item_craft_progress = null
					_active_item_key = KEY_NONE
	#var status_text: Label = get_node("Camera2D/Status")
	#status_text.text = "Stamina: %s\nTime remaining: %10.2f" % [stamina_points, time_remaining]

func get_tiled_pos_of(pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(pos))

func get_position_of_tile(coord: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(coord))

func _handle_jump(delta: float) -> void:
	var can_jump := (current_state == PlayerState.FREEMOVE and is_on_floor()) or (current_state == PlayerState.WALLSLIDE and is_on_wall_only());
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

func _physics_process(delta: float) -> void:
	if _active_bridge_maker != null and not _active_bridge_maker.active:
		_active_bridge_maker = null
		
	if _item_craft_progress != null:
		current_state = PlayerState.CRAFTING
		_item_craft_progress.time_remaining -= delta
		if _item_craft_progress.time_remaining <= 0.0:
			finish_item_craft()
	
	if is_taking_damage and _iframe_timer <= 0.0:
		_stun_timer = DAMAGE_STUN_LENGTH
		_iframe_timer = IFRAME_LENGTH
		current_state = PlayerState.STUNNED
		velocity = Vector2(0, -200)
		deactivate_active_item()
		_item_craft_progress = null
	
	_iframe_timer = move_toward(_iframe_timer, 0, delta)

	_handle_jump(delta);

	# calculate move direction
	var move_dir := 0
	if _active_bridge_maker == null and _item_craft_progress == null:
		if Input.is_action_pressed("player_right"):
			move_dir += 1
		if Input.is_action_pressed("player_left"):
			move_dir -= 1
	
	match current_state:
		PlayerState.FREEMOVE:
			# apply gravity normally
			velocity += get_gravity() * delta

			# apply movement direction
			# velocity.x = move_toward(velocity.x, walk_speed * move_dir, walk_acceleration * delta);
			velocity.x += walk_acceleration * move_dir * delta
			velocity.x *= speed_damping

			if is_on_wall_only() and move_dir != 0:
				_jump_remaining = 0.0
				current_state = PlayerState.WALLSLIDE
		
		PlayerState.STUNNED:
			# apply gravity normally
			velocity += get_gravity() * delta
			
			# damping
			velocity.x *= speed_damping
			
			_stun_timer = move_toward(_stun_timer, 0, delta)
			if _stun_timer <= 0.0:
				current_state = PlayerState.FREEMOVE
		
		PlayerState.CRAFTING:
			velocity = Vector2.ZERO
			if _item_craft_progress == null:
				current_state = PlayerState.FREEMOVE
		
		PlayerState.WALLSLIDE:
			move_direction = 1 if get_wall_normal().x > 0.0 else -1

			if _jump_remaining > 0.0:
				current_state = PlayerState.WALLJUMP
				_wall_jump_freeze = WALL_JUMP_FREEZE_LENGTH
				velocity.x = move_direction * wall_jump_velocity
			elif not is_on_wall_only():
				current_state = PlayerState.FREEMOVE
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
				current_state = PlayerState.WALLSLIDE
				velocity.x = -get_wall_normal().x * 100.0 # please stay on the wall
				
			elif is_on_floor() or _wall_jump_freeze < 0.0:
				_jump_remaining = 0.0
				current_state = PlayerState.FREEMOVE
				
			else:
				velocity.x += move_dir * wall_jump_control_acceleration * delta
				velocity.x *= wall_jump_damping
	
	_last_move_dir = move_dir
	move_and_slide()

func kill() -> void:
	game_reset();
	Global.game_state = Global.GameState.DEATH;
