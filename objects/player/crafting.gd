extends Node2D

var item_craft_progress = null
var active_item: Node2D = null

var is_active_or_crafting : bool :
	get:
		return item_craft_progress != null or active_item != null

var enabled: bool :
	get: return _enabled
	set(new):
		if new != _enabled:
			_enabled = new
			if not _enabled:
				deactivate_active_item()
				deactivate_item_craft()

@export var item_table: ItemTable

var _active_item_key := KEY_NONE
var _enabled := true

func _ready() -> void:
	reset()

func reset() -> void:
	SoundManager.stop(SoundManager.Sound.CRAFTING)
	SoundManager.stop(SoundManager.Sound.PLACE)
	item_craft_progress = null
	active_item = null
	_active_item_key = KEY_NONE

func finish_item_craft():
	SoundManager.play(SoundManager.Sound.PLACE)
	var inst: Node2D = item_craft_progress.prefab.instantiate()
	inst.global_position = global_position
	Global.get_game().add_child(inst)
	inst.activate()
	Global.get_game().stamina_points -= item_craft_progress.points
	item_craft_progress = null
	
	# if active state is not false after activate() was called,
	# then this is an item that whose crafting button can be held
	# down further to increase the power of the tool.
	if inst.is_active():
		active_item = inst
	else:
		_active_item_key = KEY_NONE

func deactivate_item_craft():
	item_craft_progress = null
	_active_item_key = KEY_NONE
	
	SoundManager.stop(SoundManager.Sound.PLACE)
	SoundManager.stop(SoundManager.Sound.CRAFTING)
	
func deactivate_active_item():
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
	
	if not meets_stamina_requirement(item_desc.cost):
		return false
	
	if item_desc.only_when_airborne and is_player_on_floor():
		return false
	
	# really this is just so the player doesn't fall through the bridge
	# immediately after crafting it
	get_parent().velocity.y = 0.0
	
	if item_desc.immediate:
		item_craft_progress = {
			time_remaining = 0,
			wait_length = 0,
			points = item_desc.cost,
			prefab = item_desc.item_scene
		}
		
		finish_item_craft()
	else:
		SoundManager.play(SoundManager.Sound.CRAFTING)
		item_craft_progress = {
			time_remaining = 0.5,
			wait_length = 0.5,
			points = item_desc.cost,
			prefab = item_desc.item_scene
		}
	
	return true

# this is for crafting stuff
func _input(event: InputEvent) -> void:
	if not enabled: return
	
	var player: CharacterBody2D = get_parent()
	
	if event is InputEventKey and not event.is_echo():
		if event.pressed and active_item == null and item_craft_progress == null:
			var item_index_to_craft := \
				[KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
		
			if item_index_to_craft != -1 and trigger_item_craft(item_index_to_craft):
				_active_item_key = event.keycode
			# 2 key: bridge marker (if airborne)
			#elif event.pressed and event.keycode == KEY_2 and not player.is_on_floor() and meets_stamina_requirement(8):
				## place bridge maker if not on floor
#22				var inst: Node2D = item_table.find_item("bridge").instantiate()
				#
				## place bridge maker on the center of the cell below the player
				#var tilemap: TileMapLayer = Global.get_game().get_node("Map")
				#var player_bottom: Vector2i = global_position + Vector2.DOWN * player.get_node("CollisionShape2D").shape.size.y / 2.0
				#var player_bottom_tile_pos := tilemap.local_to_map(tilemap.to_local(player_bottom))
				#var bridge_maker_placement_tile_pos := player_bottom_tile_pos + Vector2i(0, 1)
				#inst.global_position = tilemap.to_global(tilemap.map_to_local(bridge_maker_placement_tile_pos))
				#
				#Global.get_game().add_child(inst)
				#inst.activate()
				#Global.get_game().stamina_points -= 8
				#
				#active_item = inst
				#_active_item_key = event.
		
		elif event.is_released() and event.keycode == _active_item_key:
			if active_item != null:
				deactivate_active_item()
				
			if item_craft_progress != null:
				deactivate_item_craft()

func _physics_process(delta: float) -> void:
	# if bridge maker is no longer active, then deactivate the tracking of it
	if active_item != null and not active_item.active:
		active_item = null
	
	# update item craft progress
	if item_craft_progress != null:
		item_craft_progress.time_remaining -= delta
		if item_craft_progress.time_remaining <= 0.0:
			finish_item_craft()
