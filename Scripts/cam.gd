extends Camera2D

func _process(delta: float) -> void:
	$".".position = %Player.position;
