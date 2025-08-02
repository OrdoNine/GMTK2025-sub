extends Node2D

var speed = 100
var velocity = Vector2.ZERO
@onready var player = get_parent().get_node("Player")

func _ready():
	var player_pos = player.position
	print("Player position: ", player_pos)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		body.kill()
		
func _physics_process(delta: float) -> void:		
	var player_pos = player.position
	print("Player position: ", player_pos)
	var direction = (player.global_position - global_position).normalized()
	move_and_collide(direction * speed * delta)
