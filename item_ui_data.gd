extends RefCounted

# Read existing prices for presentation; never define a second economy table.
static func sell_price(item: String) -> int:
	return Inventory.sell_price(item)
