extends CanvasLayer
@onready var animated_sprite_2d: AnimatedSprite2D = %AnimatedSprite2D
@onready var eggshop: CanvasLayer = $"."

var common_egg = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if eggshop.visible:
		animated_sprite_2d.play("eggidle")
		print("The canvas layer is visible!")
	else:
		animated_sprite_2d.stop()
		print("The canvas layer is hidden!")
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	pass # Replace with function body.


func _common_egg_buy_pressed() -> void:
	common_egg += 1
	print(common_egg)
	
