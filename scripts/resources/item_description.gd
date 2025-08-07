extends Resource
class_name ItemDescription

@export var id := "unnamed"
@export var name := "Unnamed Item"
@export var cost := 5
@export var immediate := false
@export var only_when_airborne := false
@export var item_scene: PackedScene

func _init(
		p_id: String = "unnamed",
		p_name: String = "Unnamed Item",
		p_cost: int = 5,
		p_immediate: bool = false,
		p_only_when_airborne: bool = false,
		p_item_scene: PackedScene = null):
	id = p_id
	name = p_name
	cost = p_cost
	immediate = p_immediate
	only_when_airborne = p_only_when_airborne
	item_scene = p_item_scene
