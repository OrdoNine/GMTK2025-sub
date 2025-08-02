extends Node
class_name Globals

var maceAttackPatterns : Dictionary

func _ready() -> void:
	maceAttackPatterns = read_JSON("res://Resources/Components/macepatterns.json")
	gamemode_changed.connect(_on_gamemode_changed);
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

signal gamemode_changed(from_state: GameState, to_state: GameState);
signal ui_update(time_remaining: float, round_number: int);

var game_state : GameState :
	set(state):
		var from_state := game_state;
		game_state = state;
		gamemode_changed.emit(from_state, state);

var ignore_escape: bool = false; # For PAUSE->GAMPLAY transition

const MAXIMUM_ROUND_TIME = 50;
var round_time: int = MAXIMUM_ROUND_TIME;
var round_number: int = 0
var time_remaining: float

func _on_gamemode_changed(from_state: GameState, to_state: GameState):
	if to_state == GameState.PAUSE:
		ui_update.emit(0, round_number);
	if to_state == GameState.GAMEPLAY:
		if from_state == GameState.DEATH:
			# Reset game here
			round_time -= 2
			time_remaining = round_time
			round_number += 1
		elif from_state == GameState.MAIN_MENU:
			round_time = MAXIMUM_ROUND_TIME;
			time_remaining = round_time;

func _process(delta: float):	
	if game_state == GameState.GAMEPLAY:
		ui_update.emit(time_remaining, round_number)
		
		if time_remaining <= 0.0:
			time_remaining = 0;
		
		time_remaining -= delta
