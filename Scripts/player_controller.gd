extends CharacterBody2D

const WALL_JUMP_FREEZE_LENGTH := 0.1

enum PlayerState {
	FREEMOVE, # normal grounded/mid-air movement mode
	WALLSLIDE, # currently wallsliding
	WALLJUMP, # jump from a wallslide. diminished mid-air control
}

@export_range(0, 10000) var jump_power = 300
@export_range(0.1, 10) var jump_length = 0.5
@export_range(0, 10000) var walk_speed = 200.0
@export_range(0.0, 1.0) var jump_stop_power = 0.5

# TODO: time_remaining is not stored in player?
var stamina_points: int = 0
var round_time: int = 30
var time_remaining: float

# progress of the jump, from 0.0 to 1.0.
# 1.0 means the player just started jumping; 0.0 means the player is not jumping
var _jump_remaining = 0.0
var _wall_jump_freeze = 0.0
var current_state := PlayerState.FREEMOVE
var construction_area: Area2D
@onready var _start_pos := position
@onready var tilemap: TileMapLayer = get_node("../TileMap")

var should_update : bool;

func _on_game_gamemode_changed(state: Global.GameState) -> void:
	should_update = (state == Global.GameState.GAMEPLAY);
	
func _ready() -> void:
	Global.gamemode_changed.connect(_on_game_gamemode_changed)
	time_remaining = round_time
	should_update = true;
	game_reset();

func game_reset():
	position = _start_pos
	round_time -= 1
	time_remaining = round_time
	
func get_tiled_pos_of_player() -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(global_position))

func get_postion_of_tile(coord: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(coord))

func get_destructible_tiles() -> Array:
	return [ Vector2i(1, 0), Vector2i(3, 0) ];

# destroy radius of blocks
func eat() -> void:
	var player_tile_coord = get_tiled_pos_of_player();
	var destructible_tiles = get_destructible_tiles();

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos: Vector2i = player_tile_coord + Vector2i(dx, dy)
			var coords = tilemap.get_cell_atlas_coords(pos) # Gives the coords of that tile in the spritesheet

			# TODO: make hashset of destructible tiles (szudzik/cantor pairing function?)
			# Idk bout the above, but arrays are better than what were before.
			if coords in destructible_tiles:
				tilemap.erase_cell(pos)

# create a platform
func spit() -> void:
	var player_tile_coord := get_tiled_pos_of_player();
	var player_tile_pos := get_postion_of_tile(player_tile_coord);

	var square := RectangleShape2D.new()
	square.size = tilemap.tile_set.tile_size * 3
	var hitbox := CollisionShape2D.new()
	hitbox.shape = square

	construction_area = Area2D.new();
	construction_area.add_child(hitbox)
	construction_area.position = player_tile_pos;
	get_parent().add_child(construction_area)

	# once player leaves this temporary area, the cells occupied by the
	# area will be filled with the Goop. if the cell is empty.	
	construction_area.body_exited.connect(func(body):
		if body == self:
			construction_area.queue_free()
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var pos: Vector2i = player_tile_coord + Vector2i(dx, dy)

					# overwrite cell if exists
					if tilemap.get_cell_source_id(pos) == -1:
						tilemap.set_cell(pos, 1, Vector2i(3, 0))
		)

func _process(_delta: float) -> void:
	if !should_update: return;
	
	if Input.is_action_just_pressed("escape"):
		if Global.ignore_escape: Global.ignore_escape = false;
		else: Global.game_state = Global.GameState.PAUSE;
	
	if stamina_points > 0:
		if Input.is_action_just_pressed("player_action1"):
			eat()
			stamina_points -= 1

		if Input.is_action_just_pressed("player_action2"):
			spit()
			stamina_points -= 1
	
	$"../Camera2D/GamePlayUI".stamina_points = stamina_points;
	$"../Camera2D/GamePlayUI".time_remaining = time_remaining;

func _handle_jump(delta: float) -> void:
	var can_jump := (current_state == PlayerState.FREEMOVE and is_on_floor()) or (current_state == PlayerState.WALLSLIDE and is_on_wall_only());

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
	if !should_update: return;
	if time_remaining <= 0.0:
		time_remaining = 0;
		kill()

	time_remaining -= delta

	_handle_jump(delta);

	# calculate move direction
	var move_dir := int(Input.is_action_pressed("player_right")) - int(Input.is_action_pressed("player_left"));
	
	match current_state:
		PlayerState.FREEMOVE:
			velocity += get_gravity() * delta # apply gravity normal
			velocity.x = move_dir * walk_speed # apply movement direction
			if is_on_wall_only() and velocity.y > 0.0:
				current_state = PlayerState.WALLSLIDE

		PlayerState.WALLSLIDE:
			if _jump_remaining > 0.0:
				current_state = PlayerState.WALLJUMP
				_wall_jump_freeze = WALL_JUMP_FREEZE_LENGTH
				velocity.x = get_wall_normal().x * walk_speed
			elif not is_on_wall_only():
				current_state = PlayerState.FREEMOVE
			else:
				velocity.y = get_gravity().y * delta * 4.0
				velocity.x = move_dir * walk_speed

		PlayerState.WALLJUMP:
			velocity += get_gravity() * delta # apply gravity normal
			# velocity.x = move_dir * walk_speed # apply movement direction
			if is_on_wall():
				_jump_remaining = 0.0
				current_state = PlayerState.WALLSLIDE
			elif is_on_floor() or _wall_jump_freeze < 0.0:
				_jump_remaining = 0.0
				current_state = PlayerState.FREEMOVE
	
	move_and_slide()

func kill() -> void:
	game_reset();
	Global.game_state = Global.GameState.DEATH;
