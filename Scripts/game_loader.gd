extends Node2D

const collectibles: Dictionary[Vector2i, Resource] = {
	Vector2i(0, 0): preload("res://Objects/stamina_collectible.tscn")
}

var deadly_tiles: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 0)]

func _ready() -> void:
	var collectibles_tile_map: TileMapLayer = $CollectiblesTileMap
	var tile_map: TileMapLayer = $TileMap
	var deadly_area: Area2D = $DeadlyTiles
	
	# read the collectibles tilemap to instantiate collectible instances
	var ct_bounds := collectibles_tile_map.get_used_rect()	
	for y in range(ct_bounds.position.y, ct_bounds.end.y):
		for x in range(ct_bounds.position.x, ct_bounds.end.x):
			var tile_pos := Vector2i(x, y)
			var tile_uv := collectibles_tile_map.get_cell_atlas_coords(tile_pos)
			
			# instantiate collectible at this cell
			var scene_res: PackedScene = collectibles.get(tile_uv)
			if scene_res != null:
				var obj: Node2D = scene_res.instantiate()
				obj.position = collectibles_tile_map.map_to_local(tile_pos)
				add_child(obj)
	
	collectibles_tile_map.visible = false
	
	# create deadly areas from the spikes
	var main_bounds := tile_map.get_used_rect()
	var tile_size = tile_map.tile_set.tile_size
	for y in range(main_bounds.position.y, main_bounds.end.y):
		for x in range(main_bounds.position.x, main_bounds.end.x):
			var tile_pos := Vector2i(x, y)
			var tile_uv := tile_map.get_cell_atlas_coords(tile_pos)
			
			# create collider at this cell
			if deadly_tiles.has(tile_uv):
				var collider := CollisionShape2D.new()
				var colshape := RectangleShape2D.new()
				colshape.size = tile_size - Vector2i(4, 4)
				collider.shape = colshape
				collider.position = tile_map.map_to_local(tile_pos)
				deadly_area.add_child(collider)	
