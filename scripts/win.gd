extends Area2D

func on_body_entered(_body: Node2D):
	Global.get_game().end_round()

func _ready() -> void:
	body_entered.connect(on_body_entered)
