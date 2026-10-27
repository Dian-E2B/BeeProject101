extends Button

@onready var icon_rect: TextureRect = %Icon
@onready var price_label: Label = %PriceLabel

func setup(s: SeedData) -> void:
	icon_rect.texture = s.icon
	price_label.text = str(s.price)
