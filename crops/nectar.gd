extends Area2D

@export var honey_value := 1
@onready var sprite: Sprite2D = $Sprite2D

var can_collect := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(start_pos: Vector2, target_pos: Vector2, arc_height: float = 40.0, duration: float = 0.55) -> void:
	can_collect = false
	global_position = start_pos
	
	# Parabolic arc animation using Tweens
	var tween = create_tween().set_parallel(true)
	
	# Horizontal / Ground movement
	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Vertical fake height arc (pops up, then falls and bounces)
	var height_tween = create_tween()
	height_tween.tween_property(sprite, "position:y", -arc_height, duration * 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(sprite, "position:y", 0.0, duration * 0.55)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	# Once it lands, enable collection and idle hover
	height_tween.tween_callback(func():
		can_collect = true
		_start_idle_animation()
	)

func _start_idle_animation() -> void:
	var bob_tween = create_tween().set_loops()
	bob_tween.tween_property(sprite, "position:y", -4.0, 0.6).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(sprite, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if not can_collect:
		return
	if body.name == "Player" or body.is_in_group("player"):
		can_collect = false
		_collect(body)

func _collect(player: Node2D) -> void:
	# Add honey to world
	var world = get_tree().current_scene
	if world and "honey" in world:
		world.honey += honey_value
		if world.has_method("_refresh_market"):
			world._refresh_market()
	
	# Cute pickup animation: fly into player and shrink
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", player.global_position, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.18)
	tween.chain().tween_callback(queue_free)

