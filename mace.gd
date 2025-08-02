extends Node2D
class_name Mace

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		body.kill()
