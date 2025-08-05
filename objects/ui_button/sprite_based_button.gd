extends AnimatedSprite2D

static var click_player: AudioStreamPlayer = null
static var select_player: AudioStreamPlayer = null

@export var label_text: String :
	set(new_label):
		label_text = new_label
		$Label.text = new_label

signal button_pressed;
signal button_released;

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

func _on_button_pressed() -> void:
	click_player.play()
	button_pressed.emit()

func _on_button_button_down() -> void:
	animation = "clicked"

func _on_button_button_up() -> void:
	animation = "unclicked"
	modulate = Color(1.0, 1.0, 1.0)

func _on_button_mouse_entered() -> void:
	# select_player.play()
	modulate = Color(0.8, 0.8, 0.8)
	await get_tree().create_timer(0.1).timeout;
	button_released.emit()
	
func _on_button_mouse_exited() -> void:
	modulate = Color(1.0, 1.0, 1.0)
