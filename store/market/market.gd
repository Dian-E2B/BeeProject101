extends CanvasLayer

signal sell_requested
signal buy_requested(seed_data: SeedData)
signal closed
@export var seed_list: Array[SeedData]
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton
@onready var info_label: Label = %Info
const SEED_SLOT:= preload("res://seeds/SeedSlot.tscn")
@onready var seed_box: GridContainer = %SeedBox

func _ready() -> void:
	visible = false
	sell_button.pressed.connect(func(): sell_requested.emit())
	close_button.pressed.connect(close)
	for s in seed_list:
		var slot = SEED_SLOT.instantiate()
		seed_box.add_child(slot)
		slot.setup(s)                # then fill
		slot.pressed.connect(func(): buy_requested.emit(s))

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func update_info(crops_held: int, crops_value: int, planting: String) -> void:
	info_label.text = "Crops: %d\nValue: %d\nPlanting: %s" % [crops_held, crops_value, planting]
