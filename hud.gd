extends CanvasLayer

const FarmData = preload("res://farm_data.gd")
const ToolData = preload("res://tool_data.gd")
const CropData = preload("res://crop_data.gd")
const Progression = preload("res://progression_data.gd")

@onready var inventory_label: Label = $Layout/InventoryLabel
@onready var shop_button: Button = $Layout/Actions/ShopButton
@onready var save_button: Button = $Layout/Actions/SaveButton
@onready var crop_selector: OptionButton = $Layout/Actions/CropSelector
@onready var save_status: Label = $Layout/SaveStatus
@onready var shop_panel: PanelContainer = $ShopPanel
@onready var buy_button: Button = $ShopPanel/Margin/Scroll/ShopContent/BuyButton
@onready var sell_button: Button = $ShopPanel/Margin/Scroll/ShopContent/SellButton
@onready var message_label: Label = $ShopPanel/Margin/Scroll/ShopContent/MessageLabel
@onready var reset_button: Button = $ResetControls/ResetButton
@onready var reset_confirmation: ConfirmationDialog = $ResetConfirmation
@onready var egg_sell_button: Button = $ShopPanel/Margin/Scroll/ShopContent/EggSellButton
@onready var dog_buy_button: Button = $ShopPanel/Margin/Scroll/ShopContent/DogBuyButton
@onready var station_panel: PanelContainer = $StationPanel
@onready var station_info: Label = $StationPanel/Margin/Content/Info
@onready var produce_button: Button = $StationPanel/Margin/Content/ProduceButton
@onready var collect_button: Button = $StationPanel/Margin/Content/CollectButton
@onready var order_panel: PanelContainer = $OrderPanel
@onready var order_cards: HBoxContainer = $OrderPanel/Margin/Content/Orders
@onready var order_message: Label = $OrderPanel/Margin/Content/Message

var crop_ids: Array = []
var buy_buttons: Dictionary = {}
var active_station: Node = null
var active_house: Node = null
@onready var house_panel: PanelContainer = $HousePanel
@onready var house_info: Label = $HousePanel/Margin/Content/Info
@onready var house_message: Label = $HousePanel/Margin/Content/Message
@onready var house_upgrade_button: Button = $HousePanel/Margin/Content/UpgradeButton
var building_buttons: Dictionary = {}
var animal_buttons: Dictionary = {}
var recipe_ids: Array = []
var upgrade_rows: Dictionary = {}
var dog_house_button: Button
var tool_rows: Dictionary = {}
var pending_plot_number: int = 0
@onready var plot_purchase: ConfirmationDialog = $PlotPurchase
@onready var tools_unlock_popup: AcceptDialog = $ToolsUnlocked

@onready var storage_label: Label = $Layout/StorageLabel
@onready var build_panel: PanelContainer = $BuildPanel
@onready var build_rows: VBoxContainer = $BuildPanel/Margin/Content/Scroll/Rows
@onready var recipe_selector: OptionButton = $StationPanel/Margin/Content/RecipeSelector
@onready var animal_buy: Button = $StationPanel/Margin/Content/AnimalBuy
@onready var animal_sell: Button = $StationPanel/Margin/Content/AnimalSell


