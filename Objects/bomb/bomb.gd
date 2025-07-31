extends RigidBody2D

const EXPLOSION_RADIUS: float = 54 # in pixels

@onready var _tilemap: TileMapLayer = get_node("../TileMap")
var _timer := -1.0
var _explosion_area: Area2D

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

func explode() -> void:
	# destroy cells in tilemap
	var origin_pos := _tilemap.to_local(global_position)
	var origin_cell_pos := _tilemap.local_to_map(origin_pos)
	var explosion_cell_radius := EXPLOSION_RADIUS / _tilemap.tile_set.tile_size.x
	
	var diameter_min := int(floor(-explosion_cell_radius))
	var diameter_max := int(ceil(explosion_cell_radius))
	for x in range(diameter_min, diameter_max + 1):
		for y in range(diameter_min, diameter_max + 1):
			var cell_pos := origin_cell_pos + Vector2i(x, y)
			var pos := _tilemap.map_to_local(cell_pos)
			
			if origin_pos.distance_squared_to(pos) < EXPLOSION_RADIUS * EXPLOSION_RADIUS:
				var coords := _tilemap.get_cell_atlas_coords(cell_pos)
				
				# TODO: make hashset of destructible tiles (szudzik/cantor pairing function?)
				if (coords.x == 1 and coords.y == 0) or (coords.x == 3 and coords.y == 0):
					_tilemap.erase_cell(cell_pos)
	
	# detect bodies which overlapped with the explosion radius
	for body in _explosion_area.get_overlapping_bodies():
		if body is CharacterBody2D:
			body.velocity = (body.global_position - global_position).normalized() * 300.0

func activate():
	_timer = 1.0

func _physics_process(delta: float) -> void:
	if _timer <= 0.0: return
	
	_timer -= delta
	if _timer <= 0.0:
		explode()
		queue_free()