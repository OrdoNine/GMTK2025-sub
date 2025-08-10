extends Camera2D

func _ready():
	Global.get_game().round_started.connect(round_reset)

func round_reset(_new_round: bool):
	position = get_node("../Player").position
	reset_physics_interpolation()

func _physics_process(_delta: float) -> void:
	position = get_node("../Player").position
