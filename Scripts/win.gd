extends Area2D

func on_body_entered(_body: Node2D):
	Global.game_state = Global.GameState.LOOP_START_WAIT;
	get_tree().paused = true;

func _ready() -> void:
	body_entered.connect(on_body_entered)
