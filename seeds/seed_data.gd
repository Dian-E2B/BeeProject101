class_name SeedData
extends Resource

@export var rarity := "Common"
@export var icon: Texture2D
@export var price := 10               # honey to buy one seed
@export var sell_value := 15          # honey you get per harvested crop
@export var seconds_per_stage := 5.0
@export var stage_textures: Array[Texture2D]

# Nectar Production & Capacity Settings
@export var tick_seconds := 120.0     # Common 120s (2 mins), Uncommon 90s, others 60s
@export var nectar_per_tick := 1
@export var nectar_cap := 30
