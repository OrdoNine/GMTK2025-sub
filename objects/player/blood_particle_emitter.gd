extends Node2D

const EMISSION_COUNT: int = 6
const EMISSION_VELOCITY: float = 140.0
const LIFETIME: float = 0.3

const texture = preload("res://assets/strudel_blood.png")

func _ready():
	pass


func emit():
	var player := get_parent()
	var root := player.get_parent()
	
	for i in range(0, EMISSION_COUNT):
		var ang := float(i) / EMISSION_COUNT * PI * 2
		
		var particle := Particle.new()
		particle.texture = texture
		particle.position = player.position
		#particle.scale = Vector2.ONE * 2.0
		particle.life = LIFETIME
		particle.velocity = Vector2(cos(ang), sin(ang)) * EMISSION_VELOCITY \
				+ Vector2(0, -200.0) \
				+ player.velocity
		particle.gravity = Vector2(0, 800.0)
		# sprite.rotation = i / (EMISSION_COUNT - 1) * PI * 2
		
		root.add_child(particle)


class Particle extends Sprite2D:
	var velocity: Vector2
	var gravity: Vector2
	var life: float
	
	func _init() -> void:
		velocity = Vector2.ZERO
		gravity = Vector2.ZERO
		life = 0.0
	
	func _process(delta: float) -> void:
		if life <= 0.0:
			queue_free()
		
		life = move_toward(life, 0, delta)
		position += velocity * delta
		velocity += gravity * delta
		rotation = atan2(-velocity.x, velocity.y)
		
		var a := 1.0 - life / LIFETIME
		scale = Vector2.ONE * pow(1.0 - pow(a, 4.0), 0.7)
