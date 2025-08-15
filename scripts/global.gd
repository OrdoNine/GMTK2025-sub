extends Node
class_name Globals

enum Sound {
	JUMP,
	LAND,
	HURT,
	CRAFTING,
	BOOST,
	PLACE,
	COLLECT
}

var _sound_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	maceAttackPatterns = read_JSON("res://resources/components/macepatterns.json")
	
	
	var sounds : Array = Sound.keys()
	for sound in sounds:
		var name_lowercased : String = sound.to_lower()
		var path_to_sound : String = "res://assets/sounds/" + name_lowercased + ".wav"

		var player : AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load(path_to_sound)
		add_child(player)
		
		_sound_players.push_back(player)

func play(sound: Sound) -> AudioStreamPlayer:
	if not _sound_players:
		return
	if _sound_players.is_empty():
		return

	_sound_players[sound].play()
	return _sound_players[sound]

func stop(sound: Sound) -> void:
	if not _sound_players:
		return
	if _sound_players.is_empty():
		return

	_sound_players[sound].stop()

var maceAttackPatterns : Dictionary
func read_JSON(path):
	var json = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json)
	if data:
		return data
	push_error("COULD NOT READ " + str(path) + ". Please check the file for any errors.")
	return
	
func get_game() -> Game:
	return get_tree().get_first_node_in_group("game")
