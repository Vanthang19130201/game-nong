extends Node

signal inventory_changed

const CropData = preload("res://crop_data.gd")
const DOG_PRICE: int = 300
const EGG_PRICE: int = 18

var wheat_seed: int = 10
var wheat: int = 0
var corn_seed: int = 0
var corn: int = 0
var carrot_seed: int = 0
var carrot: int = 0
var coins: int = 1000
var player_exp: int = 0
var player_level: int = 1
var selected_crop: String = "WHEAT"
var chicken_feed: int = 0
var egg: int = 0
var has_dog: bool = false


func buy_dog() -> bool:
	if has_dog or coins < DOG_PRICE:
		return false
	coins -= DOG_PRICE
	has_dog = true
	inventory_changed.emit()
	return true


func sell_egg() -> bool:
	if egg <= 0:
		return false
	egg -= 1
	coins += EGG_PRICE
	inventory_changed.emit()
	return true


func is_unlocked(crop: String) -> bool:
	return CropData.CROPS.has(crop) and player_level >= CropData.CROPS[crop]["unlock_level"]


func seed_count(crop: String) -> int:
	if not CropData.CROPS.has(crop):
		return 0
	return get(crop.to_lower() + "_seed")


func crop_count(crop: String) -> int:
	if not CropData.CROPS.has(crop):
		return 0
	return get(crop.to_lower())


func select_crop(crop: String) -> bool:
	if not is_unlocked(crop):
		return false
	if selected_crop != crop:
		selected_crop = crop
		inventory_changed.emit()
	return true


func buy_seed(crop: String) -> bool:
	if not is_unlocked(crop):
		return false
	var price: int = CropData.CROPS[crop]["seed_buy_price"]
	if coins < price:
		return false
	coins -= price
	set(crop.to_lower() + "_seed", seed_count(crop) + 1)
	inventory_changed.emit()
	return true


func sell_crop(crop: String) -> bool:
	if crop_count(crop) <= 0:
		return false
	set(crop.to_lower(), crop_count(crop) - 1)
	coins += CropData.CROPS[crop]["sell_price"]
	inventory_changed.emit()
	return true


func can_plant(crop: String) -> bool:
	return is_unlocked(crop) and seed_count(crop) > 0


func use_seed(crop: String) -> bool:
	if not can_plant(crop):
		return false
	set(crop.to_lower() + "_seed", seed_count(crop) - 1)
	inventory_changed.emit()
	return true


func collect_crop(crop: String) -> void:
	if not CropData.CROPS.has(crop):
		return
	set(crop.to_lower(), crop_count(crop) + 1)
	player_exp += CropData.CROPS[crop]["harvest_exp"]
	normalize_exp()
	# Save crop, EXP and any level-ups together after the plot is cleared.
	inventory_changed.emit()


func exp_to_next_level() -> int:
	return player_level * 100


func normalize_exp() -> void:
	while player_exp >= exp_to_next_level():
		player_exp -= exp_to_next_level()
		player_level += 1


func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	player_exp += amount
	normalize_exp()
	inventory_changed.emit()


# Keep the original Wheat methods available for existing callers.
func buy_wheat_seed() -> bool:
	return buy_seed("WHEAT")


func sell_wheat() -> bool:
	return sell_crop("WHEAT")


func use_wheat_seed() -> bool:
	return use_seed("WHEAT")


func add_wheat(amount: int = 1) -> void:
	if amount <= 0:
		return
	wheat += amount
	inventory_changed.emit()


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	inventory_changed.emit()


func remove_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	inventory_changed.emit()
	return true
