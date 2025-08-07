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

const _prefab_bomb = preload("res://objects/player_tools/bomb/bomb.tscn")
const _prefab_inverse_bomb = preload("res://objects/player_tools/inverse_bomb/inverse_bomb.tscn")
const _prefab_bridge_maker = preload("res://objects/player_tools/bridge/bridge.tscn")
const _prefab_spring = preload("res://objects/player_tools/spring/spring.tscn")
const _prefab_horiz_spring = preload("res://objects/player_tools/horiz_spring/horiz_spring.tscn")

const _crafting_sound := preload("res://assets/sounds/crafting.wav")
const _place_sound := preload("res://assets/sounds/building_place.wav")
var _sound_player: AudioStreamPlayer

var _active_item_key := KEY_NONE
var _enabled := true

func _ready() -> void:
	_sound_player = AudioStreamPlayer.new()
	add_child(_sound_player)
	
	reset()

func reset() -> void:
	_sound_player.stop()
	item_craft_progress = null
	active_item = null
	_active_item_key = KEY_NONE

func play_sound(stream: AudioStream):
	_sound_player.stop()
	_sound_player.stream = stream
	_sound_player.play()

func begin_item_craft(time: float, points: int, prefab: PackedScene):
	play_sound(_crafting_sound)
	
	item_craft_progress = {
		time_remaining = time,
		wait_length = time,
		points = points,
		prefab = prefab
	}

func finish_item_craft():
	var inst: Node2D = item_craft_progress.prefab.instantiate()
	inst.global_position = global_position
	Global.get_game().add_child(inst)
	inst.activate()
	
	Global.get_game().stamina_points -= item_craft_progress.points
	
	item_craft_progress = null
	_active_item_key = KEY_NONE
	play_sound(_place_sound)

func deactivate_item_craft():
	item_craft_progress = null
	_active_item_key = KEY_NONE
	_sound_player.stop()
	
func deactivate_active_item():
	if active_item != null:
		active_item.deactivate()
		active_item = null

func meets_stamina_requirement(c: int) -> bool:
	return Global.get_game().stamina_points >= c

# this is for crafting stuff
func _input(event: InputEvent) -> void:
	if not enabled: return
	
	var player: CharacterBody2D = get_parent()
	
	if event is InputEventKey and not event.is_echo():
		if active_item == null and item_craft_progress == null:
			# 1 key: craft bomb
			if event.pressed and event.keycode == KEY_1 and meets_stamina_requirement(5):
				_active_item_key = event.keycode
				begin_item_craft(0.5, 5, _prefab_bomb)
				
			# slime bomb
			# if event.pressed and event.keycode == KEY_2 and meets_stamina_requirement(3):
			# 	_active_item_key = event.keycode
			# 	begin_item_craft(0.5, 3, _prefab_inverse_bomb)
				
			# 2 key: bridge marker (if airborne)
			elif event.pressed and event.keycode == KEY_2 and not player.is_on_floor() and meets_stamina_requirement(8):
				# place bridge maker if not on floor
				var inst: Node2D = _prefab_bridge_maker.instantiate()
				
				# place bridge maker on the center of the cell below the player
				var tilemap: TileMapLayer = Global.get_game().get_node("Map")
				var player_bottom: Vector2i = global_position + Vector2.DOWN * player.get_node("CollisionShape2D").shape.size.y / 2.0
				var player_bottom_tile_pos := tilemap.local_to_map(tilemap.to_local(player_bottom))
				var bridge_maker_placement_tile_pos := player_bottom_tile_pos + Vector2i(0, 1)
				inst.global_position = tilemap.to_global(tilemap.map_to_local(bridge_maker_placement_tile_pos))
				
				Global.get_game().add_child(inst)
				inst.activate()
				Global.get_game().stamina_points -= 8
				
				active_item = inst
				_active_item_key = event.keycode
			
			# 3 key: spring
			elif event.pressed and event.keycode == KEY_3 and meets_stamina_requirement(6):
				_active_item_key = event.keycode
				begin_item_craft(0.5, 6, _prefab_spring)
				
			# 4 key: horiz spring
			elif event.pressed and event.keycode == KEY_4 and meets_stamina_requirement(6):
				_active_item_key = event.keycode
				begin_item_craft(0.5, 6, _prefab_horiz_spring)
		
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
