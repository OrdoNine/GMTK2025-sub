extends Node

var maceAttackPatterns : Dictionary

func _ready() -> void:
	maceAttackPatterns = read_JSON("res://Resources/Components/macepatterns.json")

func read_JSON(path):
	var json = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json)
	if data:
		return data
	print("COULD NOT READ " + str(path) + ". Please check the file for any errors.")
	return
