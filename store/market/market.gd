extends CanvasLayer

signal sell_requested
signal buy_requested(seed_data: SeedData)
signal closed

@export var seed_list: Array[SeedData]

@onready var info: Label = $Panel/VBoxContainer/Info
@onready var seed_box: VBoxContainer = $Panel/VBoxContainer/SeedBox

func _ready() -> void:
	visible = false
	$Panel/VBoxContainer/SellButton.pressed.connect(func(): sell_requested.emit())
	$Panel/VBoxContainer/CloseButton.pressed.connect(close)
	for s in seed_list:
		var b := Button.new()
		b.text = "%s Seed - %d honey" % [s.rarity, s.price]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): buy_requested.emit(s))
		seed_box.add_child(b)

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func update_info(text: String) -> void:
	info.text = text
