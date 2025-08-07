extends Node2D

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_pause"):
		var root := get_tree()
		
		if root.paused:
			root.paused = false
			%PauseUI.visible = false
			
		else:
			root.paused = true
			%PauseUI.visible = true
		
func _exit_tree() -> void:
	get_tree().paused = false
	
func _ready() -> void:
	%PauseUI.visible = false

func _on_game_round_ended() -> void:
	Global.get_game().next_round()

func _on_exit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/processes/main_menu/main_menu_process.tscn")

func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	%PauseUI.visible = false
