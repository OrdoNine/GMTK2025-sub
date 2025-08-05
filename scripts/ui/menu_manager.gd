extends Control
class_name UiMenuManager

var current_menu: Control = null
var _menu_stack: Array[Control] = []

func switch_to_menu(menu: Control) -> void:
	if current_menu:
		_menu_stack.push_back(current_menu)
		current_menu.visible = false
	
	menu.visible = true
	current_menu = menu

func go_back() -> void:
	if _menu_stack.is_empty():
		push_error("attempt to call UiMenuManager.go_back() when menu stack is empty")
		return
	
	var new_menu: Control = _menu_stack.pop_back()
	
	if current_menu:
		current_menu.visible = false
	
	new_menu.visible = true
	current_menu = new_menu