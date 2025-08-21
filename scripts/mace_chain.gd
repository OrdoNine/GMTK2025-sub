extends Line2D
class_name MaceChain

const DEFAULT_RANGE := 100.0
const MID_RANGE := 200.0
const RANGE_TO_WORLD := 100.0 
const INITIAL_MACE_SPEED := 1.5
const MACE_SPEED_INCREASE := 0.31
const INITIAL_MACE_ACCEL := 0.67
const MACE_ACCEL_INCREASE := 0.01

@export var mace : Node2D #the object that is chained to this.
@export var tilemap : TileMapLayer  #the tilemap as a reference for path pixelization. doesnt pixelize if null.
@export var target : Node2D

signal knocked_back()
signal completed_loop()

var mace_speed := 2.1
var mace_accel := 0.67
var mace_vel := 0.0 
var mace_range := DEFAULT_RANGE
var mace_start := Vector2()

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
	mace_start = mace.global_position
	Global.get_game().round_started.connect(game_reset)
	game_reset(true)

func game_reset(_new_round: bool):
	var game := Global.get_game()
	mace_speed = INITIAL_MACE_SPEED + (game.round_number - 1) * MACE_SPEED_INCREASE
	mace_accel = INITIAL_MACE_ACCEL + (game.round_number - 1) * MACE_ACCEL_INCREASE

	mace.global_position = mace_start
	mace_vel = 0.0
	mace_range = DEFAULT_RANGE
	current_loop = true
	reversed = false
	knockback = 0.0
	completion = 0.0
	loops = 0
	cur_pattern = {"move" : null, "position" : Vector2(), "rotation" : 0, "advanced" : false} 
	last_pattern = {"move" : null, "position" : Vector2(), "rotation" : 0, "advanced": false} 
	emit_signal("completed_loop")

var disabled : bool = false

func _physics_process(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_1) and Input.is_physical_key_pressed(KEY_CTRL):
		disabled = not disabled

	if disabled and Global.get_game_process().has_debug_freedom():
		return

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
			mace_vel = move_toward(mace_vel, -mace_speed, knockback/mace_accel * delta)
			knockback = move_toward(knockback, 0, mace_accel)
		else:
			if reversed:
				reversed = false
			mace_vel = move_toward(mace_vel, mace_speed, mace_accel * delta)
		
		var dist = mace_vel
		completion += dist * delta * 60.0
		
		mace.global_position = curve.sample_baked(completion)

func _on_completed_loop() -> void:
	if current_loop:
		last_pattern = cur_pattern.duplicate(true)
	else:
		current_loop = true
	
	#settings for the next targeting move
	var new_rot = [0,45,90,-45,-90].pick_random()
	var new_pattern = ""
	var advance = false
	
	if target:
		var tolerance = 10.0
		# var actual_dist = mace.global_position.distance_to(target.global_position)
		var actual_range = mace.global_position.distance_to(target.global_position)
		if actual_range <= DEFAULT_RANGE:
			mace_range = actual_range
		elif actual_range <= MID_RANGE + tolerance:
			mace_range = DEFAULT_RANGE
			advance = true
		else:
			mace_range = actual_range - MID_RANGE
			new_pattern = "line"
		 
		new_rot = rad_to_deg(mace.global_position.angle_to_point(target.global_position))
	
	if loop_dist > 0:
		var p0 = curve.sample_baked(loop_dist - 1.0)
		var p1 = curve.sample_baked(loop_dist)
		var last_tan = (p1 - p0).normalized().angle()
	
		if angle_difference(last_tan, deg_to_rad(new_rot)) > PI/6:
			reverse(6.0)
	changePattern(mace_range, new_rot, new_pattern, advance)

func changePattern(range : float = 1, rot_deg : float = 0, move_name : String = "", advance : bool = false, pos_override : Vector2 = Vector2()):
	#unset move_name will pick a random move
	
	if Global.maceAttackPatterns: 
		curve.clear_points()
		
		#select pattern
		move_name = move_name.to_lower()
		var valid_move = move_name.is_empty() or Global.maceAttackPatterns.has(move_name) 
		if move_name.is_empty() or not valid_move:
			if not valid_move:
				printerr("Error: Given undefined (", move_name , ") pattern. Selecting random instead.")
				
			var idx = randi_range(1, Global.maceAttackPatterns.keys().size() - 1)
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
		#get the distance required to complete the loop
		loop_dist = curve.get_baked_length()
		var loop_perc = 1
		if advance:
			loop_perc = Global.maceAttackPatterns[move_name]["advance"]
		
		loop_dist *= loop_perc
		points = curve.get_baked_points().slice(0, (len(curve.get_baked_points()) -1) * loop_perc)
		
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
