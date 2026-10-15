extends CanvasLayer

func _ready():
	$Interact.button_down.connect(func(): Input.action_press("interact"))
	$Interact.button_up.connect(func(): Input.action_release("interact"))
