extends RigidBody2D

const EXPLOSION_RADIUS: float = 38 # in pixels
const EXPANSION_SPEED: float = 50

@onready var _tilemap: TileMapLayer = get_node("../TileMap")
var _timer := -1.0
var _explosion_area: Area2D
var _is_exploding := false
var _current_explosion_radius: float = 0.0

func _ready() -> void:
	_explosion_area = Area2D.new()
	_explosion_area.collision_layer = 0
	_explosion_area.collision_mask = 2
	_explosion_area.monitoring = true
	_explosion_area.monitorable = false
	
	var colshape := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = EXPLOSION_RADIUS
	colshape.shape = shape
	_explosion_area.add_child(colshape)
	
	add_child(_explosion_area)

func fill_radius(radius: float) -> void:
	if radius <= 0.0: return
	
	# create slime block cells
	var origin_pos := _tilemap.to_local(global_position)
	var origin_cell_pos := _tilemap.local_to_map(origin_pos)
	
	# move origin pos to the center of the tile
	origin_pos = _tilemap.map_to_local(origin_cell_pos)
	
	var explosion_cell_radius := radius / _tilemap.tile_set.tile_size.x
	
	var diameter_min := int(floor(-explosion_cell_radius))
	var diameter_max := int(ceil(explosion_cell_radius))
	for x in range(diameter_min, diameter_max + 1):
		for y in range(diameter_min, diameter_max + 1):
			var cell_pos := origin_cell_pos + Vector2i(x, y)
			var pos := _tilemap.map_to_local(cell_pos)
			
			if origin_pos.distance_squared_to(pos) < radius * radius:
				# overwrite cell if it is empty
				if _tilemap.get_cell_source_id(pos) == -1:
					_tilemap.set_cell(cell_pos, 1, Vector2i(3, 0))
	
	# detect bodies which overlapped with the explosion radius
	for body in _explosion_area.get_overlapping_bodies():
		if body is CharacterBody2D:
			body.velocity = (body.global_position - global_position).normalized() * 300.0

func activate():
	_timer = 0.5

func is_active():
	return false

func _physics_process(delta: float) -> void:
	if _is_exploding:
		if _current_explosion_radius >= EXPLOSION_RADIUS:
			queue_free()
			_is_exploding = false
			return
		
		fill_radius(_current_explosion_radius)
		_current_explosion_radius = move_toward(_current_explosion_radius, EXPLOSION_RADIUS, EXPANSION_SPEED * delta)
		
	else:
		if _timer <= 0.0: return
		
		_timer -= delta
		if _timer <= 0.0:
			_is_exploding = true
