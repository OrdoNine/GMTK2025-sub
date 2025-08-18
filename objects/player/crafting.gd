extends Node2D

## An item that is active for further input to increase it's power or something.[br]
## Like for bridge maker, holding it for longer makes it wider.
var active_item: Node2D = null

## ID of the last item used.
var item_id: StringName = ""

func is_item_active_or_crafting() -> bool:
	return is_crafting() or is_item_active()

func is_crafting() -> bool:
	return crafted_item_prefab != null

func is_item_active() -> bool:
	return active_item != null

var enabled: bool :
	set(new):
		if new != enabled:
			enabled = new
			if not enabled:
				deactivate_active_item_if_any()
				deactivate_item_craft_if_any()

@export var item_table: ItemTable

var _active_item_key := KEY_NONE

var crafted_item_cost : int;
var crafted_item_prefab : PackedScene = null;

var _crafting_timer := PollTimer.new(0.5)

func _ready() -> void:
	enabled = true;
	reset()

func reset() -> void:
	Global.stop(Global.Sound.CRAFTING)
	Global.stop(Global.Sound.PLACE)
	_crafting_timer.deactivate()
	crafted_item_prefab = null
	active_item = null
	_active_item_key = KEY_NONE

func finish_item_craft():
	Global.play(Global.Sound.PLACE)
	var inst: Node2D = crafted_item_prefab.instantiate()
	inst.global_position = global_position
	Global.get_game().add_child(inst)
	inst.activate()
	
	Global.get_game().stamina_points -= crafted_item_cost if not OS.is_debug_build() else 0
	crafted_item_prefab = null
	
	# if active state is not false after activate() was called,
	# then this is an item that whose crafting button can be held
	# down further to increase the power of the tool.
	if inst.is_active():
		active_item = inst
	else:
		_active_item_key = KEY_NONE

func deactivate_item_craft_if_any():
	if crafted_item_prefab != null:
		Global.stop(Global.Sound.PLACE)
		Global.stop(Global.Sound.CRAFTING)
		_crafting_timer.deactivate()
		crafted_item_prefab = null
		_active_item_key = KEY_NONE

func deactivate_active_item_if_any():
	if active_item != null:
		active_item.deactivate()
		active_item = null

func meets_stamina_requirement(c: int) -> bool:
	return Global.get_game().stamina_points >= c

func is_player_on_floor() -> bool:
	var player: CharacterBody2D = get_parent()
	if player.is_on_floor():
		return true
	
	# check also the the tile below the tile that the player's center is occupied in
	# is a floor tile. this is so that the bridge item can't place the bridge inside
	# the ground when you are very close to the ground, but not actually on it.
	var _tilemap: TileMapLayer = Global.get_game().get_node("Map")
	var player_tilemap_pos = _tilemap.local_to_map(_tilemap.to_local(player.global_position))
	return _tilemap.get_cell_source_id(player_tilemap_pos + Vector2i(0, 1)) != -1

func trigger_item_craft(index: int) -> bool:
	var item_desc := item_table.items[index]
	if item_desc == null:
		push_error("index out of range of item table")
		return false
	
	if not meets_stamina_requirement(item_desc.cost) and not Global.get_game_process().has_debug_freedom():
		return false
	
	if item_desc.only_when_airborne and is_player_on_floor():
		return false
	
	if item_desc.immediate:
		crafted_item_cost = item_desc.cost
		crafted_item_prefab = item_desc.item_scene
		item_id = item_desc.id
		
		finish_item_craft()
		return true;
	
	Global.play(Global.Sound.CRAFTING)
	_crafting_timer.activate()
	crafted_item_cost = item_desc.cost
	crafted_item_prefab = item_desc.item_scene
	item_id = item_desc.id
	
	return true

# this is for crafting stuff
func _input(event: InputEvent) -> void:
	if not enabled: return
	if not event is InputEventKey or event.is_echo(): return
	
	if event.pressed and active_item == null and crafted_item_prefab == null:
		var item_index_to_craft := \
			[KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
	
		if item_index_to_craft != -1 and trigger_item_craft(item_index_to_craft):
			_active_item_key = event.keycode
	elif event.is_released() and event.keycode == _active_item_key:
		deactivate_active_item_if_any()
		deactivate_item_craft_if_any()

func _physics_process(delta: float) -> void:
	# if bridge maker is no longer active, then deactivate the tracking of it
	if active_item != null and not active_item.active:
		active_item = null
	
	_crafting_timer.update(delta)
	# update item craft progress
	if crafted_item_prefab != null:
		if not _crafting_timer.is_active:
			finish_item_craft()
