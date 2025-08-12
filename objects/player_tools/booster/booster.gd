extends RigidBody2D

class_name Booster

static var BOUNCE_POWER := 180.0
static var SIDE_POWER := 800.0
@onready var _bounce_area := $BounceArea

func on_body_entered(body: Node):
	if body.has_method("_on_booster_bounce"):
		body._on_booster_bounce()
		
func activate():
	await get_tree().create_timer(0.1).timeout
	_bounce_area.body_entered.connect(on_body_entered)

func is_active():
	return false
