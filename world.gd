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
var tier_level := 2
var plot_cells: Array[Vector2i] = []
var plot_tiles: Dictionary = {}
var plot_order: Dictionary = {}
var unlocked_plot_cells: Dictionary = {}



const SEED_RESOURCES := {
	"Common": preload("res://seeds/common.tres"),
	"Uncommon": preload("res://seeds/uncommon.tres"),
	"Rare": preload("res://seeds/rare.tres"),
	"Epic": preload("res://seeds/epic.tres"),
	"Legendary": preload("res://seeds/legendary.tres"),
	"Mythical": preload("res://seeds/mythical.tres"),
}

func _ready() -> void:
	_cache_plot_cells()
	_apply_plot_tier()
	_update_stats()
	_update_inventory()
	print("WORLD READY")
	
	# Connect NetworkManager data loaded
	if Engine.has_singleton("NetworkManager") or has_node("/root/NetworkManager"):
		NetworkManager.game_data_loaded.connect(_on_server_data_loaded)
		# If data was already loaded before world._ready ran, apply it immediately!
		if not NetworkManager.last_game_data.is_empty():
			_on_server_data_loaded(NetworkManager.last_game_data)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			if (window.Telegram && Telegram.WebApp) {
				Telegram.WebApp.ready();
				Telegram.WebApp.expand();
				if (Telegram.WebApp.disableVerticalSwipes) {
					Telegram.WebApp.disableVerticalSwipes();
				}
			}
		""")

	store.interacted.connect(_open_market)
	store.player_left.connect(_close_market_if_open)
	market.sell_requested.connect(_sell_all)
	market.buy_requested.connect(_buy_seed)
	market.closed.connect(func(): player.set_physics_process(true))
	$MoveUi.inventory_pressed.connect(_toggle_inventory)
	$MoveUi.dev_reset_requested.connect(_reset_dev_data)
	inventory.seed_selected.connect(_on_inventory_seed_selected)
	child_entered_tree.connect(_on_child_added)

func _on_server_data_loaded(data: Dictionary) -> void:
	print("[World] Syncing state from server data: ", data)
	var loaded_tier: Variant = data.get("tier_level", null)
	if loaded_tier == null:
		for profile_key in ["user", "user_stats", "stats"]:
			var profile: Variant = data.get(profile_key, {})
			if profile is Dictionary and profile.has("tier_level"):
				loaded_tier = profile["tier_level"]
				break
	if loaded_tier != null:
		tier_level = int(loaded_tier)
		_apply_plot_tier()

	if data.has("honey"):
		honey = int(data["honey"])
	if data.has("nectar"):
		nectar_total = int(data["nectar"])
	
	if data.has("seeds") and data["seeds"] is Dictionary:
		seeds.clear()
		for seed_name in data["seeds"]:
			var count = int(data["seeds"][seed_name])
			# Match by case-insensitive rarity
			for rarity_key in SEED_RESOURCES:
				if rarity_key.to_lower() == str(seed_name).to_lower():
					seeds[SEED_RESOURCES[rarity_key]] = count
					break
	if data.has("plots") and data["plots"] is Array:
		_restore_plots(data["plots"])

	_update_stats()
	_update_inventory()
	_refresh_market()

func save_to_server() -> void:
	var seed_counts := {}
	for seed_res in seeds:
		if seed_res is SeedData:
			seed_counts[seed_res.rarity.to_lower()] = seeds[seed_res]
	
	var save_dict := {
		"honey": honey,
		"nectar": nectar_total,
		"tier_level": tier_level,
		"seeds": seed_counts,
		"plots": _build_plots_data()
	}

	NetworkManager.save_game(save_dict)

func _reset_dev_data() -> void:
	if not NetworkManager.is_dev_session:
		return
	nectar_total = 0
	for crop in planted.values():
		if is_instance_valid(crop):
			crop.queue_free()
	planted.clear()
	for child in get_children():
		if child.has_signal("collected"):
			child.queue_free()
	_update_stats()
	_update_inventory()
	_refresh_market()
	save_to_server()

func _unhandled_input(event: InputEvent) -> void:
	if inventory.visible:
		return

	# Check for direct tap/click on plot
	var is_click := false
	var click_pos := Vector2.ZERO
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_click = true
		click_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true
		click_pos = event.position

	if is_click:
		var world_pos := get_canvas_transform().affine_inverse() * click_pos
		var cell := plots.local_to_map(plots.to_local(world_pos))
		var is_plot := plots.get_cell_source_id(cell) != -1
		if is_plot and not planted.has(cell):
			_open_inventory_for_plot(cell)
			get_viewport().set_input_as_handled()
	
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		_toggle_inventory()
	if inventory.visible:
		prompt.visible = false
		return

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
	elif planted[cell].is_rotten:
		_show_prompt(cell, "Remove rotten crop [E]")
		if Input.is_action_just_pressed("interact"):
			_remove_rotten_crop(cell)
	elif planted[cell].is_grown():
		var crop = planted[cell]
		crop.update_nectar_from_clock()
		if crop.is_rotten:
			_show_prompt(cell, "Remove rotten crop [E]")
			if Input.is_action_just_pressed("interact"):
				_remove_rotten_crop(cell)
		elif crop.stored_nectar > 0:
			_show_prompt(cell, "Collect Nectar (%d/%d) [E]" % [crop.stored_nectar, crop.data.nectar_cap])
			if Input.is_action_just_pressed("interact"):
				collect_from_crop(cell)
		else:
			_show_prompt(cell, "Producing... (0/%d)" % [crop.data.nectar_cap])
	else:
		prompt.visible = false

func _toggle_inventory() -> void:
	print("User pressed I")
	inventory.toggle_inventory()
	player.set_physics_process(not inventory.visible)
	if not inventory.visible:
		choosing_seed_for_plot = false

func _open_inventory_for_plot(cell: Vector2i) -> void:
	if not _is_plot_unlocked(cell):
		return
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
	if not _is_plot_unlocked(cell):
		return
	seeds[seed_data] -= 1
	_update_inventory()
	_spawn_crop(cell, seed_data)
	save_to_server()

func collect_from_crop(cell: Vector2i) -> void:
	if not planted.has(cell):
		return
	var crop = planted[cell]
	crop.collect_nectar()

func _on_crop_rotted(cell: Vector2i) -> void:
	if planted.has(cell):
		save_to_server()

func _remove_rotten_crop(cell: Vector2i) -> void:
	if not planted.has(cell) or not planted[cell].is_rotten:
		return
	var crop = planted[cell]
	planted.erase(cell)
	crop.queue_free()
	save_to_server()

			
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
	save_to_server()
	
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
	save_to_server()
	

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
	char_stats.update_nectar(nectar_total)
	print("nectar +", value, " total nectar now ", nectar_total)
	save_to_server()
	
func _update_stats() ->void:
	print("honey count now:", honey)
	char_stats.update_honey(honey);
	char_stats.update_nectar(nectar_total)

func _update_inventory() -> void:
	inventory.get_inventory(seeds)

func _cache_plot_cells() -> void:
	plot_cells = plots.get_used_cells()
	plot_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	plot_tiles.clear()
	plot_order.clear()
	for index in range(plot_cells.size()):
		var cell := plot_cells[index]
		plot_order[cell] = index
		plot_tiles[cell] = {
			"source_id": plots.get_cell_source_id(cell),
			"atlas_coords": plots.get_cell_atlas_coords(cell),
			"alternative_tile": plots.get_cell_alternative_tile(cell),
		}

func _apply_plot_tier() -> void:
	tier_level = clampi(tier_level, 0, plot_cells.size())
	unlocked_plot_cells.clear()
	for index in range(plot_cells.size()):
		var cell := plot_cells[index]
		if index < tier_level:
			var tile: Dictionary = plot_tiles[cell]
			plots.set_cell(
				cell,
				int(tile["source_id"]),
				tile["atlas_coords"],
				int(tile["alternative_tile"])
			)
			unlocked_plot_cells[cell] = true
		else:
			plots.erase_cell(cell)

	for cell in planted:
		if is_instance_valid(planted[cell]):
			planted[cell].visible = unlocked_plot_cells.has(cell)

func _is_plot_unlocked(cell: Vector2i) -> bool:
	return unlocked_plot_cells.has(cell)

func _build_plots_data() -> Array:
	var out := []
	for cell in planted:
		var crop = planted[cell]
		if not is_instance_valid(crop):
			continue
		out.append({
			"x": cell.x,
			"y": cell.y,
			"rarity": crop.data.rarity.to_lower(),
			"planted_time": crop.planted_time,
			"last_collect_time": crop.last_collect_time,
			"rot_time": crop.rot_time,
			"watched_ad": crop.watched_ad,
			"stored_nectar": crop.stored_nectar,
			"is_rotten": crop.is_rotten,
		})
	return out

func _seed_by_rarity(rarity: String) -> SeedData:
	for key in SEED_RESOURCES:
		if key.to_lower() == rarity.to_lower():
			return SEED_RESOURCES[key]
	return null

func _spawn_crop(cell: Vector2i, seed_data: SeedData, saved: Dictionary = {}) -> void:
	var crop: Node2D = CROP_SCENE.instantiate()
	crops.add_child(crop)
	crop.global_position = plots.to_global(plots.map_to_local(cell))
	crop.reset_physics_interpolation()
	crop.rotted.connect(func(): _on_crop_rotted(cell))
	# Set before setup(): setup adds nectar earned since last_collect_time on top
	crop.stored_nectar = clampi(int(saved.get("stored_nectar", 0)), 0, seed_data.nectar_cap)
	crop.setup(
		seed_data,
		int(saved.get("planted_time", 0)),
		int(saved.get("last_collect_time", 0)),
		int(saved.get("rot_time", 0)),
		bool(saved.get("watched_ad", false)),
		bool(saved.get("is_rotten", false))
	)
	crop.visible = _is_plot_unlocked(cell)
	planted[cell] = crop

func _restore_plots(list: Array) -> void:
	for cell in planted:
		if is_instance_valid(planted[cell]):
			planted[cell].queue_free()
	planted.clear()

	for entry in list:
		if not entry is Dictionary:
			continue
		var seed_data: SeedData = _seed_by_rarity(str(entry.get("rarity", "")))
		if seed_data == null:
			continue
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if not plot_order.has(cell) or planted.has(cell):
			continue
		_spawn_crop(cell, seed_data, entry)
	
