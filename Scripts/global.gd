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
	push_error("COULD NOT READ " + str(path) + ". Please check the file for any errors.")
	return

enum GameState {
	MAIN_MENU,
	GAMEPLAY,
	PAUSE,
	DEATH,
	ABOUT_CONTROLS, # the state where you would see the "About controls" section.
					# cz you definetely should not have them in the UI.
	LOOP_START_WAIT, # the state when you are waiting after getting a win to start the next loop.
}

signal gamemode_changed(from_state: GameState, to_state: GameState);
signal ui_update(time_remaining: float, round_number: int);
signal game_new_loop;
signal reset_tilemap;

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
	if to_state == GameState.PAUSE || to_state == GameState.DEATH:
		get_tree().paused = true;
		ui_update.emit(0, round_number);
	elif to_state == GameState.GAMEPLAY:
		get_tree().paused = false;
		if from_state == GameState.DEATH:
			game_begin_new_loop()
			on_game_restart();
			reset_tilemap.emit();
		elif from_state == GameState.LOOP_START_WAIT:
			Global.game_begin_new_loop()
			round_time -= 2;
			time_remaining = round_time;
			round_number += 1
		elif from_state == GameState.MAIN_MENU:
			round_time = MAXIMUM_ROUND_TIME;
			time_remaining = round_time;
		elif from_state == GameState.PAUSE:
			if PauseUI.reason_to_gameplay == PauseUI.GameplaySwitchReason.RESTART:
				game_begin_new_loop()
				on_game_restart();
				reset_tilemap.emit();
	elif to_state == GameState.MAIN_MENU:
		get_tree().paused = false;

func on_game_restart() -> void:
	round_time = MAXIMUM_ROUND_TIME;
	time_remaining = round_time;
	round_number = 0;

func game_begin_new_loop():
	game_new_loop.emit()

func _process(delta: float):	
	if game_state == GameState.GAMEPLAY:
		ui_update.emit(time_remaining, round_number)
		
		if time_remaining <= 0.0:
			time_remaining = 0;
		
		# time_remaining -= delta
