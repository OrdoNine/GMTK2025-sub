extends Control

func _process(_delta: float) -> void:
	if Input.is_action_pressed("escape"):
		get_tree().quit();

func _on_start_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	Global.game_state = Global.GameState.GAMEPLAY;

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_controls_button_pressed() -> void:
	Global.game_state = Global.GameState.ABOUT_CONTROLS;

func _on_credits_button_pressed() -> void:
	Global.game_state = Global.GameState.CREDITS
