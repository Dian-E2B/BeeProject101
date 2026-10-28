extends CanvasLayer
@onready var honey_stats: Label = $HoneyStats
@onready var nectar_stats: Label = $NectarStats


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func update_honey(honey: int) -> void:
	honey_stats.text = "%d" % honey
	
func update_nectar(nectar: int) -> void:
	nectar_stats.text = "%d" % nectar
