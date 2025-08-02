extends Camera2D

func _process(_delta: float) -> void:
	position = get_node("../Player").position;
