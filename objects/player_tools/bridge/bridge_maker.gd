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

var active : bool : 
	get :
		return left_active or right_active

func _ready():
	_tilemap = get_node("../Map")

func activate() -> void:
	var start = _tilemap.local_to_map(_tilemap.to_local(global_position))
	
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

func _physics_process(delta: float) -> void:
	if not active: return
	
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
		
		if right_active:
			if _tilemap.get_cell_source_id(_pos_right) != -1:
				right_active = false
			else:
				_tilemap.set_cell(_pos_right, 1, PLACEMENT_BLOCK)
				_pos_right.x += 1
				_right_dist += 1
		
		if _left_dist > MAX_BRIDGE_RADIUS:
			left_active = false
			
		if _right_dist > MAX_BRIDGE_RADIUS:
			right_active = false
			
		var dist = max(_left_dist, _right_dist)
		$Sound.pitch_scale = 1.0 + dist * 0.1
		$Sound.play()
