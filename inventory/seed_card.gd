extends Button

@onready var seed_icon: TextureRect = $IconRect
@onready var label: Label = $CountLabel

func setup(seed_data, count: int) -> void:
	seed_icon.texture = seed_data.icon
	label.text = str(count)
