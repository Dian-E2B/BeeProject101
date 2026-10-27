@tool
extends Button

signal clicked(seed_data: SeedData)

@export var seed_data: SeedData:
	set(value):
		seed_data = value
		if is_node_ready():
			_update_visuals()

@onready var icon_rect: TextureRect = %Icon
@onready var price_label: Label = %PriceLabel

func _ready() -> void:
	_update_visuals()
	if not Engine.is_editor_hint():
		pressed.connect(func(): clicked.emit(seed_data))

func _update_visuals() -> void:
	if seed_data == null:
		return
	price_label.text = "%d" % seed_data.price
