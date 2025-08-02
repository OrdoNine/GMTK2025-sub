extends Control

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed)

func _on_gamemode_changed(_from_state: Global.GameState, state: Global.GameState) -> void:
	self.visible = state == Global.GameState.LOOP_START_WAIT;

func _on_start_new_loop_pressed() -> void:
	get_tree().paused = false;
	Global.game_begin_new_loop()
	Global.game_state = Global.GameState.GAMEPLAY;

func _on_back_to_menu_pressed() -> void:
	get_tree().paused = false;
	Global.game_state = Global.GameState.MAIN_MENU;

func _on_exit_pressed() -> void:
	get_tree().quit();

func _on_controls_pressed() -> void:
	Global.game_state = Global.GameState.ABOUT_CONTROLS;
