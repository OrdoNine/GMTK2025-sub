extends Button
class_name AudibleButton

static var click_player: AudioStreamPlayer = null
static var select_player: AudioStreamPlayer = null

func _ready():
	if click_player == null:
		click_player = AudioStreamPlayer.new()
		click_player.name = "UIClickSoundPlayer"
		click_player.stream = load("res://assets/sounds/click.wav")
		click_player.volume_linear = 0.5
		Global.add_child(click_player) # parasitic
		
	if select_player == null:
		select_player = AudioStreamPlayer.new()
		select_player.name = "UISelectSoundPlayer"
		select_player.stream = load("res://assets/sounds/select.wav")
		select_player.volume_linear = 0.5
		Global.add_child(select_player) # parasitic

func _pressed() -> void:
	click_player.play()