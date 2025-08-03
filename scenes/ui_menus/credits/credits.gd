extends Control

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed)

func _on_gamemode_changed(from_state: Global.GameState, to_state: Global.GameState):
	self.visible = to_state == Global.GameState.CREDITS;

func _on_back_button_pressed() -> void:
	pass


func _on_back_button_released() -> void:
	get_tree().quit();
