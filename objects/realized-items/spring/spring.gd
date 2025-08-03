extends RigidBody2D

@export var bounce_power := 540.0

func on_body_entered(body: Node):
	if body.has_method("spring_bounce_callback"):
		body.spring_bounce_callback(bounce_power)
		
func activate():
	await get_tree().create_timer(0.1).timeout
	$BounceArea.body_entered.connect(on_body_entered)
