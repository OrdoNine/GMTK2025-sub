extends Node2D
class_name Game

const collectibles: Dictionary[Vector2i, Resource] = {
	Vector2i(0, 0): preload("res://objects/stamina_collectible/stamina_collectible.tscn")
}

var round_number: int = 1
var stamina_points: int = 0
var player_lives: int = 3
signal round_started(new_round: bool)
signal round_ended

func _ready() -> void:
	setup_level()
	
func next_round():
	round_number += 1
	round_started.emit(true)

func reset_round():
	round_started.emit(false)

func setup_level() -> void:
	var collectibles_tile_map: TileMapLayer = $CollectiblesTileMap
	
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

func end_round() -> void:
	print("round ended")
	round_ended.emit()