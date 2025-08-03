extends AnimatedSprite2D

@export var label_text: String :
	set(new_label):
		label_text = new_label;
		$Label.text = new_label;


signal button_pressed;

func _on_button_pressed() -> void:
	print(label_text, " pressed!")
	button_pressed.emit();

func _on_button_button_down() -> void:
	self.animation = "clicked";

func _on_button_button_up() -> void:
	self.animation = "unclicked"
