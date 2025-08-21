extends RigidBody2D

const EXPANSION_WAIT := 0.2
const PLACEMENT_BLOCK := Vector2i(3, 0)
const MAX_BRIDGE_RADIUS := 5

var left_active: bool = false
var right_active: bool = false
var _pos_left: Vector2
var _pos_right: Vector2
var _left_dist := 1
var _right_dist := 1
var _tilemap: TileMapLayer
var _expansion_wait := 0.0
var _has_been_activated := false

var active : bool : 
	get :
		return left_active or right_active

func _ready():
	_tilemap = get_node("../Map")

func activate() -> void:
	_has_been_activated = true
	# i want the bridge maker to be placed directly below the player
	# and aligned to the tilemap grid
	var player_height := _tilemap.tile_set.tile_size.y # assumed player height
	var bottom := global_position + Vector2.DOWN * (player_height + 0.01)
	var start = _tilemap.local_to_map(_tilemap.to_local(bottom))
	global_position = _tilemap.to_global(_tilemap.map_to_local(start))
	
	# place initial block
	if _tilemap.get_cell_source_id(start) == -1:
		_tilemap.set_cell(start, 1, PLACEMENT_BLOCK)
		
		left_active = true
		right_active = true
		_pos_left = start + Vector2i.LEFT
		_pos_right = start + Vector2i.RIGHT
		
		$Sound.pitch_scale = 1.0
		$Sound.play()
		
		_expansion_wait = EXPANSION_WAIT

func deactivate() -> void:
	left_active = false
	right_active = false
	
func is_active():
	return active

func _physics_process(delta: float) -> void:
	if not _has_been_activated:
		return
	
	if not active or Global.get_game().stamina_points < 2:
		queue_free()
		return
	
	_expansion_wait -= delta
	if _expansion_wait <= 0.0:
		_expansion_wait = EXPANSION_WAIT
		
		if left_active:
			if _tilemap.get_cell_source_id(_pos_left) != -1:
				left_active = false
			else:
				_tilemap.set_cell(_pos_left, 1, PLACEMENT_BLOCK)
				_pos_left.x -= 1
				_left_dist += 1
				Global.get_game().stamina_points -= 1
		
		if right_active:
			if _tilemap.get_cell_source_id(_pos_right) != -1:
				right_active = false
			else:
				_tilemap.set_cell(_pos_right, 1, PLACEMENT_BLOCK)
				_pos_right.x += 1
				_right_dist += 1
				Global.get_game().stamina_points -= 1
		
		if _left_dist > MAX_BRIDGE_RADIUS:
			left_active = false
			
		if _right_dist > MAX_BRIDGE_RADIUS:
			right_active = false
			
		var dist = max(_left_dist, _right_dist)
		$Sound.pitch_scale = 1.0 + dist * 0.1
		$Sound.play()
