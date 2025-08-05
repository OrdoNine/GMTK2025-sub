extends Control

signal menu_exited

func _on_back_pressed() -> void:
	print("Test")
	menu_exited.emit()