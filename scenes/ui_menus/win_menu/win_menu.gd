extends Control

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed);

func _on_gamemode_changed(_from_state: Global.GameState, to_state: Global.GameState) -> void:
	self.visible = to_state == Global.GameState.WIN_STATE;
	if self.visible:
		$Rounds.text = "Rounds: " + str(Global.round_number)
		var player = get_node("../../Player");
		$Slimes.text = "Slimes: " + str(player.stamina_points);

func _on_continue_to_next_loop_button_pressed() -> void:
	Global.reason_to_gameplay = Global.GameplaySwitchReason.START_LOOP;
	get_tree().paused = false;
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
