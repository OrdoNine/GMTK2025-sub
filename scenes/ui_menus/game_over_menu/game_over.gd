extends Control

func _on_gamemode_changed(_from_state: Global.GameState, state: Global.GameState) -> void:
	self.visible = state == Global.GameState.GAME_OVER;

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed)
	visible = false;

func _on_back_to_menu_button_pressed() -> void:
	Global.completely_clear_game_data()
	Global.game_state = Global.GameState.MAIN_MENU;
	get_tree().change_scene_to_file("res://scenes/ui_menus/main_menu/main_menu.tscn")
