extends Node2D

signal pollinated
signal rotted

const NECTAR_SCENE := preload("res://crops/Nectar.tscn")

var data: SeedData
var stage := 0
var timer := 0.0

var planted_time: int = 0
var last_collect_time: int = 0
var rot_time: int = 0
var watched_ad: bool = false

var stored_nectar: int = 0
var tick_accumulator := 0.0

var is_collecting := false

@onready var sprite: Sprite2D = $Sprite2D

func setup(seed_data: SeedData, p_planted_time: int = 0, p_last_collect_time: int = 0, p_rot_time: int = 0, p_watched_ad: bool = false) -> void:
	data = seed_data
	var now := int(Time.get_unix_time_from_system())
	planted_time = p_planted_time if p_planted_time > 0 else now
	last_collect_time = p_last_collect_time if p_last_collect_time > 0 else planted_time
	watched_ad = p_watched_ad
	
	if p_rot_time > 0:
		rot_time = p_rot_time
	else:
		rot_time = calculate_rot_time(planted_time, watched_ad)
		
	_update_sprite()
	update_nectar_from_clock()

# Rot Calculation:
# Next reset after planting: 01:00 UTC (9:00 AM Singapore, UTC+8).
# If watched_ad: planted_time + 86400 (24h).
static func calculate_rot_time(p_planted_time: int, p_watched_ad: bool) -> int:
	if p_watched_ad:
		return p_planted_time + 86400
	var offset: int = 3600 # 01:00 UTC
	var day_seconds: int = 86400
	var days_since_epoch: int = (p_planted_time - offset) / day_seconds
	var next_reset: int = (days_since_epoch + 1) * day_seconds + offset
	return next_reset

func _process(delta: float) -> void:
	if data == null:
		return

	# Check for rot
	var now := int(Time.get_unix_time_from_system())
	if rot_time > 0 and now >= rot_time:
		rotted.emit()
		return
		
	# Growth progression
	if not is_grown():
		timer += delta
		if timer >= data.seconds_per_stage:
			timer = 0.0
			stage += 1
			_update_sprite()
	else:
		# Grown: Accumulate nectar ticks in real-time
		var cap := data.nectar_cap
		if stored_nectar < cap:
			tick_accumulator += delta
			var tick_sec := data.tick_seconds
			if tick_sec > 0.0 and tick_accumulator >= tick_sec:
				var whole_ticks := int(tick_accumulator / tick_sec)
				tick_accumulator -= whole_ticks * tick_sec
				stored_nectar = mini(cap, stored_nectar + whole_ticks * data.nectar_per_tick)
				last_collect_time = now

func update_nectar_from_clock() -> void:
	if data == null or not is_grown():
		return
	var now := int(Time.get_unix_time_from_system())
	if rot_time > 0 and now >= rot_time:
		rotted.emit()
		return

	var tick_sec: int = int(data.tick_seconds)
	if tick_sec <= 0:
		return
	var elapsed := maxi(0, now - last_collect_time)
	var whole_ticks := elapsed / tick_sec
	if whole_ticks > 0:
		var cap := data.nectar_cap
		stored_nectar = mini(cap, stored_nectar + whole_ticks * data.nectar_per_tick)
		# Advance last_collect_time by elapsed whole ticks so remainders aren't lost
		last_collect_time += whole_ticks * tick_sec

func collect_nectar() -> int:
	if stored_nectar <= 0 or is_collecting:
		return 0
	
	is_collecting = true
	var amount := stored_nectar
	stored_nectar = 0
	last_collect_time = int(Time.get_unix_time_from_system())
	tick_accumulator = 0.0
	
	spit_nectar(amount)
	
	var pop_tween = create_tween()
	pop_tween.tween_property(sprite, "scale", Vector2(1.25, 0.75), 0.1)
	pop_tween.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.12)
	pop_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	pop_tween.tween_callback(func(): is_collecting = false)
	
	pollinated.emit()
	return amount

func spit_nectar(count: int = 12) -> void:
	var spawn_parent: Node = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()

	for i in range(count):
		var nectar = NECTAR_SCENE.instantiate()
		spawn_parent.add_child(nectar)

		var start_pos = global_position + Vector2(0, -40)
		nectar.global_position = start_pos

		var angle = randf_range(0, TAU)
		var distance = randf_range(25.0, 70.0)
		var offset = Vector2(cos(angle) * distance, sin(angle) * distance * 0.5)
		var target_pos = global_position + offset

		var arc_h = randf_range(30.0, 50.0)
		var duration = randf_range(0.45, 0.65)
		nectar.launch(start_pos, target_pos, arc_h, duration)

func is_grown() -> bool:
	return data != null and stage >= data.stage_textures.size() - 1

func _update_sprite() -> void:
	if data.stage_textures.is_empty():
		return
	sprite.texture = data.stage_textures[stage]
