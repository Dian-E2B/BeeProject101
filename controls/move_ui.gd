extends CanvasLayer

signal inventory_pressed

func _ready():
	$Interact.button_down.connect(func(): Input.action_press("interact"))
	$Interact.button_up.connect(func(): Input.action_release("interact"))
	$Inventory.pressed.connect(func(): inventory_pressed.emit())