func _ready() -> void:
	add_to_group("farm_hud")
	crop_ids = CropData.CROPS.keys()
	var content: VBoxContainer = $ShopPanel/Margin/Scroll/ShopContent
	for crop in crop_ids:
		crop_selector.add_item(CropData.CROPS[crop]["name"])
		var prefix: String = "" if crop == "WHEAT" else CropData.CROPS[crop]["name"]
		var buy: Button = content.get_node(prefix + "BuyButton")
		var sell: Button = content.get_node(prefix + "SellButton")
		buy_buttons[crop] = buy
		buy.pressed.connect(_buy_seed.bind(crop))
		sell.pressed.connect(_sell_crop.bind(crop))
		sell.text = "Sell %s (+%d Coins)" % [CropData.CROPS[crop]["name"], CropData.CROPS[crop]["sell_price"]]
	_create_build_rows()
	_create_tool_rows()
	house_upgrade_button.pressed.connect(_upgrade_house)
	$HousePanel/Margin/Content/CloseButton.pressed.connect(close_house)
	recipe_ids = Progression.RECIPES.keys()
	for recipe in recipe_ids:
		recipe_selector.add_item(Progression.RECIPES[recipe]["name"])
	recipe_selector.item_selected.connect(_on_recipe_selected)
	Inventory.action_failed.connect(_show_message)
	$Layout/Actions/BuildButton.pressed.connect(open_build)
	$BuildPanel/Margin/Content/CloseButton.pressed.connect(build_panel.hide)
	$ShopPanel/Margin/Scroll/ShopContent/MilkSellButton.pressed.connect(_sell_milk)
	$ShopPanel/Margin/Scroll/ShopContent/DiscardChickenFeed.pressed.connect(_discard_feed.bind("chicken_feed"))
	$ShopPanel/Margin/Scroll/ShopContent/DiscardCowFeed.pressed.connect(_discard_feed.bind("cow_feed"))
	animal_buy.pressed.connect(_buy_station_animal)
	animal_sell.pressed.connect(_sell_station_animal)
	Inventory.inventory_changed.connect(_update_inventory)
	shop_button.pressed.connect(_toggle_shop)
	save_button.pressed.connect(_save_game)
	reset_button.pressed.connect(_show_reset_confirmation)
	reset_confirmation.confirmed.connect(_reset_game)
	reset_confirmation.visibility_changed.connect(_on_reset_visibility_changed)
	plot_purchase.confirmed.connect(_confirm_plot_purchase)
	plot_purchase.visibility_changed.connect(_on_plot_popup_visibility_changed)
	crop_selector.item_selected.connect(_select_crop)
	egg_sell_button.pressed.connect(_sell_egg)
	dog_buy_button.pressed.connect(_buy_dog)
	produce_button.pressed.connect(_produce)
	collect_button.pressed.connect(_collect)
	$StationPanel/Margin/Content/CloseButton.pressed.connect(close_station)
	$OrderPanel/Margin/Content/CloseButton.pressed.connect(order_panel.hide)
	OrderManager.orders_changed.connect(_refresh_orders)
	_update_inventory()


func _update_inventory() -> void:
	save_status.text = ""
	inventory_label.text = "Coins: %d | Level: %d | EXP: %d / %d" % [
		Inventory.coins, Inventory.player_level, Inventory.player_exp, Inventory.exp_to_next_level()
	]
	inventory_label.text += " | Feed: %d | Eggs: %d" % [Inventory.chicken_feed, Inventory.egg]
	inventory_label.text += " | Cow Feed: %d | Milk: %d" % [Inventory.cow_feed, Inventory.milk]
	var next_unlock: String = "All current features unlocked"
	for feature in Progression.FEATURES:
		if Inventory.player_level < Progression.FEATURES[feature]:
			next_unlock = "%s (Level %d)" % [feature, Progression.FEATURES[feature]]
			break
	storage_label.text = "Silo: %d / %d | Barn: %d / %d | Next: %s" % [Inventory.storage_used("silo"), Inventory.silo_capacity, Inventory.storage_used("barn"), Inventory.barn_capacity, next_unlock]
	storage_label.text += "\nWood: %d | Stone: %d | House Level: %d" % [Inventory.wood, Inventory.stone, Inventory.house_level]
	storage_label.text += " | Plots: %d / %d" % [Inventory.unlocked_plot_count, FarmData.MAX_PLOTS]
	_update_build_rows()
	_update_tools()
	_show_tool_unlock_if_needed.call_deferred()
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
	_update_house_panel()
	if order_panel.visible:
		_refresh_orders()


func _select_crop(index: int) -> void:
	Inventory.select_crop(crop_ids[index])


func _show_reset_confirmation() -> void:
	reset_confirmation.popup_centered()
	reset_confirmation.get_cancel_button().grab_focus()


