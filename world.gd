extends Node2D

const CROP_SCENE := preload("res://crops/Crops.tscn")

@onready var plots: TileMapLayer = $Plots
@onready var crops: Node2D = $Crops
@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $PromptLabel

@onready var store = $Store
@onready var market = $Market

@onready var inventory = $Inventory

var honey := 24
var crops_held := 0
var crops_value := 0
var seeds := {}                 # SeedData -> how many you own
var selected_seed: SeedData
const NECTAR_PER_HONEY := 12
var nectar := 0
var market_open := false

var planted := {}   # cell (Vector2i) -> Crop node
func _ready() -> void:
	store.interacted.connect(_open_market)
	# market.sell_requested.connect(_sell_all)
	market.buy_requested.connect(_buy_seed)
	market.convert_requested.connect(_convert_nectar)
	# selected_seed = preload("res://seeds/common.tres")
	# seeds[selected_seed] = 3
	inventory.seed_selected.connect(_on_seed_selected)
	inventory.opened.connect(_freeze_player)
	inventory.closed.connect(func(): player.set_physics_process(true))
	market.closed.connect(func():
		market_open = false
		player.set_physics_process(true)
	)
	
func _process(_delta: float) -> void:
	if inventory.is_open():
		prompt.visible = false
		return
	var cell := _get_player_cell()
	var on_plot := plots.get_cell_source_id(cell) != -1

	if not on_plot:
		prompt.visible = false
		return

	if not planted.has(cell):
		if has_seed():
			_show_prompt(cell, "Plant %s [E]" % selected_seed.rarity)
			if Input.is_action_just_pressed("interact"):
				plant(cell)
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

func plant(cell: Vector2i) -> void:
	seeds[selected_seed] -= 1
	var crop: Node2D = CROP_SCENE.instantiate()
	crops.add_child(crop)
	crop.global_position = plots.to_global(plots.map_to_local(cell))
	crop.setup(selected_seed)
	planted[cell] = crop
	if seeds[selected_seed] <= 0:
		_select_next_seed()

func _select_next_seed() -> void:
	for s in seeds:
		if seeds[s] > 0:
			selected_seed = s
			return

func pollinate(cell: Vector2i) -> void:
	var crop = planted[cell]
	if crop.is_pollinating or crop.has_pollinated:
		return
	crop.pollinated.connect(func():
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
	if inventory.is_open():
		inventory.close()
	market_open = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	_refresh_market()
	market.open()

# func _sell_all() -> void:
# 	honey += crops_value
# 	crops_held = 0
# 	crops_value = 0
# 	_refresh_market()
	
func _buy_seed(seed_data: SeedData) -> void:
	if honey < seed_data.price:
		return
	honey -= seed_data.price
	seeds[seed_data] = seeds.get(seed_data, 0) + 1
	selected_seed = seed_data   # the seed you just bought is the one you plant
	_refresh_market()

func _convert_nectar() -> void:
	var gained := nectar / NECTAR_PER_HONEY
	if gained <= 0:
		return
	nectar -= gained * NECTAR_PER_HONEY
	honey += gained
	_refresh_market()

func add_nectar(amount: int = 1) -> void:
	nectar += amount
	_refresh_market()

func _refresh_market() -> void:
	var owned: int = seeds.get(selected_seed, 0)
	var planting := "none"
	if selected_seed != null:
		planting = "%s x%d" % [selected_seed.rarity, owned]
	market.update_info("Honey: %d\nNectar: %d (converts to %d honey)\nPlanting: %s" % [honey, nectar, nectar / NECTAR_PER_HONEY, planting])
	_refresh_inventory()

func has_seed() -> bool:
	return selected_seed != null and seeds.get(selected_seed, 0) > 0

func _unhandled_input(event: InputEvent) -> void:
	if market_open:
		return
	if event.is_action_pressed("inventory"):
		inventory.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and inventory.is_open():
		inventory.close()

func _freeze_player() -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	_refresh_inventory()

func _on_seed_selected(seed_data: SeedData) -> void:
	selected_seed = seed_data
	_refresh_inventory()

func _refresh_inventory() -> void:
	inventory.refresh({
		"honey": honey,
		"nectar": nectar,
		"nectar_per_honey": NECTAR_PER_HONEY,
		"seeds": seeds,
		"selected_seed": selected_seed,
	})
