extends Control

@export var radius := 80.0
@export var knob_radius := 32.0
@export var deadzone := 0.2

var touch_id := -1
var output := Vector2.ZERO

func _ready():
	custom_minimum_size = Vector2.ONE * radius * 2
	size = custom_minimum_size

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1 and get_global_rect().has_point(event.position):
			touch_id = event.index
			_update(event.position)
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			output = Vector2.ZERO
			_apply()
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_update(event.position)

func _update(pos: Vector2):
	var center := global_position + size / 2
	output = ((pos - center) / radius).limit_length(1.0)
	_apply()
	queue_redraw()

func _apply():
	var v := output if output.length() > deadzone else Vector2.ZERO
	_set_action("ui_right", maxf(v.x, 0.0))
	_set_action("ui_left", maxf(-v.x, 0.0))
	_set_action("ui_down", maxf(v.y, 0.0))
	_set_action("ui_up", maxf(-v.y, 0.0))

func _set_action(action: String, strength: float):
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _draw():
	var c := size / 2
	draw_circle(c, radius, Color(1, 1, 1, 0.15))
	draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.4), 3.0)
	draw_circle(c + output * radius, knob_radius, Color(1, 1, 1, 0.6))
