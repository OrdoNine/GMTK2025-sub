extends Area2D

func on_body_entered(body: Node2D):
	if body.is_in_group("players"):
		print("Game reset")
		
		for node in get_tree().get_nodes_in_group("players"):
			if node.has_method("game_reset"):
				node.game_reset()
		
		for node in get_tree().get_nodes_in_group("collectibles"):
			if node.has_method("game_reset"):
				node.game_reset()

func _ready() -> void:
	body_entered.connect(on_body_entered)