func _reset_game() -> void:
	if SaveManager.reset_game():
		plot_purchase.hide()
		pending_plot_number = 0
		_close_game_panels()
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
	var was_open: bool = shop_panel.visible
	_close_game_panels()
	shop_panel.visible = not was_open
	shop_button.text = "Close Shop" if shop_panel.visible else "Open Shop"
	message_label.text = ""


func _buy_seed(crop: String = "WHEAT") -> void:
	if Inventory.buy_seed(crop):
		message_label.text = "Bought 1 %s Seed." % CropData.CROPS[crop]["name"]
	elif not Inventory.is_unlocked(crop):
		message_label.text = "Crop is locked."
	else:
		message_label.text = "Not enough Coins or Silo full!"


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
	_close_game_panels()
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
	var id: String = active_station.station_id
	var is_mill: bool = id == "feed_mill"
	recipe_selector.visible = is_mill
	animal_buy.visible = not is_mill
	animal_sell.visible = not is_mill
	if is_mill:
		var recipe: String = recipe_ids[maxi(0, recipe_selector.selected)]
		var info: Dictionary = Progression.RECIPES[recipe]
		station_info.text = "Feed Mill\nState: %s\n%s\nRequires:" % [active_station.state, info["name"]]
		for item in info["requirements"]:
			station_info.text += "\n%d %s (have %d)" % [info["requirements"][item], item.capitalize(), Inventory.get(item)]
		station_info.text += "\nTime: %d seconds | Unlock Level %d" % [info["time"], info["level"]]
		if active_station.state != "IDLE":
			station_info.text += "\nBatch: " + active_station.production_type.capitalize()
		for index in range(recipe_ids.size()):
			recipe_selector.set_item_disabled(index, Inventory.player_level < Progression.RECIPES[recipe_ids[index]]["level"])
		produce_button.text = "Produce"
		collect_button.text = "Collect Feed"
		produce_button.disabled = not active_station.can_produce(recipe) or not active_station.player_near
	else:
		var product: Dictionary = Progression.PRODUCTS[id]
		var animal: String = product["animal"]
		var info: Dictionary = Progression.ANIMALS[animal]
		station_info.text = "%s\n%s: %d / %d\nState: %s\n%s: %d\n1 Feed for the whole herd\nTime: %d seconds | Production Level %d" % [Progression.BUILDINGS[id]["name"], info["name"], Inventory.get(animal + "_count"), Inventory.animal_capacity(animal), active_station.state, product["feed"].capitalize(), Inventory.get(product["feed"]), product["time"], product["level"]]
		produce_button.text = "Feed " + info["name"]
		collect_button.text = "Collect " + product["item"].capitalize()
		animal_buy.text = "Buy %s (%d Coins)" % [info["name"], info["buy"]]
		animal_sell.text = "Sell %s (+%d Coins)" % [info["name"], info["sell"]]
		var busy: bool = Inventory.animal_trade_busy(animal)
		animal_buy.disabled = busy or Inventory.player_level < info["level"] or Inventory.get(animal + "_count") >= Inventory.animal_capacity(animal)
		animal_sell.disabled = busy or Inventory.get(animal + "_count") <= 0
		produce_button.disabled = not active_station.can_produce() or not active_station.player_near
	collect_button.disabled = active_station.state != "READY" or not active_station.player_near

func _produce() -> void:
	if is_instance_valid(active_station) and active_station.player_near:
		active_station.produce(recipe_ids[maxi(0, recipe_selector.selected)])


func _collect() -> void:
	if is_instance_valid(active_station) and active_station.player_near:
		active_station.collect()


func blocks_world_input() -> bool:
	return house_panel.visible or plot_purchase.visible or tools_unlock_popup.visible or shop_panel.visible or station_panel.visible or order_panel.visible or build_panel.visible or reset_confirmation.visible or crop_selector.get_popup().visible


func _input(event: InputEvent) -> void:
	# Handle UI keys before any farm node receives _unhandled_input.
	if event.is_action_pressed("ui_cancel"):
		if not event.is_echo():
			close_current_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action("interact") and blocks_world_input():
		get_viewport().set_input_as_handled()


