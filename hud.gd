extends CanvasLayer

const FarmData = preload("res://farm_data.gd")
const ToolData = preload("res://tool_data.gd")
const CropData = preload("res://crop_data.gd")
const Progression = preload("res://progression_data.gd")
const FishingData = preload("res://fishing_data.gd")
@onready var fishing_ui: Control = $FishingUI
@onready var fish_market_panel: PanelContainer = $FishMarketPanel
@onready var storage_panel: PanelContainer = $StoragePanel
@onready var experience_bar: ProgressBar = $Layout/Experience/ExperienceBar
@onready var experience_value: Label = $Layout/Experience/ExperienceValue
var rod_info: Label
var rod_upgrade: Button

@onready var inventory_label: Label = $Layout/InventoryLabel
@onready var shop_button: Button = $Layout/Actions/ShopButton
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
var debug_panel: PanelContainer
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
	if OS.is_debug_build():
		debug_panel = PanelContainer.new()
		debug_panel.set_script(preload("res://dev_debug_panel.gd"))
		add_child(debug_panel)
		debug_panel.visibility_changed.connect(_on_main_panel_visibility_changed)
	for panel in [shop_panel, build_panel, station_panel, house_panel, order_panel, fish_market_panel, storage_panel]:
		panel.visibility_changed.connect(_on_main_panel_visibility_changed)
	crop_ids = CropData.CROPS.keys()
	var content: VBoxContainer = $ShopPanel/Margin/Scroll/ShopContent
	for crop in crop_ids:
		crop_selector.add_item(Localization.display_name(CropData.CROPS[crop]["name"]))
		var prefix: String = "" if crop == "WHEAT" else crop.capitalize()
		var buy: Button = content.get_node(prefix + "BuyButton")
		var sell: Button = content.get_node(prefix + "SellButton")
		buy_buttons[crop] = buy
		buy.pressed.connect(_buy_seed.bind(crop))
		sell.pressed.connect(_sell_crop.bind(crop))
		sell.text = tr("UI_SELL_CROP") % [Localization.display_name(CropData.CROPS[crop]["name"]), CropData.CROPS[crop]["sell_price"]]
	_create_build_rows()
	_create_tool_rows()
	_create_rod_row()
	house_upgrade_button.pressed.connect(_upgrade_house)
	$HousePanel/Margin/Content/CloseButton.pressed.connect(close_house)
	recipe_ids = Progression.RECIPES.keys()
	for recipe in recipe_ids:
		recipe_selector.add_item(Localization.display_name(Progression.RECIPES[recipe]["name"]))
	recipe_selector.item_selected.connect(_on_recipe_selected)
	Inventory.action_failed.connect(_show_message)
	$Layout/Actions/BuildButton.pressed.connect(open_build)
	$Layout/Actions/StorageButton.pressed.connect(_toggle_storage)
	$Layout/Actions/OrdersButton.pressed.connect(open_orders)
	$BuildPanel/Margin/Content/CloseButton.pressed.connect(build_panel.hide)
	$ShopPanel/Margin/Scroll/ShopContent/MilkSellButton.pressed.connect(_sell_milk)
	$ShopPanel/Margin/Scroll/ShopContent/DiscardChickenFeed.pressed.connect(_discard_feed.bind("chicken_feed"))
	$ShopPanel/Margin/Scroll/ShopContent/DiscardCowFeed.pressed.connect(_discard_feed.bind("cow_feed"))
	animal_buy.pressed.connect(_buy_station_animal)
	animal_sell.pressed.connect(_sell_station_animal)
	Inventory.inventory_changed.connect(_update_inventory)
	shop_button.pressed.connect(_toggle_shop)
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
	inventory_label.text = tr("HUD_COMPACT") % [Inventory.coins, Inventory.player_level]
	experience_bar.max_value = Inventory.exp_to_next_level()
	experience_bar.value = Inventory.player_exp
	experience_value.text = "%d / %d" % [Inventory.player_exp, Inventory.exp_to_next_level()]
	storage_label.text = ""
	_update_build_rows()
	_update_tools()
	_update_rod_row()
	_show_tool_unlock_if_needed.call_deferred()
	egg_sell_button.text = tr("UI_SELL_EGG") % Inventory.EGG_PRICE
	dog_buy_button.disabled = Inventory.has_dog
	dog_buy_button.text = tr("UI_OWNED") if Inventory.has_dog else tr("UI_BUY_DOG") % Inventory.DOG_PRICE
	$ShopPanel/Margin/Scroll/ShopContent/PetsLabel.text = tr("UI_PETS") % Inventory.DOG_PRICE
	for i in range(crop_ids.size()):
		var crop: String = crop_ids[i]
		var info: Dictionary = CropData.CROPS[crop]
		var unlocked: bool = Inventory.is_unlocked(crop)
		var choice: String = Localization.display_name(info["name"])
		if not unlocked:
			choice += tr("UI_UNLOCK_LEVEL") % info["unlock_level"]
		crop_selector.set_item_text(i, choice)
		crop_selector.set_item_disabled(i, not unlocked)
		var buy: Button = buy_buttons[crop]
		buy.disabled = not unlocked
		buy.text = tr("UI_BUY_SEED") % [Localization.display_name(info["name"]), info["seed_buy_price"]]
		if not unlocked:
			buy.text += tr("UI_LEVEL_SUFFIX") % info["unlock_level"]
	crop_selector.select(crop_ids.find(Inventory.selected_crop))
	_update_station_panel()
	_update_house_panel()
	if order_panel.visible:
		_refresh_orders()


