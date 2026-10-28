extends CanvasLayer

@onready var seed_list: GridContainer = %SeedList

func _ready() -> void:
	visible = false

func get_inventory(seed_counts: Dictionary) -> void:
	for child in seed_list.get_children():
		seed_list.remove_child(child)
		child.queue_free()

	var has_seeds := false
	for seed_data in seed_counts:
		var count: int = seed_counts[seed_data]
		if count <= 0:
			continue
		has_seeds = true
		var card := Button.new()
		card.flat = true
		var card_content := VBoxContainer.new()
		

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = seed_data.icon
		card_content.add_child(icon)

		var label := Label.new()
		label.text = "%d" % [count]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_content.add_child(label)
		card.pressed.connect(func(): _on_seed_card_clicked(seed_data))
		seed_list.add_child(card)

	if not has_seeds:
		var empty_label := Label.new()
		empty_label.text = "No seeds in inventory"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seed_list.add_child(empty_label)
		
	

func toggle_inventory() -> void:
	visible = not visible
	
func _on_seed_card_clicked(seed_data) -> void:
	print("Clicked seed: ", seed_data)
	
	# If your seed_data has a name or rarity property, you can print it like this:
	# print("Clicked seed rarity: ", seed_data.rarity)
	
	# (Optional) If you want clicking it to select it for planting/selling:
	# selected_seed = seed_data
	# _refresh_market()
