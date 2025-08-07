extends Node
class_name Globals

var maceAttackPatterns : Dictionary

func _ready() -> void:
	maceAttackPatterns = read_JSON("res://resources/components/macepatterns.json")

func read_JSON(path):
	var json = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json)
	if data:
		return data
	push_error("COULD NOT READ " + str(path) + ". Please check the file for any errors.")
	return
	
func get_game() -> Game:
	return get_tree().get_first_node_in_group("game")
