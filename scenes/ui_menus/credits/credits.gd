extends Control

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed)

func _on_gamemode_changed(from_state: Global.GameState, to_state: Global.GameState):
	self.visible = to_state == Global.GameState.CREDITS;
	
	# WHY DO YOU HAVE TO PAUSE THE GAME SO THAT THE BACK BUTTON WORKS
	# WHY WHY WHY WHY WHY WHY WHY WHY WHY
	if to_state == Global.GameState.CREDITS:
		get_tree().paused = true

func _on_back_button_pressed() -> void:
	Global.game_state = Global.GameState.MAIN_MENU
	print("pressed")
	pass


func _on_back_button_released() -> void:
	pass