func close_current_panel() -> void:
	# Native popup windows sit above the panels. Panel priority matches z_index.
	if tools_unlock_popup.visible:
		tools_unlock_popup.hide()
	elif reset_confirmation.visible:
		reset_confirmation.hide()
	elif plot_purchase.visible:
		plot_purchase.hide()
	elif crop_selector.get_popup().visible:
		crop_selector.get_popup().hide()
	elif recipe_selector.get_popup().visible:
		recipe_selector.get_popup().hide()
	elif house_panel.visible:
		close_house()
	elif order_panel.visible:
		order_panel.hide()
	elif build_panel.visible:
		build_panel.hide()
	elif station_panel.visible:
		close_station()
	elif shop_panel.visible:
		shop_panel.hide()
		shop_button.text = "Open Shop"


func _close_game_panels() -> void:
	close_house()
	build_panel.hide()
	close_station()
	order_panel.hide()
	shop_panel.hide()
	shop_button.text = "Open Shop"


func open_house(house: Node) -> void:
	if not is_instance_valid(house) or not house.can_interact() or blocks_world_input():
		return
	var player = get_tree().get_first_node_in_group("farm_player")
	if player != null and is_instance_valid(player.active_resource):
		return
	_close_game_panels()
	active_house = house
	house_message.text = ""
	house_panel.show()
	_update_house_panel()


func close_house() -> void:
	house_panel.hide()
	active_house = null


func _update_house_panel() -> void:
	if not house_panel.visible:
		return
	house_message.text = ""
	house_info.text = "Current Level: %d" % Inventory.house_level
	var cost: Dictionary = Inventory.next_upgrade("house")
	house_upgrade_button.disabled = cost.is_empty()
	if cost.is_empty():
		house_info.text += "\n\nMAX LEVEL"
		return
	house_info.text += "\n\nNext Upgrade: Level %d\nCoins: %d / %d\nWood: %d / %d\nStone: %d / %d" % [Inventory.house_level + 1, Inventory.coins, cost["coins"], Inventory.wood, cost["wood"], Inventory.stone, cost["stone"]]


func _upgrade_house() -> void:
	if not house_panel.visible or not is_instance_valid(active_house) or not active_house.can_interact():
		close_house()
		return
	if Inventory.upgrade_structure("house"):
		house_message.text = "House upgraded!"
	else:
		house_message.text = "MAX LEVEL" if Inventory.next_upgrade("house").is_empty() else "Not enough resources."


func open_orders() -> void:
	_close_game_panels()
	order_message.text = ""
	order_panel.show()
	_refresh_orders()


func _refresh_orders() -> void:
	for child in order_cards.get_children():
		order_cards.remove_child(child)
		child.queue_free()
	var items: Dictionary = OrderManager.item_info()
	for order in OrderManager.orders:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(230, 250)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		card.add_child(content)
		var label := Label.new()
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.text = order["order_id"].capitalize() + "\n\n"
		for item in order["requirements"]:
			label.text += "%s: %d (have %d)\n" % [items[item]["name"], order["requirements"][item], Inventory.get(item)]
		label.text += "\nReward:\n%d Coins\n%d EXP" % [order["coin_reward"], order["exp_reward"]]
		content.add_child(label)
		var complete := Button.new()
		complete.name = "Complete"
		complete.text = "Complete"
		complete.focus_mode = Control.FOCUS_NONE
		complete.pressed.connect(_complete_order.bind(order["order_id"]))
		content.add_child(complete)
		order_cards.add_child(card)


func _complete_order(order_id: String) -> void:
	if OrderManager.complete_order(order_id):
		order_message.text = "Order completed!"
	else:
		order_message.text = "Not enough items"

func _show_message(message: String) -> void:
	save_status.text = message


func _sell_milk() -> void:
	message_label.text = "Sold 1 Milk." if Inventory.sell_milk() else "No Milk to sell!"


func _discard_feed(item: String) -> void:
	if Inventory.discard_feed(item):
		message_label.text = "Discarded 1 " + item.capitalize() + "."
	else:
		message_label.text = "No Feed to discard."


func _on_recipe_selected(_index: int) -> void:
	_update_station_panel()