func _select_crop(index: int) -> void:
	Inventory.select_crop(crop_ids[index])


func _show_reset_confirmation() -> void:
	close_all_panels()
	reset_confirmation.popup_centered()
	reset_confirmation.get_cancel_button().grab_focus()


func _reset_game() -> void:
	if SaveManager.reset_game():
		plot_purchase.hide()
		pending_plot_number = 0
		_close_game_panels()
		message_label.text = ""
		save_status.text = tr("RESET_DONE")
	else:
		save_status.text = tr("RESET_FAILED")


func _toggle_shop() -> void:
	if _native_dialog_open():
		return
	var was_open: bool = shop_panel.visible
	_close_game_panels()
	shop_panel.visible = not was_open
	shop_button.text = tr("UI_SHOP_SHORT")
	message_label.text = ""


func _buy_seed(crop: String = "WHEAT") -> void:
	if Inventory.buy_seed(crop):
		message_label.text = tr("MSG_BOUGHT_SEED") % Localization.display_name(CropData.CROPS[crop]["name"])
	elif not Inventory.is_unlocked(crop):
		message_label.text = tr("MSG_CROP_LOCKED")
	else:
		message_label.text = tr("MSG_COINS_OR_SILO")


func _sell_crop(crop: String) -> void:
	if Inventory.sell_crop(crop):
		message_label.text = tr("MSG_SOLD_CROP") % Localization.display_name(CropData.CROPS[crop]["name"])
	else:
		message_label.text = tr("MSG_NO_CROP") % Localization.display_name(CropData.CROPS[crop]["name"])


func _sell_egg() -> void:
	message_label.text = tr("MSG_SOLD_EGG") if Inventory.sell_egg() else tr("MSG_NO_EGG")


func _buy_dog() -> void:
	if Inventory.buy_dog():
		message_label.text = tr("MSG_DOG_BOUGHT")
	else:
		message_label.text = tr("MSG_DOG_OWNED") if Inventory.has_dog else tr("MSG_NEED_COINS") % Inventory.DOG_PRICE


func open_station(station: Node) -> void:
	if _native_dialog_open() or not is_instance_valid(station) or not station.can_interact():
		return
	_close_game_panels()
	active_station = station
	active_station.state_changed.connect(_update_station_panel)
	shop_panel.hide()
	shop_button.text = tr("UI_SHOP_SHORT")
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
		station_info.text = tr("STATION_MILL_INFO") % [Localization.state(active_station.state), Localization.display_name(info["name"])]
		for item in info["requirements"]:
			station_info.text += tr("STATION_INGREDIENT") % [info["requirements"][item], Localization.display_name(item), Inventory.get(item)]
		station_info.text += tr("STATION_TIME") % [info["time"], info["level"]]
		if active_station.state != "IDLE":
			station_info.text += tr("STATION_BATCH") + Localization.display_name(active_station.production_type)
		for index in range(recipe_ids.size()):
			recipe_selector.set_item_disabled(index, Inventory.player_level < Progression.RECIPES[recipe_ids[index]]["level"])
		produce_button.text = tr("UI_PRODUCE")
		collect_button.text = tr("UI_COLLECT_FEED")
		produce_button.disabled = not active_station.can_produce(recipe) or not active_station.player_near
	else:
		var product: Dictionary = Progression.PRODUCTS[id]
		var animal: String = product["animal"]
		var info: Dictionary = Progression.ANIMALS[animal]
		station_info.text = tr("STATION_ANIMALS_INFO") % [Localization.display_name(Progression.BUILDINGS[id]["name"]), Localization.display_name(info["name"]), Inventory.get(animal + "_count"), Inventory.animal_capacity(animal), Localization.state(active_station.state), Localization.display_name(product["feed"]), Inventory.get(product["feed"]), product["time"], product["level"]]
		produce_button.text = tr("UI_FEED_PREFIX") + Localization.display_name(info["name"])
		collect_button.text = tr("UI_COLLECT_PREFIX") + Localization.display_name(product["item"])
		animal_buy.text = tr("UI_BUY_ANIMAL") % [Localization.display_name(info["name"]), info["buy"]]
		animal_sell.text = tr("UI_SELL_CROP") % [Localization.display_name(info["name"]), info["sell"]]
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
	return storage_panel.visible or fish_market_panel.visible or (is_instance_valid(debug_panel) and debug_panel.visible) or house_panel.visible or plot_purchase.visible or tools_unlock_popup.visible or shop_panel.visible or station_panel.visible or order_panel.visible or build_panel.visible or reset_confirmation.visible or crop_selector.get_popup().visible or recipe_selector.get_popup().visible


