extends Node2D

const CROP_SCENE := preload("res://crops/Crops.tscn")

@onready var plots: TileMapLayer = $Plots
@onready var crops: Node2D = $Crops
@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $PromptLabel

@onready var store = $Store
@onready var market = $Market
@onready var char_stats: CanvasLayer = $CharStats
@onready var inventory: CanvasLayer = $Inventory


var honey := 5000
var nectar_total := 0
var crops_held := 0
var crops_value := 0
var seeds := {}                 # SeedData -> how many you own
var bought_seed_counts: Dictionary = {}
var selected_seed: SeedData
var pending_plant_cell: Vector2i
var choosing_seed_for_plot := false
var purchase_summary: Array[String] = []

var planted := {}   # cell (Vector2i) -> Crop node
func _ready() -> void:
	_update_stats()
	_update_inventory()
	print("WORLD READY")
	store.interacted.connect(_open_market)
	store.player_left.connect(_close_market_if_open)
	market.sell_requested.connect(_sell_all)
	market.buy_requested.connect(_buy_seed)
	market.closed.connect(func(): player.set_physics_process(true))
	$MoveUi.inventory_pressed.connect(_toggle_inventory)
	inventory.seed_selected.connect(_on_inventory_seed_selected)
	child_entered_tree.connect(_on_child_added)
	# selected_seed = preload("res://seeds/common.tres")
	# seeds[selected_seed] = 3
	
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()

	var cell := _get_player_cell()
	var on_plot := plots.get_cell_source_id(cell) != -1

	if not on_plot:
		prompt.visible = false
		return

	if not planted.has(cell):
		if _has_any_seed():
			_show_prompt(cell, "Choose seed [E]")
			if Input.is_action_just_pressed("interact"):
				_open_inventory_for_plot(cell)
		else:
			_show_prompt(cell, "Need seeds")
	elif planted[cell].is_grown():
		var crop = planted[cell]
		if crop.is_pollinating:
			_show_prompt(cell, "Pollinating...")
		elif not crop.has_pollinated:
			_show_prompt(cell, "Pollinate [E]")
			if Input.is_action_just_pressed("interact"):
				pollinate(cell)
		else:
			prompt.visible = false
	else:
		prompt.visible = false

func _toggle_inventory() -> void:
	print("User pressed I")
	inventory.toggle_inventory()
	player.set_physics_process(not inventory.visible)
	if not inventory.visible:
		choosing_seed_for_plot = false

func _open_inventory_for_plot(cell: Vector2i) -> void:
	pending_plant_cell = cell
	choosing_seed_for_plot = true
	inventory.visible = true
	player.set_physics_process(false)

func _on_inventory_seed_selected(seed_data: SeedData) -> void:
	if seeds.get(seed_data, 0) <= 0:
		return
	selected_seed = seed_data
	if choosing_seed_for_plot:
		plant(pending_plant_cell, seed_data)
		choosing_seed_for_plot = false
		inventory.visible = false
		player.set_physics_process(true)
	else:
		_update_inventory()

func plant(cell: Vector2i, seed_data: SeedData) -> void:
	seeds[seed_data] -= 1
	_update_inventory()
	var crop: Node2D = CROP_SCENE.instantiate()
	crops.add_child(crop)
	crop.global_position = plots.to_global(plots.map_to_local(cell))
	crop.setup(seed_data)
	planted[cell] = crop

func pollinate(cell: Vector2i) -> void:
	var crop = planted[cell]
	if crop.is_pollinating or crop.has_pollinated:
		return
	crop.pollinated.connect(func():
		crops_held += 1
		crops_value += crop.data.sell_value
		planted.erase(cell)
		var t = create_tween()
		t.tween_property(crop, "modulate:a", 0.0, 0.3)
		t.tween_callback(crop.queue_free)
	)
	crop.start_pollination()

			
func _get_player_cell() -> Vector2i:
	# Use the feet so it feels right on the isometric grid
	var feet := player.global_position + Vector2(0, 8)
	return plots.local_to_map(plots.to_local(feet))

func _show_prompt(cell: Vector2i, text: String) -> void:
	prompt.text = text
	prompt.visible = true
	var pos := plots.to_global(plots.map_to_local(cell))
	prompt.global_position = pos + Vector2(-prompt.size.x / 2.0, -60)
	


func _open_market() -> void:
	_refresh_market()
	market.open()

func _close_market_if_open() -> void:
	if market.visible:
		market.close()

func _sell_all() -> void:
	honey += crops_value
	crops_held = 0
	crops_value = 0
	print("sold +", crops_value)
	_update_stats()
	_refresh_market()
	
func _buy_seed(seed_data: SeedData) -> void:
	if honey < seed_data.price:
		return
	honey -= seed_data.price
	print("bought, price ", seed_data.price)
	seeds[seed_data] = seeds.get(seed_data, 0) + 1
	bought_seed_counts[seed_data.rarity] = bought_seed_counts.get(seed_data.rarity, 0) + 1
	selected_seed = seed_data   # the seed you just bought is the one you plant
	purchase_summary.clear()
	for rarity in bought_seed_counts:
		purchase_summary.append("%s x%d" % [rarity, bought_seed_counts[rarity]])
	# print("Seeds bought so far: ", ", ".join(purchase_summary))
	_update_inventory()
	_update_stats()
	_refresh_market()
	

func _refresh_market() -> void:
	var owned: int = seeds.get(selected_seed, 0)
	var planting := "none"
	if selected_seed != null:
		planting = "%s x%d" % [selected_seed.rarity, owned]
	market.update_info(crops_held, crops_value, planting)
	
	
func has_seed() -> bool:
	return selected_seed != null and seeds.get(selected_seed, 0) > 0

func _has_any_seed() -> bool:
	for count in seeds.values():
		if count > 0:
			return true
	return false

func _on_child_added(node: Node) -> void:
	if node.has_signal("collected"):
		node.collected.connect(_on_nectar_collected)

func _on_nectar_collected(value: int) -> void:
	nectar_total += value
	print("nectar +", value, " total nectar now ", nectar_total)
	
func _update_stats() ->void:
	print("honey count now:", honey)
	char_stats.update_honey(honey);

func _update_inventory() -> void:
	inventory.get_inventory(seeds)
	
