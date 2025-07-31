extends Control

func _process(delta: float) -> void:
	if Input.is_action_pressed("escape"):
		get_tree().quit();

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
	Global.game_state = Global.GameState.GAMEPLAY;

func _on_exit_button_pressed() -> void:
	get_tree().quit()