func _input(event: InputEvent) -> void:
	# Handle UI keys before any farm node receives _unhandled_input.
	if event.is_action("toggle_inventory"):
		if event.is_action_pressed("toggle_inventory") and not event.is_echo():
			_toggle_storage()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F3 and not event.echo:
		if not _native_dialog_open():
			var was_open: bool = debug_panel.visible
			_close_game_panels()
			debug_panel.visible = not was_open
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if not event.is_echo():
			close_current_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action("interact") and blocks_world_input():
		get_viewport().set_input_as_handled()


func close_current_panel() -> void:
	# Native popup windows sit above the panels. Panel priority matches z_index.
	if reset_confirmation.visible:
		reset_confirmation.hide()
	elif plot_purchase.visible:
		plot_purchase.hide()
	elif storage_panel.visible:
		storage_panel.hide()
	elif tools_unlock_popup.visible:
		tools_unlock_popup.hide()
	elif crop_selector.get_popup().visible:
		crop_selector.get_popup().hide()
	elif recipe_selector.get_popup().visible:
		recipe_selector.get_popup().hide()
	elif is_instance_valid(debug_panel) and debug_panel.visible:
		debug_panel.hide()
	elif fish_market_panel.visible:
		fish_market_panel.close()
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
		shop_button.text = tr("UI_SHOP_SHORT")
	elif is_instance_valid(fishing_ui.active_spot):
		fishing_ui.close_session()


func _close_game_panels() -> void:
	storage_panel.hide()
	fish_market_panel.close()
	fishing_ui.close_session()
	if is_instance_valid(debug_panel):
		debug_panel.hide()
	crop_selector.get_popup().hide()
	recipe_selector.get_popup().hide()
	close_house()
	build_panel.hide()
	close_station()
	order_panel.hide()
	shop_panel.hide()
	shop_button.text = tr("UI_SHOP_SHORT")
	var player = get_tree().get_first_node_in_group("farm_player")
	if player != null and is_instance_valid(player.active_resource):
		player.active_resource.cancel_harvest()


func _native_dialog_open() -> bool:
	return reset_confirmation.visible or plot_purchase.visible or tools_unlock_popup.visible


func _toggle_storage() -> void:
	if _native_dialog_open():
		return
	var was_open: bool = storage_panel.visible
	_close_game_panels()
	storage_panel.visible = not was_open
	if storage_panel.visible:
		storage_panel.refresh()


func open_fish_market(market: Node) -> void:
	if blocks_world_input() or not is_instance_valid(market) or not market.can_interact():
		return
	_close_game_panels()
	fish_market_panel.open(market)


func close_all_panels() -> void:
	_close_game_panels()
	reset_confirmation.hide()
	plot_purchase.hide()
	tools_unlock_popup.hide()


func _on_main_panel_visibility_changed() -> void:
	crop_selector.disabled = storage_panel.visible
	_show_tool_unlock_if_needed.call_deferred()


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
	house_info.text = tr("HOUSE_CURRENT") % Inventory.house_level
	var cost: Dictionary = Inventory.next_upgrade("house")
	house_upgrade_button.disabled = cost.is_empty()
	if cost.is_empty():
		house_info.text += tr("HOUSE_MAX")
		return
	house_info.text += tr("HOUSE_NEXT") % [Inventory.house_level + 1, Inventory.coins, cost["coins"], Inventory.wood, cost["wood"], Inventory.stone, cost["stone"]]


