extends Area2D

func game_reset():
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

		body.stamina_points += 1

func _ready() -> void:
	body_entered.connect(on_body_entered)
	Global.game_new_loop.connect(game_reset)
