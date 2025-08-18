extends Node2D

var debug_help : bool = false
# TBQH, a hash set
var keys_to_toggle_debug : Dictionary[Key, bool] = {
	KEY_CTRL: false,
	KEY_QUOTELEFT: false
}
# TBQH, a hash set
var pressed_keys : Dictionary[Key, bool] = {}

func has_debug_freedom() -> bool:
	return debug_help and OS.is_debug_build()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("game_pause") and not %WarmupMenu.visible:
		var root := get_tree()
		
		if root.paused:
			root.paused = false
			%PauseUI.visible = false
		else:
			root.paused = true
			%PauseUI.visible = true


# Just toggles debug_help for now
func _process(dt: float):
	if pressed_keys.size() == keys_to_toggle_debug.size():
		for key in keys_to_toggle_debug:
			if not Input.is_physical_key_pressed(key):
				pressed_keys.erase(key)
		return
	
	for key in keys_to_toggle_debug:
		if not Input.is_physical_key_pressed(key):
			pressed_keys.erase(key)
			return
		else:
			pressed_keys[key] = false
	
	debug_help = not debug_help


func _exit_tree() -> void:
	# The only way possible to currently call this is by going to main menu.
	# And thus, we must unpause it for the main menu scene to work.
	get_tree().paused = false


func _ready() -> void:
	%PauseUI.visible = false
	%WarmupMenu.visible = false
