extends Node2D

var data: SeedData
var stage := 0
var timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func setup(seed_data: SeedData) -> void:
	data = seed_data
	_update_sprite()

func _process(delta: float) -> void:
	if data == null or is_grown():
		return
	timer += delta
	if timer >= data.seconds_per_stage:
		timer = 0.0
		stage += 1
		_update_sprite()

func is_grown() -> bool:
	return data != null and stage >= data.stage_textures.size() - 1

func _update_sprite() -> void:
	if data.stage_textures.is_empty():
		return
	sprite.texture = data.stage_textures[stage]
