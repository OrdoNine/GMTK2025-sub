extends RigidBody2D

@export var bounce_power := 180.0
@export var side_power := 800.0
@onready var _bounce_area := $BounceArea

func on_body_entered(body: Node):
	if body.has_method("horiz_spring_bounce_callback"):
		body.horiz_spring_bounce_callback(bounce_power, side_power)
		
func activate():
	await get_tree().create_timer(0.1).timeout
	_bounce_area.body_entered.connect(on_body_entered)

func is_active():
	return false
