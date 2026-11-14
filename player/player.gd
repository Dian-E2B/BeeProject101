extends CharacterBody2D

const SPEED := 200.0
const FACING_DEADZONE := 0.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_walking := false

func _ready() -> void:
	_stop_walk()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
        "ui_down"
	)

	var movement := Vector2(direction.x, direction.y * 0.5)

	if movement.length() > 0.0:
		movement = movement.normalized()

	velocity = movement * SPEED

	move_and_slide()

	# Keep the current facing when the touch joystick is close to vertical.
	# Small thumb movements there can otherwise flip the bee every frame.
	if direction.x < -FACING_DEADZONE:
		sprite.flip_h = false
	elif direction.x > FACING_DEADZONE:
		sprite.flip_h = true

	# Walking animation
	if direction.length() > 0.0:
		if not is_walking:
			_start_walk()
	else:
		if is_walking:
			_stop_walk()

func _start_walk() -> void:
	is_walking = true
	sprite.play("walk")

func _stop_walk() -> void:
	is_walking = false
	sprite.stop()
	sprite.frame = 0
