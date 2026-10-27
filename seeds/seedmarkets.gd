extends CanvasLayer
signal opened
signal closed
@onready var item_grid: HBoxContainer = $HBoxContainer

const SEED_OBJECT := preload("res://seeds/seed_object.tscn")  
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false;
	# for i in range(4):
	# 	add_seed_to_market("Seed #" + str(i + 1))

func add_seed_to_market(seed_name: String) -> void:
	var new_seed := SEED_OBJECT.instantiate()
	item_grid.add_child(new_seed) 
	
func open() -> void:
	visible = true
	opened.emit()

func close() -> void:
	visible = false
	closed.emit()
