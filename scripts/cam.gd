extends Camera2D

# Public variables & constants
# Empty for now.....

# Public Methods
# Empty for now.....

# Private variables & constants
@onready var player = get_node("../Player");

# Private Methods
func _process(_delta: float) -> void:
	self.position = player.position; # Follow the player
