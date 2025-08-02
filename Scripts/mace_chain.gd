extends Line2D
class_name MaceChain

@export var mace : Node2D #the object that is chained to this.
@export var tilemap : TileMapLayer  #the tilemap as a reference for path pixelization. doesnt pixelize if null.
@export var target : Node2D

signal knocked_back()
signal completed_loop()

var mace_speed := 2.0 
var mace_accel := 1.0
var mace_vel := Vector2()
var mace_range := 100.0

var reversed := false #whether the mace will move backwards 
var current_loop = true #whether the mace is following the current pattern
var cur_pattern := {"move" : null, "position" : Vector2(), "rotation" : 0, "advanced" : false} 
var last_pattern := {"move" : null, "position" : Vector2(), "rotation" : 0, "advanced": false} 
var knockback := 0.0 #how much reversed will last.

var loop_dist := 0.0

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
			
		if completion < 0:
			if current_loop and last_pattern.move:
				changePattern(mace_range, last_pattern.rotation, last_pattern.move, last_pattern.advanced, last_pattern.position)
				completion = loop_dist
				current_loop = false
			else:
				completion = 0
		
		if knockback > 0:
			mace_vel.x = move_toward(mace_vel.x, -mace_speed, knockback/mace_accel * delta)
		else:
			if reversed:
				print("stopped kno")
				reversed = false
			mace_vel.x = move_toward(mace_vel.x, mace_speed, mace_accel * delta)
		#mace_vel.y = move_toward(mace_vel.x, mace_speed, delta*mace_accel)
		
		var dist = mace_vel.x
		completion += dist
		if reversed:
			knockback = max(0, knockback - max(0, abs(dist)))
		
		mace.global_position = curve.sample_baked(completion)

func _on_completed_loop() -> void:
	if current_loop:
		last_pattern = cur_pattern.duplicate(true)
	else:
		current_loop = true
	
	var new_rot = [0,45,90,-45,-90].pick_random()
	var advance = false
	if target:
		advance = mace.global_position.distance_squared_to(target.global_position) > mace_range * 200
		new_rot = rad_to_deg(mace.global_position.angle_to_point(target.global_position))
	changePattern(mace_range, new_rot, "", advance)

func changePattern(range : float = 1, rot_deg : float = 0, move_name : String = "", advance : bool = false, pos_override : Vector2 = Vector2()):
	#unset move_name will pick a random move
	
	if Global.maceAttackPatterns: 
		curve.clear_points()
		
		#select pattern
		var valid_move = move_name.is_empty() or Global.maceAttackPatterns.has(move_name) 
		if move_name.is_empty() or not valid_move:
			if not valid_move:
				printerr("Error: Given undefined (", move_name , ") pattern. Selecting random instead.")
				
			var idx = randi_range(0, Global.maceAttackPatterns.keys().size() - 1)
			move_name = Global.maceAttackPatterns.keys()[idx]
		
		var pattern = Global.maceAttackPatterns[move_name]["points"]
		
		#initialize mace path
		var rot_rad = deg_to_rad(rot_deg - Global.maceAttackPatterns[move_name]["rotation"])
		var start = mace.global_position
		if pos_override:
			start = pos_override
		
		if tilemap:
			start = tilemap.map_to_local( tilemap.local_to_map( start ))
		
		#create pattern
		for i in range(pattern.size()):
			curve.add_point(
							start + Vector2(pattern[i][0][0], pattern[i][0][1]).rotated(rot_rad) * range, 
							Vector2(pattern[i][1][0], pattern[i][1][1]).rotated(rot_rad) * range,
							Vector2(pattern[i][2][0], pattern[i][2][1]).rotated(rot_rad) * range
							)
		
		curve.tessellate()
		points = curve.get_baked_points()
		
		#get the distance required to complete the loop
		loop_dist = curve.get_baked_length()
		if advance:
			loop_dist *= Global.maceAttackPatterns[move_name]["advance"]
		
		#save the current move settings (will not save if the position was overriden)
		if not pos_override:
			cur_pattern.move = move_name
			cur_pattern.position = start
			cur_pattern.rotation = rot_deg 
			cur_pattern.advanced = advance

func reverse(kb : float):
	if kb > 0:
		reversed = true
		knockback = kb
		emit_signal("knocked_back")
