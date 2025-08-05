# this class is used to manage menus. Duh!
# it assumes that each menu is a child of this MenuManager node.
#
# example structure:
#	MainMenuManager (UiMenuManager)
#		ControlsMenu (Control)
#		CreditsMenu (Control)
#		MainMenu (Control)
#
# MainMenu has a Credits button, which when pressed will call switch_to_menu($CreditsMenu).
# MainMenu also has a Controls button, which when pressed will call switch_to_menu($ControlsMenu)
# both the credits and controls menu each have their respective back button, which when pressed will
# call the menu manager's go_back() method.

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