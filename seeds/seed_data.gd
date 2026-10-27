class_name SeedData
extends Resource

@export var rarity := "Common"
@export var icon: Texture2D
@export var price := 10               # honey to buy one seed
@export var sell_value := 15          # honey you get per harvested crop
@export var seconds_per_stage := 5.0
@export var stage_textures: Array[Texture2D]
