extends Node2D
signal pollinated
const NECTAR_SCENE := preload("res://crops/Nectar.tscn")

var data: SeedData
var stage := 0
var timer := 0.0

var is_pollinating := false
var has_pollinated := false
var pollinate_timer := 0.0
@export var pollinate_delay := 5.0
@export var nectar_count := 12

@onready var sprite: Sprite2D = $Sprite2D

func setup(seed_data: SeedData) -> void:
	data = seed_data
	_update_sprite()

func _process(delta: float) -> void:
	if data == null:
		return
		
	if not is_grown():
		timer += delta
		if timer >= data.seconds_per_stage:
			timer = 0.0
			stage += 1
			_update_sprite()
	elif is_pollinating:
		pollinate_timer += delta
		# Cute wiggle effect while pollinating
		sprite.position.x = sin(pollinate_timer * 18.0) * 2.5
		if pollinate_timer >= pollinate_delay:
			sprite.position.x = 0.0
			is_pollinating = false
			has_pollinated = true
			spit_nectar(nectar_count)
			pollinated.emit()

func start_pollination() -> void:
	if is_pollinating or has_pollinated:
		return
	is_pollinating = true
	pollinate_timer = 0.0

func spit_nectar(count: int = 12) -> void:
	# Small squash & stretch bounce on the plant when it spits
	var pop_tween = create_tween()
	pop_tween.tween_property(sprite, "scale", Vector2(1.25, 0.75), 0.1)
	pop_tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.12)
	pop_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

	# Add nectar drops to the world/scene root so they aren't deleted if the crop is harvested
	var spawn_parent: Node = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()

	for i in range(count):
		var nectar = NECTAR_SCENE.instantiate()
		spawn_parent.add_child(nectar)

		# Start at the flower head
		var start_pos = global_position + Vector2(0, -40)
		nectar.global_position = start_pos

		# Scatter around the crop in an isometric ellipse
		var angle = randf_range(0, TAU)
		var distance = randf_range(25.0, 70.0)
		var offset = Vector2(cos(angle) * distance, sin(angle) * distance * 0.5)
		var target_pos = global_position + offset

		# Random arc height and duration for a fountain burst
		var arc_h = randf_range(30.0, 50.0)
		var duration = randf_range(0.45, 0.65)
		nectar.launch(start_pos, target_pos, arc_h, duration)

func is_grown() -> bool:
	return data != null and stage >= data.stage_textures.size() - 1

func _update_sprite() -> void:
	if data.stage_textures.is_empty():
		return
	sprite.texture = data.stage_textures[stage]
