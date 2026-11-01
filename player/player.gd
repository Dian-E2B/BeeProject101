extends CharacterBody2D

var last_velocity_normalized: Vector2 = Vector2.ZERO
const SPEED := 200.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_walking := false

func _ready() -> void:
	_stop_walk()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = Vector2(direction.x, direction.y * 0.5) * SPEED
	move_and_slide()

	var current_direction := velocity.normalized()

	# Flip sprite left/right depending on direction
	if direction.x < 0:
		sprite.flip_h = false
	elif direction.x > 0:
		sprite.flip_h = true

	# Play walk animation when moving, stop when idle
	if velocity.length() > 5.0:
		if not is_walking:
			_start_walk()
	else:
		if is_walking:
			_stop_walk()

	if current_direction != Vector2.ZERO and current_direction != last_velocity_normalized:
		position = position.round()

	last_velocity_normalized = current_direction

func _start_walk() -> void:
	is_walking = true
	sprite.play("walk")

func _stop_walk() -> void:
	is_walking = false
	sprite.stop()
	sprite.frame = 0
