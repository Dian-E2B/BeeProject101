
extends CharacterBody2D

var last_velocity_normalized: Vector2 = Vector2.ZERO
const SPEED := 200.0
func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = Vector2(direction.x, direction.y * 0.5) * SPEED
	move_and_slide()

	var current_direction := velocity.normalized()

	if current_direction != Vector2.ZERO \
	and current_direction != last_velocity_normalized:
		position = position.round()

	last_velocity_normalized = current_direction
