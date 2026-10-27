extends CanvasLayer

signal sell_requested
signal buy_requested(seed_data: SeedData)
signal closed

@export var seed_list: Array[SeedData]
@onready var info: Label = %Info
@onready var seed_box: GridContainer = %SeedBox
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton
const SEED_SLOT := preload("res://seeds/SeedSlot.tscn")

func _ready() -> void:
	visible = false
	sell_button.pressed.connect(func(): sell_requested.emit())
	close_button.pressed.connect(close)
	for s in seed_list:
			var slot := SEED_SLOT.instantiate()
			seed_box.add_child(slot)      # add first
			slot.setup(s)                 # then fill
			slot.pressed.connect(func(): buy_requested.emit(s))

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func update_info(text: String) -> void:
	info.text = text
