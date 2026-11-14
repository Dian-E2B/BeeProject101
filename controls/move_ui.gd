extends CanvasLayer

signal inventory_pressed
signal dev_reset_requested

var fps_update_timer := 0.0

func _ready():
	$Interact.button_down.connect(func(): Input.action_press("interact"))
	$Interact.button_up.connect(func(): Input.action_release("interact"))
	$Inventory.pressed.connect(func(): inventory_pressed.emit())
	$ResetButton.visible = NetworkManager.is_dev_session
	$ResetButton.pressed.connect(func(): $ResetConfirmation.popup_centered())
	$ResetConfirmation.confirmed.connect(func(): dev_reset_requested.emit())

func _process(delta: float) -> void:
	fps_update_timer += delta
	if fps_update_timer >= 1.0:
		$FpsLabel.text = "FPS: %d" % Engine.get_frames_per_second()
		fps_update_timer = 0.0