func _upgrade_house() -> void:
	if not house_panel.visible or not is_instance_valid(active_house) or not active_house.can_interact():
		close_house()
		return
	if Inventory.upgrade_structure("house"):
		house_message.text = tr("HOUSE_UPGRADED")
	else:
		house_message.text = tr("UI_MAX_LEVEL") if Inventory.next_upgrade("house").is_empty() else tr("ERROR_RESOURCES")


func open_orders() -> void:
	if _native_dialog_open():
		return
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
		label.text = tr("ORDER_NUMBER") % order["order_id"].trim_prefix("order_") + "\n\n"
		for item in order["requirements"]:
			label.text += tr("ORDER_ITEM") % [Localization.display_name(items[item]["name"]), order["requirements"][item], Inventory.get(item)]
		label.text += tr("ORDER_REWARD") % [order["coin_reward"], order["exp_reward"]]
		content.add_child(label)
		var complete := Button.new()
		complete.name = "Complete"
		complete.text = tr("ORDER_COMPLETE")
		complete.focus_mode = Control.FOCUS_NONE
		complete.pressed.connect(_complete_order.bind(order["order_id"]))
		content.add_child(complete)
		order_cards.add_child(card)


func _complete_order(order_id: String) -> void:
	if OrderManager.complete_order(order_id):
		order_message.text = tr("ORDER_DONE")
	else:
		order_message.text = tr("ERROR_ITEMS")

func _show_message(message: String) -> void:
	save_status.text = message


func _sell_milk() -> void:
	message_label.text = tr("MSG_SOLD_MILK") if Inventory.sell_milk() else tr("MSG_NO_MILK")


func _discard_feed(item: String) -> void:
	if Inventory.discard_feed(item):
		message_label.text = tr("UI_DISCARD_ITEM") + Localization.display_name(item) + "."
	else:
		message_label.text = tr("MSG_NO_FEED")


func _on_recipe_selected(_index: int) -> void:
	_update_station_panel()


func open_build() -> void:
	if _native_dialog_open():
		return
	_close_game_panels()
	build_panel.show()
	_update_build_rows()


func _create_build_rows() -> void:
	for id in Progression.BUILDINGS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size.x = 300
		label.text = Localization.display_name(Progression.BUILDINGS[id]["name"])
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
	heading.text = tr("UI_FARM_UPGRADES")
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
			buy.text = tr("UI_OWNED")
		elif Inventory.player_level < info["level"]:
			buy.text = tr("UI_LOCKED_LEVEL") % info["level"]
		else:
			buy.text = tr("UI_BUY_PRICE") % info["price"]
	for animal in animal_buttons:
		var info: Dictionary = Progression.ANIMALS[animal]
		var row: Dictionary = animal_buttons[animal]
		var count: int = Inventory.get(animal + "_count")
		row["label"].text = "%s | %s: %d / %d" % [Localization.display_name(Progression.BUILDINGS[info["building"]]["name"]), Localization.display_name(info["name"]), count, Inventory.animal_capacity(animal)]
		var locked: bool = Inventory.player_level < info["level"] or not Inventory.owns_building(info["building"])
		var busy: bool = Inventory.animal_trade_busy(animal)
		if busy:
			row["label"].text += tr("UI_COLLECT_BEFORE_TRADE")
		row["buy"].disabled = locked or busy or count >= Inventory.animal_capacity(animal)
		row["buy"].text = tr("UI_ANIMAL_LOCKED") % info["level"] if locked else tr("UI_BUY_ANIMAL_SHORT") % [Localization.display_name(info["name"]), info["buy"]]
		row["sell"].disabled = busy or count <= 0
		row["sell"].text = tr("UI_SELL_ANIMAL") % [Localization.display_name(info["name"]), info["sell"]]


	for id in upgrade_rows:
		var row: Dictionary = upgrade_rows[id]
		var current: int = Inventory.get(id + "_level")
		row["label"].text = tr("UI_STRUCTURE_LEVEL") % [Localization.display_name(id), current]
		var cost: Dictionary = Inventory.next_upgrade(id)
		var owned: bool = id not in Progression.BUILDINGS or Inventory.owns_building(id)
		row["button"].disabled = cost.is_empty() or not owned
		if not owned:
			row["button"].text = tr("UI_BUILDING_FIRST")
		elif cost.is_empty():
			row["button"].text = tr("UI_MAX_LEVEL")
		else:
			row["button"].text = tr("UI_STRUCTURE_UPGRADE") % [current + 1, cost["wood"], cost["stone"], cost["coins"]]
			if cost.has("capacity"):
				row["button"].text += tr("UI_CAPACITY") % cost["capacity"]
	dog_house_button.disabled = Inventory.has_dog_house
	var dog_house_cost: Dictionary = Progression.DOG_HOUSE_COST
	dog_house_button.text = tr("UI_DOG_HOUSE_BUILT") if Inventory.has_dog_house else tr("UI_BUILD_DOG_HOUSE") % [dog_house_cost["wood"], dog_house_cost["stone"]]

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
	title.text = tr("TOOLS_TITLE")
	content.add_child(title)
	for id in ToolData.TOOLS:
		var label := Label.new()
		var button := Button.new()
		button.text = tr("UI_UPGRADE")
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
			row["label"].text = Localization.display_name(info["name"]) + tr("TOOLS_LOCKED")
			row["button"].disabled = true
			row["button"].text = tr("UI_LOCKED")
			continue
		row["label"].text = tr("TOOLS_INFO") % [Localization.display_name(info["name"]), level, Inventory.tool_duration(id)]
		row["button"].disabled = not info["levels"].has(level + 1)
		row["button"].text = tr("UI_UPGRADE_PRICE") % info["levels"][level + 1]["cost"] if info["levels"].has(level + 1) else tr("UI_MAX_LEVEL")