func open_build() -> void:
	_close_game_panels()
	build_panel.show()
	_update_build_rows()


func _create_build_rows() -> void:
	for id in Progression.BUILDINGS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size.x = 300
		label.text = Progression.BUILDINGS[id]["name"]
		row.add_child(label)
		var buy := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		buy.pressed.connect(_buy_building.bind(id))
		row.add_child(buy)
		building_buttons[id] = buy
		build_rows.add_child(row)
	for animal in Progression.ANIMALS:
		var row := VBoxContainer.new()
		var label := Label.new()
		row.add_child(label)
		var buttons := HBoxContainer.new()
		var buy := Button.new()
		var sell := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		sell.focus_mode = Control.FOCUS_NONE
		buy.pressed.connect(_buy_animal.bind(animal))
		sell.pressed.connect(_sell_animal.bind(animal))
		buttons.add_child(buy)
		buttons.add_child(sell)
		row.add_child(buttons)
		animal_buttons[animal] = {"label": label, "buy": buy, "sell": sell}
		build_rows.add_child(row)


	var heading := Label.new()
	heading.text = "FARM UPGRADES - Wood + Stone + Coins"
	build_rows.add_child(heading)
	for id in Progression.UPGRADES:
		var row := VBoxContainer.new()
		var label := Label.new()
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_upgrade_structure.bind(id))
		row.add_child(label)
		row.add_child(button)
		build_rows.add_child(row)
		upgrade_rows[id] = {"label": label, "button": button}
	dog_house_button = Button.new()
	dog_house_button.focus_mode = Control.FOCUS_NONE
	dog_house_button.pressed.connect(_build_dog_house)
	build_rows.add_child(dog_house_button)

func _update_build_rows() -> void:
	for id in building_buttons:
		var info: Dictionary = Progression.BUILDINGS[id]
		var buy: Button = building_buttons[id]
		buy.disabled = Inventory.owns_building(id) or Inventory.player_level < info["level"]
		if Inventory.owns_building(id):
			buy.text = "Owned"
		elif Inventory.player_level < info["level"]:
			buy.text = "Locked - Level %d" % info["level"]
		else:
			buy.text = "Buy (%d Coins)" % info["price"]
	for animal in animal_buttons:
		var info: Dictionary = Progression.ANIMALS[animal]
		var row: Dictionary = animal_buttons[animal]
		var count: int = Inventory.get(animal + "_count")
		row["label"].text = "%s | %s: %d / %d" % [Progression.BUILDINGS[info["building"]]["name"], info["name"], count, Inventory.animal_capacity(animal)]
		var locked: bool = Inventory.player_level < info["level"] or not Inventory.owns_building(info["building"])
		var busy: bool = Inventory.animal_trade_busy(animal)
		if busy:
			row["label"].text += " - Collect before trading"
		row["buy"].disabled = locked or busy or count >= Inventory.animal_capacity(animal)
		row["buy"].text = "Locked - Level %d + owned building" % info["level"] if locked else "Buy %s (%d)" % [info["name"], info["buy"]]
		row["sell"].disabled = busy or count <= 0
		row["sell"].text = "Sell %s (+%d)" % [info["name"], info["sell"]]


	for id in upgrade_rows:
		var row: Dictionary = upgrade_rows[id]
		var current: int = Inventory.get(id + "_level")
		row["label"].text = "%s Lv%d" % [id.capitalize(), current]
		var cost: Dictionary = Inventory.next_upgrade(id)
		var owned: bool = id not in Progression.BUILDINGS or Inventory.owns_building(id)
		row["button"].disabled = cost.is_empty() or not owned
		if not owned:
			row["button"].text = "Buy building with Coins first"
		elif cost.is_empty():
			row["button"].text = "Max Level"
		else:
			row["button"].text = "Upgrade Lv%d: %d Wood + %d Stone + %d Coins" % [current + 1, cost["wood"], cost["stone"], cost["coins"]]
			if cost.has("capacity"):
				row["button"].text += " | Capacity %d" % cost["capacity"]
	dog_house_button.disabled = Inventory.has_dog_house
	dog_house_button.text = "Dog House: Built" if Inventory.has_dog_house else "Build Dog House: 15 Wood + 5 Stone (Dog optional)"

