extends Control

class_name PauseUI;

func _on_gamemode_changed(_from_state: Global.GameState, state: Global.GameState) -> void:
	self.visible = state == Global.GameState.PAUSE;

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed)
	self.visible = false;

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("escape") and Global.game_state == Global.GameState.PAUSE:
		Global.ignore_escape = true;
		Global.game_state = Global.GameState.GAMEPLAY;

func _on_resume_button_pressed() -> void:
	Global.reason_to_gameplay = Global.GameplaySwitchReason.RESUME;
	Global.game_state = Global.GameState.GAMEPLAY;

func _on_back_to_menu_button_pressed() -> void:
	Global.game_state = Global.GameState.MAIN_MENU;
	get_tree().change_scene_to_file("res://scenes/ui_menus/main_menu/main_menu.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit();

func _on_controls_button_pressed() -> void:
	Global.game_state = Global.GameState.ABOUT_CONTROLS;

func _on_restart_button_pressed() -> void:
	Global.reason_to_gameplay = Global.GameplaySwitchReason.RESTART;
	Global.game_state = Global.GameState.GAMEPLAY;
