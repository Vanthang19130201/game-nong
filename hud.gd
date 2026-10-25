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
@onready var reset_button: Button = $ResetControls/ResetButton
@onready var reset_confirmation: ConfirmationDialog = $ResetConfirmation
@onready var egg_sell_button: Button = $Layout/ShopPanel/Margin/ShopContent/EggSellButton
@onready var dog_buy_button: Button = $Layout/ShopPanel/Margin/ShopContent/DogBuyButton
@onready var station_panel: PanelContainer = $StationPanel
@onready var station_info: Label = $StationPanel/Margin/Content/Info
@onready var produce_button: Button = $StationPanel/Margin/Content/ProduceButton
@onready var collect_button: Button = $StationPanel/Margin/Content/CollectButton

var crop_ids: Array = []
var buy_buttons: Dictionary = {}
var active_station: Node = null


func _ready() -> void:
	add_to_group("farm_hud")
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
	reset_button.pressed.connect(_show_reset_confirmation)
	reset_confirmation.confirmed.connect(_reset_game)
	crop_selector.item_selected.connect(_select_crop)
	egg_sell_button.pressed.connect(_sell_egg)
	dog_buy_button.pressed.connect(_buy_dog)
	produce_button.pressed.connect(_produce)
	collect_button.pressed.connect(_collect)
	$StationPanel/Margin/Content/CloseButton.pressed.connect(close_station)
	_update_inventory()


func _update_inventory() -> void:
	save_status.text = ""
	inventory_label.text = "Coins: %d | Level: %d | EXP: %d / %d" % [
		Inventory.coins, Inventory.player_level, Inventory.player_exp, Inventory.exp_to_next_level()
	]
	inventory_label.text += " | Feed: %d | Eggs: %d" % [Inventory.chicken_feed, Inventory.egg]
	egg_sell_button.text = "Sell Egg (+%d Coins)" % Inventory.EGG_PRICE
	dog_buy_button.disabled = Inventory.has_dog
	dog_buy_button.text = "Owned" if Inventory.has_dog else "Buy Dog (%d Coins)" % Inventory.DOG_PRICE
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
	_update_station_panel()


func _select_crop(index: int) -> void:
	Inventory.select_crop(crop_ids[index])


func _show_reset_confirmation() -> void:
	reset_confirmation.popup_centered()
	reset_confirmation.get_cancel_button().grab_focus()


func _reset_game() -> void:
	if SaveManager.reset_game():
		close_station()
		message_label.text = ""
		save_status.text = "Game reset and saved!"
	else:
		save_status.text = "Reset failed. Please try again."


func _save_game() -> void:
	if SaveManager.save_game():
		save_status.text = "Game saved!"
	else:
		save_status.text = "Save failed. Please try again."


func _toggle_shop() -> void:
	close_station()
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


func _sell_egg() -> void:
	message_label.text = "Sold 1 Egg." if Inventory.sell_egg() else "No Eggs to sell!"


func _buy_dog() -> void:
	if Inventory.buy_dog():
		message_label.text = "Dog purchased!"
	else:
		message_label.text = "Dog already owned." if Inventory.has_dog else "Need 300 Coins!"


func open_station(station: Node) -> void:
	close_station()
	active_station = station
	active_station.state_changed.connect(_update_station_panel)
	shop_panel.hide()
	shop_button.text = "Open Shop"
	station_panel.show()
	_update_station_panel()


func close_station() -> void:
	if is_instance_valid(active_station) and active_station.state_changed.is_connected(_update_station_panel):
		active_station.state_changed.disconnect(_update_station_panel)
	active_station = null
	station_panel.hide()


func _update_station_panel() -> void:
	if not is_instance_valid(active_station):
		return
	if active_station.station_id == "feed_mill":
		station_info.text = "Feed Mill\nChicken Feed\nRequires: 1 Wheat + 1 Corn\nProduction time: 10 seconds\nFEED: " + active_station.state
		produce_button.text = "Produce"
		collect_button.text = "Collect Feed"
	else:
		station_info.text = "Chicken Coop\n%d Chickens\nChicken Feed: %d\nFeeding costs: 1 Feed for the whole coop\nProduction time: 20 seconds\nState: %s" % [active_station.chicken_count, Inventory.chicken_feed, active_station.state]
		produce_button.text = "Feed Chickens"
		collect_button.text = "Collect Eggs"
	produce_button.disabled = not active_station.can_produce() or not active_station.player_near
	collect_button.disabled = active_station.state != "READY" or not active_station.player_near


func _produce() -> void:
	if is_instance_valid(active_station) and active_station.player_near:
		active_station.produce()


func _collect() -> void:
	if is_instance_valid(active_station) and active_station.player_near:
		active_station.collect()