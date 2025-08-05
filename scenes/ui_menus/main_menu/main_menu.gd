extends UiMenuManager

func _ready() -> void:
	switch_to_menu($MainMenu)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	Global.game_state = Global.GameState.GAMEPLAY;

func _on_controls_pressed() -> void:
	switch_to_menu($AboutControls)

func _on_credits_pressed() -> void:
	switch_to_menu($CreditsMenu)

func _on_quit_pressed() -> void:
	get_tree().quit()
