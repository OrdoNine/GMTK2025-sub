extends Node
class_name Globals

## Timers used in Player
enum TimerType {
	COYOTE,
	INVINCIBILITY,
	STUN,
	JUMP_PROGRESS,
	CRAFTING
}

## Activate values are which will cause the timer to update.
## They will be considered deactivated at 0.
const timer_to_activate_values : Dictionary[TimerType, float] = {
	TimerType.COYOTE: 0.13,
	TimerType.INVINCIBILITY: 2.0,
	TimerType.STUN: 2.0,
	TimerType.JUMP_PROGRESS: 1.0,
	TimerType.CRAFTING: 0.5,
}

## A dictionary of current timer times.
var timer_to_current_value : Dictionary[TimerType, float];

## Get current time of a timer type.[br]
## If timer doesn't exists, the timer will be added and will be set to the deactivated values.
func get_time_of(timer_type: TimerType) -> float:
	# If we have it in the dictionary, we return it.
	if timer_to_current_value.has(timer_type):
		return timer_to_current_value[timer_type]

	# Or we set it to the deactivated value!
	timer_to_current_value[timer_type] = 0
	return 0

func get_activation_time_of(timer_type: TimerType) -> float:
	return timer_to_activate_values[timer_type]

## Returns if the timer is active.
func is_timer_active(timer_type: TimerType) -> bool:
	return get_time_of(timer_type) != 0

## Sets the timer to the active value.
func activate_timer(timer_type: TimerType) -> void:
	timer_to_current_value[timer_type] = get_activation_time_of(timer_type)

## Sets the timer to the deactive value, i.e., 0.
func deactivate_timer(timer_type: TimerType) -> void:
	timer_to_current_value[timer_type] = 0

## Updates the timer by the delta amount.
func update_timer(timer_type: TimerType, delta_time: float) -> void:
	timer_to_current_value[timer_type] = move_toward(get_time_of(timer_type), 0, delta_time);

const PLAYER_TIMERS = [TimerType.COYOTE, TimerType.INVINCIBILITY, TimerType.STUN, TimerType.JUMP_PROGRESS]

var maceAttackPatterns : Dictionary

func _ready() -> void:
	maceAttackPatterns = read_JSON("res://resources/components/macepatterns.json")

func read_JSON(path):
	var json = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json)
	if data:
		return data
	push_error("COULD NOT READ " + str(path) + ". Please check the file for any errors.")
	return
	
func get_game() -> Game:
	return get_tree().get_first_node_in_group("game")