func _buy_building(id: String) -> void:
	Inventory.buy_building(id)


func _buy_animal(animal: String) -> void:
	Inventory.buy_animal(animal)


func _sell_animal(animal: String) -> void:
	Inventory.sell_animal(animal)


func _buy_station_animal() -> void:
	if is_instance_valid(active_station) and Progression.PRODUCTS.has(active_station.station_id):
		Inventory.buy_animal(Progression.PRODUCTS[active_station.station_id]["animal"])


func _sell_station_animal() -> void:
	if is_instance_valid(active_station) and Progression.PRODUCTS.has(active_station.station_id):
		Inventory.sell_animal(Progression.PRODUCTS[active_station.station_id]["animal"])

func _upgrade_structure(id: String) -> void:
	Inventory.upgrade_structure(id)


func _build_dog_house() -> void:
	Inventory.build_dog_house()
func _create_tool_rows() -> void:
	var content: VBoxContainer = $ShopPanel/Margin/Scroll/ShopContent
	var title := Label.new()
	title.text = "TOOLS - Unlock Level 6 | Coins upgrades"
	content.add_child(title)
	for id in ToolData.TOOLS:
		var label := Label.new()
		var button := Button.new()
		button.text = "Upgrade"
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_upgrade_tool.bind(id))
		content.add_child(label)
		content.add_child(button)
		tool_rows[id] = {"label": label, "button": button}


func _update_tools() -> void:
	if Inventory.player_level < ToolData.UNLOCK_LEVEL:
		tools_unlock_popup.hide()
	for id in tool_rows:
		var info: Dictionary = ToolData.TOOLS[id]
		var row: Dictionary = tool_rows[id]
		var level: int = Inventory.get(id + "_level")
		if not Inventory.can_use_tool(id):
			row["label"].text = info["name"] + " - Locked until Level 6"
			row["button"].disabled = true
			row["button"].text = "Locked"
			continue
		row["label"].text = "%s | Level %d | Harvest time: %.1f sec" % [info["name"], level, Inventory.tool_duration(id)]
		row["button"].disabled = not info["levels"].has(level + 1)
		row["button"].text = "Upgrade (%d Coins)" % info["levels"][level + 1]["cost"] if info["levels"].has(level + 1) else "MAX LEVEL"


func _upgrade_tool(id: String) -> void:
	Inventory.upgrade_tool(id)


func _on_reset_visibility_changed() -> void:
	if not reset_confirmation.visible:
		_show_tool_unlock_if_needed.call_deferred()


func _show_tool_unlock_if_needed() -> void:
	if Inventory.player_level < ToolData.UNLOCK_LEVEL or Inventory.tools_unlock_notified or reset_confirmation.visible or plot_purchase.visible:
		return
	if not Inventory.has_axe or not Inventory.has_hammer:
		return
	tools_unlock_popup.popup_centered()
	Inventory.tools_unlock_notified = true
	# Deferred notification: never save half of a harvest/order transaction.
	SaveManager.save_game()
func open_plot_purchase(number: int) -> void:
	if number != Inventory.unlocked_plot_count + 1:
		Inventory.fail("Unlock Plot %d first." % (Inventory.unlocked_plot_count + 1))
		return
	_close_game_panels()
	pending_plot_number = number
	plot_purchase.dialog_text = "Plot #%d\nPrice: %d Coins" % [number, FarmData.plot_price(number)]
	plot_purchase.popup_centered()


func _confirm_plot_purchase() -> void:
	if Inventory.buy_plot(pending_plot_number):
		plot_purchase.hide()
		save_status.text = "Farm plot unlocked!"
	else:
		plot_purchase.dialog_text = "Plot #%d\nPrice: %d Coins\n%s" % [pending_plot_number, FarmData.plot_price(pending_plot_number), save_status.text]


func _on_plot_popup_visibility_changed() -> void:
	if not plot_purchase.visible:
		pending_plot_number = 0
		_show_tool_unlock_if_needed.call_deferred()
