extends Node

class_name Globals

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
		gamemode_changed.emit(state);
		print("State changed: " + str(state))

func _ready() -> void:
	game_state = GameState.MAIN_MENU;
