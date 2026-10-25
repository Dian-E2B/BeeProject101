extends CharacterBody2D

var last_velocity_normalized: Vector2 = Vector2.ZERO
const SPEED := 200.0

@onready var armature_view: DragonBonesArmatureView = $DragonBonesArmatureView
var is_walking := false

func _ready() -> void:
	print(armature_view.get_animations())
	_stop_walk()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = Vector2(direction.x, direction.y * 0.5) * SPEED
	move_and_slide()

	var current_direction := velocity.normalized()

	# Flip sprite left/right depending on direction
	if direction.x != 0:
		armature_view.flip_x = direction.x > 0
	#if direction.x < 0:
		#armature_view.scale.x = -abs(armature_view.scale.x)
	elif direction.x > 0:
		armature_view.scale.x = abs(armature_view.scale.x)

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
	armature_view.play("walk")


func _stop_walk() -> void:
	is_walking = false
	armature_view.stop_all_animations(false)
