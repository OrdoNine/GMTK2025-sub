extends Control

var stamina_points: int;
var time_remaining: float;

func _process(delta: float) -> void:
	var status_text: Label = get_node("Status")
	status_text.text = "Stamina: %s\nTime remaining: %10.2f" % [stamina_points, time_remaining]
