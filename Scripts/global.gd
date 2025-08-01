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
		if state == GameState.PAUSE:
			print("Switched to pause!");
		elif state == GameState.GAMEPLAY:
			print("Switched to gameplay!")
		gamemode_changed.emit(state);

var ignore_escape: bool = false; # For PAUSE->GAMPLAY transition

func _ready() -> void:
	game_state = GameState.MAIN_MENU;
