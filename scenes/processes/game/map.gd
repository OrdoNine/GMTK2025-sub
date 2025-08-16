extends TileMapLayer

@onready var _deadly_area = $DeadlyTiles
var _collider_dict: Dictionary[Vector2i, CollisionShape2D]

func _update_cells(coords: Array[Vector2i], _forced_cleanup: bool) -> void:	
	for coord in coords:
		# create/remove collider at this cell
		var tile_data = get_cell_tile_data(coord)
		var pre_existing_collider = _collider_dict.get(coord)
		
		if pre_existing_collider != null:
			pre_existing_collider.queue_free()
		
		if tile_data != null and tile_data.get_custom_data("Hazard"):
			var collider := CollisionShape2D.new()
			var colshape := RectangleShape2D.new()
			colshape.size = tile_set.tile_size - Vector2i(4, 4)
			collider.shape = colshape
			collider.position = map_to_local(coord)
			_deadly_area.add_child(collider)
			_collider_dict[coord] = collider
		else:
			_collider_dict.erase(coord)
