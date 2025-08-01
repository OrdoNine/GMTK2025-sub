extends Camera2D

func _process(delta: float) -> void:
	position = get_node("../Player").position;
