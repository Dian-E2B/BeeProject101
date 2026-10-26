extends CanvasLayer

signal seed_selected(seed_data: SeedData)
signal opened
signal closed

@onready var panel: Control = $Panel
@onready var stats: Label = $Panel/VBox/StatsLabel
@onready var seed_list: VBoxContainer = $Panel/VBox/SeedList

func _ready() -> void:
	panel.visible = false

func is_open() -> bool:
	return panel.visible

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

func open() -> void:
	panel.visible = true
	opened.emit()

func close() -> void:
	panel.visible = false
	closed.emit()

func refresh(data: Dictionary) -> void:
	stats.text = "Honey: %d\nNectar: %d (converts to %d honey)" % [
		data.honey,
		data.nectar,
		int(data.nectar) / int(data.nectar_per_honey)
	]

	for child in seed_list.get_children():
		child.queue_free()

	var any := false
	for s: SeedData in data.seeds:
		var count: int = data.seeds[s]
		if count <= 0:
			continue
		any = true
		var btn := Button.new()
		var marker := "▶ " if s == data.selected_seed else ""
		btn.text = "%s%s x%d" % [marker, s.rarity, count]
		btn.icon = s.icon
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(func(): seed_selected.emit(s))
		seed_list.add_child(btn)

	if not any:
		var empty := Label.new()
		empty.text = "No seeds. Visit the market!"
		seed_list.add_child(empty)
