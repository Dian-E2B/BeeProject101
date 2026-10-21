extends Area2D

signal interacted

@onready var prompt: Label = $Prompt
var player_near := false

func _ready() -> void:
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		player_near = true
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		player_near = false
		prompt.visible = false

func _process(_delta: float) -> void:
	if player_near and Input.is_action_just_pressed("interact"):
		interacted.emit()
