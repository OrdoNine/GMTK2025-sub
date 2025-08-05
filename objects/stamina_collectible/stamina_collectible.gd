extends Area2D

func game_reset(new_round: bool):
	if new_round:
		visible = true
		set_deferred("monitorable", true)
		set_deferred("monitoring", true)

func on_body_entered(body: Node2D):
	if body.is_in_group("players"):
		visible = false
		set_deferred("monitorable", false)
		set_deferred("monitoring", false)
		
		$CollectSound.pitch_scale = 1.0 + randf() * 0.3
		$CollectSound.play()

		Global.get_game().stamina_points += 1

func _ready() -> void:
	body_entered.connect(on_body_entered)
	Global.get_game().round_started.connect(game_reset)
