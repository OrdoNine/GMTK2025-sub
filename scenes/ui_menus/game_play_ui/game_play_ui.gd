extends Control

var stamina_points: int = 0;
var time_remaining: float = 0.0;
var round_number: int = 0

const can_use_color := Color.CORNSILK;
const cannot_use_color := Color.DARK_SLATE_GRAY;

func _ready() -> void:
	Global.ui_update.connect(_on_ui_update);

func _on_ui_update(new_time_remaining: float, new_round_number: int):
	time_remaining = new_time_remaining;
	round_number = new_round_number;

func _process(_delta: float) -> void:
	%RoundNumber.text = "Round: " + str(round_number)
	%Slimes.text = "x" + str(stamina_points)
	%Lives.text = "x" + str(Global.player_lives)
	
	if stamina_points >= 5:
		%CanCreateSlimeBomb.modulate = can_use_color;
	else:
		%CanCreateSlimeBomb.modulate = cannot_use_color;
	if stamina_points >= 6:
		%CanCreateBooster.modulate = can_use_color;
		%CanCreateSpring.modulate = can_use_color;
	else:
		%CanCreateSpring.modulate = cannot_use_color;
		%CanCreateBooster.modulate = cannot_use_color;
	if stamina_points >= 8:
		%CanCreateMidAirBridge.modulate = can_use_color;
	else:
		%CanCreateMidAirBridge.modulate = cannot_use_color;
