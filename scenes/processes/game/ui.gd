extends UiMenuManager
class_name UI

# Variables for Warmup Menu
var countdown_active := true
var countdown_timer := PollTimer.new(2)

func _on_resume_button_pressed() -> void:
	%PauseUI.visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_exit_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/processes/main_menu/main_menu_process.tscn")


func _on_game_round_ended() -> void:
	get_tree().paused = true
	%WarmupMenu.visible = true
	%CountdownMode.visible = true
	%IndefiniteMode.visible = false
	countdown_timer.activate()
	countdown_active = true


func _input(event: InputEvent) -> void:
	# pause the countdown timer when pause is pressed
	if event is InputEventKey:
		if event.pressed and event.is_action("game_pause"):
			if %WarmupMenu.visible and countdown_active:
				%CountdownMode.visible = false
				%IndefiniteMode.visible = true
				countdown_active = false


func _process(dt: float) -> void:
	if %WarmupMenu.visible and countdown_active:
		countdown_timer.update(dt)
		if countdown_timer.time_remaining == 0:
			%WarmupMenu.visible = false
			get_tree().paused = false
			Global.get_game().next_round()
		%WarmupCounter.text = str(snappedf(countdown_timer.time_remaining, 0.1))


func _on_warmup_resume_button_pressed() -> void:
	%WarmupMenu.visible = false
	get_tree().paused = false
	Global.get_game().next_round()


func _on_game_game_over() -> void:
	get_tree().paused = true
	%GameOver.visible = true
