extends Node
class_name Globals

var maceAttackPatterns : Dictionary

func _ready() -> void:
	maceAttackPatterns = read_JSON("res://Resources/Components/macepatterns.json")
  game_state = GameState.MAIN_MENU;

func read_JSON(path):
	var json = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json)
	if data:
		return data
	print("COULD NOT READ " + str(path) + ". Please check the file for any errors.")
	return

enum GameState {
	MAIN_MENU,
	GAMEPLAY,
	PAUSE,
	DEATH
}

signal gamemode_changed(state: GameState);

var game_state : GameState :
	set(state):
		game_state = state;
		if state == GameState.PAUSE:
			print("Switched to pause!");
		elif state == GameState.GAMEPLAY:
			print("Switched to gameplay!")
		elif state == GameState.DEATH:
			print("Switched to death!");
		gamemode_changed.emit(state);

var ignore_escape: bool = false; # For PAUSE->GAMPLAY transition

