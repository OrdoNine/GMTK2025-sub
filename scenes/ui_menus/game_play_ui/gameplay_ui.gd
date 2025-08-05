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
	
	if stamina_points >= 5:
		%BombDisplayIcon.modulate = can_use_color
	else:
		%BombDisplayIcon.modulate = cannot_use_color
	
	if stamina_points >= 6:
		%BoosterDisplayIcon.modulate = can_use_color
		%SpringDisplayIcon.modulate = can_use_color
	else:
		%BoosterDisplayIcon.modulate = cannot_use_color
		%SpringDisplayIcon.modulate = cannot_use_color
	
	if stamina_points >= 8:
		%BridgeDisplayIcon.modulate = can_use_color
	else:
		%BridgeDisplayIcon.modulate = cannot_use_color
