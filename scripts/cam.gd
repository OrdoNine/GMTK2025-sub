extends Camera2D

# Private Variables & Methods
@onready var _player = get_node("../Player");

func _process(_delta: float) -> void:
	self.position = _player.position; # Follow the player
