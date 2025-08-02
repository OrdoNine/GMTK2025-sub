extends Control

var stamina_points: int = 0;
var time_remaining: float = 0.0;
var round_number: int = 0

func _process(_delta: float) -> void:
	var status_text: Label = get_node("Status")
	status_text.text = "Round: %s\nSlime: %s\nTime remaining: %.2f" % \
		[round_number, stamina_points, time_remaining]
