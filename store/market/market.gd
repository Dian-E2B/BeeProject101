extends CanvasLayer

signal convert_requested          # was: sell_requested
signal buy_requested(seed_data: SeedData)
signal closed

@export var seed_list: Array[SeedData]

@onready var info: Label = $Panel/VBoxContainer/Info
@onready var seed_box: VBoxContainer = $Panel/VBoxContainer/SeedBox
#const SEED_CARD := preload("res://seeds/Seedcard.tscn") 

func _ready() -> void:
	visible = false
	$Panel/VBoxContainer/ConvertButton.pressed.connect(func(): convert_requested.emit())   # was: SellButton / sell_requested
	$Panel/VBoxContainer/CloseButton.pressed.connect(close)
	#for s in seed_list:
			#var card := SEED_CARD.instantiate()
			#seed_box.add_child(card)      # add first, so the @onready nodes exist
			#card.setup(s)                 # then fill in the data
			#card.focus_mode = Control.FOCUS_NONE
			#card.pressed.connect(func(): buy_requested.emit(s))

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func update_info(text: String) -> void:
	info.text = text