func _upgrade_tool(id: String) -> void:
	Inventory.upgrade_tool(id)


func _on_reset_visibility_changed() -> void:
	if not reset_confirmation.visible:
		_show_tool_unlock_if_needed.call_deferred()


func _show_tool_unlock_if_needed() -> void:
	if Inventory.player_level < ToolData.UNLOCK_LEVEL or Inventory.tools_unlock_notified or blocks_world_input():
		return
	if not Inventory.has_axe or not Inventory.has_hammer:
		return
	tools_unlock_popup.popup_centered()
	fishing_ui.close_session()
	Inventory.tools_unlock_notified = true
	# Deferred notification: never save half of a harvest/order transaction.
	SaveManager.save_game()
func open_plot_purchase(number: int) -> void:
	if _native_dialog_open():
		return
	if number != Inventory.unlocked_plot_count + 1:
		Inventory.fail(tr("PLOT_FIRST") % (Inventory.unlocked_plot_count + 1))
		return
	_close_game_panels()
	pending_plot_number = number
	plot_purchase.dialog_text = tr("PLOT_PRICE") % [number, FarmData.plot_price(number)]
	plot_purchase.popup_centered()


func _confirm_plot_purchase() -> void:
	if Inventory.buy_plot(pending_plot_number):
		plot_purchase.hide()
		save_status.text = tr("PLOT_UNLOCKED")
	else:
		plot_purchase.dialog_text = tr("PLOT_PRICE_ERROR") % [pending_plot_number, FarmData.plot_price(pending_plot_number), save_status.text]


func _on_plot_popup_visibility_changed() -> void:
	if not plot_purchase.visible:
		pending_plot_number = 0
		_show_tool_unlock_if_needed.call_deferred()


func _create_rod_row() -> void:
	var content = $ShopPanel/Margin/Scroll/ShopContent
	rod_info = Label.new()
	rod_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rod_upgrade = Button.new()
	rod_upgrade.focus_mode = Control.FOCUS_NONE
	rod_upgrade.pressed.connect(Inventory.upgrade_fishing_rod)
	content.add_child(rod_info)
	content.add_child(rod_upgrade)


func _update_rod_row() -> void:
	if not Inventory.has_fishing_rod or not Inventory.is_zone_unlocked("fishing"):
		rod_info.text = tr("ROD_LOCKED")
		rod_upgrade.text = tr("UI_LOCKED")
		rod_upgrade.disabled = true
		return
	var level: int = Inventory.fishing_rod_level
	rod_info.text = tr("ROD_INFO") % [level, FishingData.ROD_LEVELS[level]["bite_window"]]
	rod_upgrade.disabled = not FishingData.ROD_LEVELS.has(level + 1)
	rod_upgrade.text = tr("ROD_UPGRADE") % FishingData.ROD_LEVELS[level + 1]["cost"] if not rod_upgrade.disabled else tr("UI_MAX_LEVEL")
