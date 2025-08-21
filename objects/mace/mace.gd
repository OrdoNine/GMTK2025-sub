extends Node2D
class_name Mace

var grace_period_timer := PollTimer.new(5.0)
signal chomped_player

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player and not grace_period_timer.is_active:
		var dir = global_position.direction_to(body.global_position)
		body.kill(dir)
		chomped_player.emit()
		
		grace_period_timer.activate()

const OPEN_MOUTH_ZONE_DISTANCE : float = 100
const OPEN_MOUTH_ZONE_DISTANCE_SQUARED : float = OPEN_MOUTH_ZONE_DISTANCE * OPEN_MOUTH_ZONE_DISTANCE


func _physics_process(delta: float) -> void:
	grace_period_timer.update(delta)


func _process(_dt: float) -> void:
	var difference : Vector2 = position - %Player.position
	$AnimatedSprite2D.flip_h = difference.x > 0
	$AnimatedSprite2D.animation = "open_mouth" if\
				difference.length_squared() < OPEN_MOUTH_ZONE_DISTANCE_SQUARED\
				else "close_mouth"
