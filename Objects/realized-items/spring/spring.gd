extends RigidBody2D

@export var BOUNCE_POWER := 540.0
@onready var _bounce_area := $BounceArea

func on_body_entered(body: Node):
	if body is CharacterBody2D:
		body.velocity.y = -BOUNCE_POWER
		
func activate():
	await get_tree().create_timer(0.1).timeout
	_bounce_area.body_entered.connect(on_body_entered)
