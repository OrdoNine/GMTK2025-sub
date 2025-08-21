extends Control

const can_use_color := Color.CORNSILK;
const cannot_use_color := Color.DARK_SLATE_GRAY;

func _process(_delta: float) -> void:
	var game := Global.get_game()
	if game == null:
		push_error("Game is not active")
		return
	
	var round_number: int = game.round_number
	var stamina_points: int = game.stamina_points
	var player_lives: int = game.player_lives
	
	%RoundNumberLabel.text = "Round: " + str(round_number)
	%SlimeCountLabel.text = "x" + str(stamina_points)
	%LifeCountLabel.text = "x" + str(player_lives)
	
	
	if stamina_points >= Global.get_item_table().find_item("bomb").cost:
		%BombDisplayIcon.modulate = can_use_color
	else:
		%BombDisplayIcon.modulate = cannot_use_color
	
	if stamina_points >= Global.get_item_table().find_item("booster").cost:
		%BoosterDisplayIcon.modulate = can_use_color
	else:
		%BoosterDisplayIcon.modulate = cannot_use_color
	
	if stamina_points >= Global.get_item_table().find_item("spring").cost:
		%SpringDisplayIcon.modulate = can_use_color
	else:
		%SpringDisplayIcon.modulate = cannot_use_color
	
	if stamina_points >= Global.get_item_table().find_item("bridge").cost:
		%BridgeDisplayIcon.modulate = can_use_color
	else:
		%BridgeDisplayIcon.modulate = cannot_use_color
