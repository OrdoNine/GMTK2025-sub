extends Line2D
class_name MaceChain

@export var mace := Node2D #the object that is chained to this

signal knocked_back()
signal completed_loop()

var mace_speed := 5.0 
var mace_accel := 0.5 
var mace_vel := Vector2()
var mace_range := 100.0

var reversed := false #whether the mace will move backwards 
var knockback := 0.0 #how much reversed will last.

var curve := Curve2D.new()
var completion := 0.0 #how much of the curve we completed (distance)
var loops := 0 #how many times have we completed the same loop 

func _ready() -> void:
	changePattern(randi_range(0,1), mace_range)
	print("something")

func changePattern(idx : int = 0, range : float = 1):
	if Global.maceAttackPatterns:
		var next_move = Global.maceAttackPatterns.keys()[idx]
		var pattern = Global.maceAttackPatterns[next_move]["points"]
		curve.clear_points()
		
		for i in range(pattern.size()):
			curve.add_point(
							global_position + Vector2(pattern[i][0][0], pattern[i][0][1]) * range, 
							Vector2(pattern[i][1][0], pattern[i][1][1]) * range,
							global_position + Vector2(pattern[i][2][0], pattern[i][2][1]) * range
							)
		points = curve.get_baked_points()

func reverse(kb : float):
	if kb > 0:
		reversed = true
		knockback = kb
		emit_signal("knocked_back")

func _process(delta: float) -> void:
	if mace:
		if completion >= curve.get_baked_length():
			completion = 0
			loops += 1
			emit_signal("completed_loop")
			
		mace_vel.x = move_toward(mace_vel.x, mace_speed, delta*mace_accel)
		mace_vel.y = move_toward(mace_vel.x, mace_speed, delta*mace_accel)
		
		completion += sqrt(pow(mace_vel.x,2) + pow(mace_vel.y,2))
		mace.global_position = curve.sample_baked(completion)

func _on_completed_loop() -> void:
	changePattern(randi_range(0,1), mace_range)
