extends RefCounted

const CANCEL_COOLDOWN: float = 180.0
# Quantities are per item. Storage limits and fish rarity caps still apply.
const TIERS: Dictionary = {
	"EASY": {"level":1,"weight":40,"types_min":1,"types_max":1,"crop_min":3,"crop_max":5,"product_min":1,"product_max":2,"coins":1.25,"exp":1.0,"color":Color("c9d9a5")},
	"NORMAL": {"level":4,"weight":35,"types_min":1,"types_max":2,"crop_min":3,"crop_max":6,"product_min":1,"product_max":3,"coins":1.4,"exp":1.3,"color":Color("d5d9b9")},
	"HARD": {"level":8,"weight":20,"types_min":2,"types_max":3,"crop_min":4,"crop_max":8,"product_min":2,"product_max":3,"coins":1.7,"exp":1.7,"color":Color("edc58e")},
	"PREMIUM": {"level":15,"weight":5,"types_min":3,"types_max":4,"crop_min":5,"crop_max":10,"product_min":2,"product_max":4,"coins":2.1,"exp":2.2,"color":Color("d9b5d5")}
}
