extends CanvasLayer

const CropData = preload("res://crop_data.gd")

@onready var inventory_label: Label = $Layout/InventoryLabel
@onready var shop_button: Button = $Layout/Actions/ShopButton
@onready var save_button: Button = $Layout/Actions/SaveButton
@onready var crop_selector: OptionButton = $Layout/Actions/CropSelector
@onready var save_status: Label = $Layout/SaveStatus
@onready var shop_panel: PanelContainer = $Layout/ShopPanel
@onready var buy_button: Button = $Layout/ShopPanel/Margin/ShopContent/BuyButton
@onready var sell_button: Button = $Layout/ShopPanel/Margin/ShopContent/SellButton
@onready var message_label: Label = $Layout/ShopPanel/Margin/ShopContent/MessageLabel

var crop_ids: Array = []
var buy_buttons: Dictionary = {}


func _ready() -> void:
	crop_ids = CropData.CROPS.keys()
	var content: VBoxContainer = $Layout/ShopPanel/Margin/ShopContent
	for crop in crop_ids:
		crop_selector.add_item(CropData.CROPS[crop]["name"])
		var prefix: String = "" if crop == "WHEAT" else CropData.CROPS[crop]["name"]
		var buy: Button = content.get_node(prefix + "BuyButton")
		var sell: Button = content.get_node(prefix + "SellButton")
		buy_buttons[crop] = buy
		buy.pressed.connect(_buy_seed.bind(crop))
		sell.pressed.connect(_sell_crop.bind(crop))
		sell.text = "Sell %s (+%d Coins)" % [CropData.CROPS[crop]["name"], CropData.CROPS[crop]["sell_price"]]
	Inventory.inventory_changed.connect(_update_inventory)
	shop_button.pressed.connect(_toggle_shop)
	save_button.pressed.connect(_save_game)
	crop_selector.item_selected.connect(_select_crop)
	_update_inventory()


func _update_inventory() -> void:
	save_status.text = ""
	inventory_label.text = "Coins: %d | Level: %d | EXP: %d / %d" % [
		Inventory.coins, Inventory.player_level, Inventory.player_exp, Inventory.exp_to_next_level()
	]
	var seed_text: Array[String] = []
	var harvest_text: Array[String] = []
	for i in range(crop_ids.size()):
		var crop: String = crop_ids[i]
		var info: Dictionary = CropData.CROPS[crop]
		var unlocked: bool = Inventory.is_unlocked(crop)
		seed_text.append("%s: %d" % [info["name"], Inventory.seed_count(crop)])
		harvest_text.append("%s: %d" % [info["name"], Inventory.crop_count(crop)])
		var choice: String = info["name"]
		if not unlocked:
			choice += " - Unlock Level %d" % info["unlock_level"]
		crop_selector.set_item_text(i, choice)
		crop_selector.set_item_disabled(i, not unlocked)
		var buy: Button = buy_buttons[crop]
		buy.disabled = not unlocked
		buy.text = "Buy %s Seed (%d Coins)" % [info["name"], info["seed_buy_price"]]
		if not unlocked:
			buy.text += " - Level %d" % info["unlock_level"]
	inventory_label.text += "\nSeeds: " + " | ".join(seed_text)
	inventory_label.text += "\nHarvest: " + " | ".join(harvest_text)
	crop_selector.select(crop_ids.find(Inventory.selected_crop))


func _select_crop(index: int) -> void:
	Inventory.select_crop(crop_ids[index])


func _save_game() -> void:
	if SaveManager.save_game():
		save_status.text = "Game saved!"
	else:
		save_status.text = "Save failed. Please try again."


func _toggle_shop() -> void:
	shop_panel.visible = not shop_panel.visible
	shop_button.text = "Close Shop" if shop_panel.visible else "Open Shop"
	message_label.text = ""


func _buy_seed(crop: String = "WHEAT") -> void:
	if Inventory.buy_seed(crop):
		message_label.text = "Bought 1 %s Seed." % CropData.CROPS[crop]["name"]
	elif not Inventory.is_unlocked(crop):
		message_label.text = "Crop is locked."
	else:
		message_label.text = "Not enough Coins!"


func _sell_crop(crop: String) -> void:
	if Inventory.sell_crop(crop):
		message_label.text = "Sold 1 %s." % CropData.CROPS[crop]["name"]
	else:
		message_label.text = "No %s to sell!" % CropData.CROPS[crop]["name"]