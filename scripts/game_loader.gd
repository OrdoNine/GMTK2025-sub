extends Node2D # main.tscn: Game node

# Public Variables & Constants
# Empty for now...

# Public Methods
# Empty for now...

# Private Variables & Constants
const COLLECTABLE_SLIME_SCENE := "res://objects/realized-items/stamina_collectable/stamina_collectable.tscn";
const _atlas_pos_to_collectables: Dictionary[Vector2i, Resource] = {
	Vector2i(0, 0): preload(COLLECTABLE_SLIME_SCENE)
}

# Private Methods
func _ready() -> void:
	# CollectablesMap is a tilemap, mapping position to a collectable object.
	var collectables_map : TileMapLayer = %CollectablesMap;
	_instanciate_collectable_from(collectables_map);
	collectables_map.visible = false; # The tilemap is a design help. Not a thing to be viewed in game.

## This method is used to instanciate collectable objects and push it onto
## game during runtime with a help of a tilemap, mapping position to tile object.
func _instanciate_collectable_from(collectables_map : TileMapLayer) -> void:
	# Coordinates are in Tilemap Coordinate System
	var collectables_bounding_box : Rect2i = collectables_map.get_used_rect()
	var top_left_most_tile_pos_inclusive : Vector2i = collectables_bounding_box.position;
	var bottom_right_most_tile_pos_exclusive : Vector2i = collectables_bounding_box.end;
	
	for x in range(top_left_most_tile_pos_inclusive.x, bottom_right_most_tile_pos_exclusive.x):
		for y in range(top_left_most_tile_pos_inclusive.y, bottom_right_most_tile_pos_exclusive.y):
			var tile_pos : Vector2i = Vector2i(x, y)
			var tile_pos_in_atlas : Vector2i = collectables_map.get_cell_atlas_coords(tile_pos)
			
			var collectable_obj : PackedScene = _atlas_pos_to_collectables.get(tile_pos_in_atlas)
			if collectable_obj != null:
				var instance : Node2D = collectable_obj.instantiate()
				instance.position = collectables_map.map_to_local(tile_pos)
				self.add_child(instance)
