extends Line2D
class_name MaceChain

@export var mace : Node2D #the object that is chained to this.
@export var tilemap : TileMapLayer  #the tilemap as a reference for path pixelization. doesnt pixelize if null.
@export var target : Node2D

signal knocked_back()
signal completed_loop()

var mace_speed := 2.0 
var mace_accel := 0.5 
var mace_vel := Vector2()
var mace_range := 100.0

var reversed := false #whether the mace will move backwards 
var advance := false
var loop_dist := 0.0
var knockback := 0.0 #how much reversed will last.

var curve := Curve2D.new()
var completion := 0.0 #how much of the curve we completed (distance)
var loops := 0 #how many times have we completed the same loop 

func _ready() -> void:
	Global.gamemode_changed.connect(_on_gamemode_changed);
	changePattern(mace_range)

func _on_gamemode_changed(from_state: Global.GameState, to_state: Global.GameState):
	if from_state != Global.GameState.PAUSE and to_state == Global.GameState.GAMEPLAY:
		game_reset();

func game_reset():
	push_error("Mace chain has no reset code!");

func _process(delta: float) -> void:
	if mace:
		if completion >= loop_dist:
			completion = 0
			loops += 1
			emit_signal("completed_loop")
			
		mace_vel.x = move_toward(mace_vel.x, mace_speed, delta*mace_accel)
		mace_vel.y = move_toward(mace_vel.x, mace_speed, delta*mace_accel)
		
		completion += sqrt(pow(mace_vel.x,2) + pow(mace_vel.y,2))
		mace.global_position = curve.sample_baked(completion)

func _on_completed_loop() -> void:
	var new_rot = [0,45,90,-45,-90].pick_random()
	if target:
		advance = mace.global_position.distance_squared_to(target.global_position) > mace_range * 200
		new_rot = rad_to_deg(mace.global_position.angle_to_point(target.global_position))
	changePattern(mace_range, new_rot)

func changePattern(range : float = 1, rot_deg : float = 0, idx : int = -1):
	#negative index picks randomly from available moves
	
	if Global.maceAttackPatterns: 
		if idx < 0:
			idx = randi_range(0, Global.maceAttackPatterns.keys().size() - 1)
		var next_move = Global.maceAttackPatterns.keys()[idx]
		var pattern = Global.maceAttackPatterns[next_move]["points"]
		
		curve.clear_points()
		
		var rot_rad = deg_to_rad(rot_deg - Global.maceAttackPatterns[next_move]["rotation"])
		var start = mace.global_position
		if tilemap:
			start = tilemap.map_to_local( tilemap.local_to_map(mace.global_position) )
		
		for i in range(pattern.size()):
			curve.add_point(
							start + Vector2(pattern[i][0][0], pattern[i][0][1]).rotated(rot_rad) * range, 
							Vector2(pattern[i][1][0], pattern[i][1][1]).rotated(rot_rad) * range,
							Vector2(pattern[i][2][0], pattern[i][2][1]).rotated(rot_rad) * range
							)
		
		curve.tessellate()
		points = curve.get_baked_points()
		
		loop_dist = curve.get_baked_length()
		if advance:
			loop_dist *= Global.maceAttackPatterns[next_move]["advance"]

func reverse(kb : float):
	if kb > 0:
		reversed = true
		knockback = kb
		emit_signal("knocked_back")
