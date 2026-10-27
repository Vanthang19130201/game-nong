extends RefCounted

# Read existing prices for presentation; never define a second economy table.
static func sell_price(item: String) -> int:
	if Inventory.CropData.CROPS.has(item.to_upper()):
		return Inventory.CropData.CROPS[item.to_upper()]["sell_price"]
	if item == "egg":
		return Inventory.EGG_PRICE
	if item == "milk":
		return Inventory.MILK_PRICE
	if Inventory.FishingData.FISH.has(item):
		return Inventory.FishingData.FISH[item]["sell_price"]
	for recipes in [Inventory.BakeryData.RECIPES, Inventory.DairyData.RECIPES]:
		if recipes.has(item):
			return recipes[item]["price"]
	return 0
