extends UiMenuManager
class_name UI

func _on_resume_button_pressed() -> void:
	%PauseUI.visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_exit_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/processes/main_menu/main_menu_process.tscn")
