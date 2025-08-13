extends RigidBody2D
class_name Spring

static var BOUNCE_POWER := 540.0

func on_body_entered(body: Node):
	if body.has_method("_on_spring_bounce"):
		Global.play(Global.Sound.BOOST)
		body._on_spring_bounce()
		
func activate():
	await get_tree().create_timer(0.1).timeout
	$BounceArea.body_entered.connect(on_body_entered)

func is_active():
	return false
