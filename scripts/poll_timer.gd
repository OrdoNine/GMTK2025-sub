extends Object
class_name PollTimer

var timeout_length: float
var time_remaining: float = 0.0
var is_active: bool

func _init(p_timeout_length: float):
	timeout_length = p_timeout_length
	is_active = false

func activate():
	time_remaining = timeout_length
	is_active = true

func deactivate():
	time_remaining = 0.0
	is_active = false

func is_done():
	return is_active and time_remaining == 0.0

## Get the timer's progress as a value given by the fraction time_remaining /
## timeout_length.
func get_progress_ratio() -> float:
	return time_remaining / timeout_length

func update(dt: float):
	if not is_active:
		return

	if is_done():
		deactivate()
		return

	if time_remaining <= 0:
		return

	time_remaining = move_toward(time_remaining, 0.0, dt)
