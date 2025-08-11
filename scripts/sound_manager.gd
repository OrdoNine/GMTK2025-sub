extends Node

class_name SoundManager;

enum Sound {
	JUMP,
	LAND,
	HURT,
	CRAFTING,
	BOOST,
	PLACE,
	COLLECT
}

static var _sound_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	var sounds : Array = Sound.keys()
	for sound in sounds:
		var name_lowercased : String = sound.to_lower()
		var path_to_sound : String = "res://assets/sounds/" + name_lowercased + ".wav"

		var player : AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load(path_to_sound)
		add_child(player);
		
		_sound_players.push_back(player);

static func play(sound: Sound) -> AudioStreamPlayer:
	_sound_players[sound].play();
	return _sound_players[sound];

static func stop(sound: Sound) -> void:
	if not _sound_players.is_empty():
		_sound_players[sound].stop();
