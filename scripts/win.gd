extends Area2D

func on_body_entered(_body: Node2D):
	if Global.round_number % 10 != 0:
		Global.game_state = Global.GameState.LOOP_START_WAIT;
	else:
		Global.game_state = Global.GameState.WIN_STATE;
	get_tree().paused = true;

func _ready() -> void:
	body_entered.connect(on_body_entered)
