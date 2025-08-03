extends Control

var previous_state: Global.GameState;
var previous_pause: bool;

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed)

func _on_gamemode_changed(from_state: Global.GameState, to_state: Global.GameState):
	if to_state == Global.GameState.ABOUT_CONTROLS:
		self.visible = true;
		previous_state = from_state;
		previous_pause = get_tree().paused;
		get_tree().paused = true;
	else: self.visible = false;

func _on_back_button_pressed() -> void:
	Global.game_state = previous_state;
	get_tree().paused = previous_pause;
