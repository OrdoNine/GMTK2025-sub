extends Resource
class_name ItemTable

@export var items: Array[ItemDescription]

func _init(p_items: Array[ItemDescription] = []):
	items = p_items

func find_item(id: String):
	for item in items:
		if item.id == id:
			return item
	return null
