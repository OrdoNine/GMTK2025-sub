extends Sprite2D

@onready var start_pos := global_position
var position_to_go: Vector2
var direction: Vector2
const MAX_HOVER_DISTANCE := 15.0
const SPEED := 20.0

func _ready() -> void:
	_pick_new_hover_target()

func _physics_process(delta: float) -> void:
	var to_target := position_to_go - global_position
	var distance := to_target.length()
	if distance < 1.0:
		_pick_new_hover_target()
	else:
		direction = to_target.normalized();
		global_position += direction * SPEED * delta

func _pick_new_hover_target() -> void:
	var angle = randf_range(0, TAU);
	var radius = randf_range(4.0, MAX_HOVER_DISTANCE);  # Minimum radius avoids jitter=
	
	position_to_go = start_pos + Vector2.RIGHT.rotated(angle) * radius;
