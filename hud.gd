extends CanvasLayer

const FarmData = preload("res://farm_data.gd")
const ToolData = preload("res://tool_data.gd")
const CropData = preload("res://crop_data.gd")
const Progression = preload("res://progression_data.gd")
const FishingData = preload("res://fishing_data.gd")
const DecorationData = preload("res://decoration_data.gd")
const UI_THEME: Theme = preload("res://assets/ui/ui_theme.tres")
@onready var shop_build_panel: PanelContainer = $ShopBuildPanel
@onready var shop_build_tabs: TabContainer = $ShopBuildPanel/Margin/Content/Tabs
var transaction_feedback: VBoxContainer
var bakery_panel: PanelContainer
var market_stall_panel: PanelContainer
var wandering_merchant_panel: PanelContainer
var dairy_panel: PanelContainer
var spinning_machine_panel: PanelContainer
var collection_book: PanelContainer
var edit_farm: Node
var land_panel: PanelContainer
var decoration_panel: ScrollContainer
const ItemCard = preload("res://item_card.gd")
var hotbar: PanelContainer
var sell_buttons: Dictionary = {}
var product_sell_buttons: Dictionary = {}
var shop_cards: Dictionary = {}
var catalog_grids: Array[GridContainer] = []
var catalog_cards: Array[PanelContainer] = []
var item_hints: Array[Label] = []
var item_hint_source: Control
@onready var fishing_ui: Control = $FishingUI
@onready var fish_market_panel: PanelContainer = $FishMarketPanel
@onready var storage_panel: PanelContainer = $StoragePanel
@onready var experience_bar: ProgressBar = $Layout/Experience/ExperienceBar
@onready var experience_value: Label = $Layout/Experience/ExperienceValue
@onready var floating_feedback: Control = $FloatingFeedback
var rod_info: Label
var rod_upgrade: Button

@onready var inventory_label: Label = $Layout/InventoryLabel
var player_name_label: Label
var player_level_label: Label
var coin_count_label: Label
@onready var shop_button: Button = $Layout/Actions/ShopButton
@onready var crop_selector: OptionButton = $Layout/Actions/CropSelector
@onready var save_status: Label = $Layout/SaveStatus
@onready var shop_panel: PanelContainer = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel
@onready var buy_button: Button = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/BuyButton
@onready var sell_button: Button = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/SellButton
@onready var message_label: Label = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/MessageLabel
@onready var reset_button: Button = $SettingsPanel/Margin/Content/ContentScroll/Body/ResetButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var reset_confirmation: ConfirmationDialog = $ResetConfirmation
@onready var animal_sale_confirmation: ConfirmationDialog = $AnimalSaleConfirmation
var pending_sale_animal: Node2D
@onready var egg_sell_button: Button = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/EggSellButton
@onready var dog_buy_button: Button = $ShopBuildPanel/Margin/Content/Tabs/AnimalPanel/Margin/Content/Scroll/Cards/DogBuyButton
@onready var station_panel: PanelContainer = $StationPanel
@onready var station_info: Label = $StationPanel/Margin/Content/ContentScroll/Body/Info
@onready var produce_button: Button = $StationPanel/Margin/Content/ContentScroll/Body/ProduceButton
@onready var collect_button: Button = $StationPanel/Margin/Content/ContentScroll/Body/CollectButton
@onready var feed_queue: VBoxContainer = $StationPanel/Margin/Content/ContentScroll/Body/FeedQueue
var station_layout: Node
var feed_presentation: VBoxContainer
@onready var station_title: Label = $StationPanel/Margin/Content/Title
@onready var order_panel: PanelContainer = $OrderPanel
@onready var order_cards: HBoxContainer = $OrderPanel/Margin/Content/Scroll/Orders
@onready var order_message: Label = $OrderPanel/Margin/Content/Message

var crop_ids: Array = []
var buy_buttons: Dictionary = {}
var active_station: Node = null
var active_house: Node = null
@onready var house_panel: PanelContainer = $HousePanel
@onready var house_info: Label = $HousePanel/Margin/Content/ContentScroll/Body/Info
@onready var house_message: Label = $HousePanel/Margin/Content/ContentScroll/Body/Message
@onready var house_upgrade_button: Button = $HousePanel/Margin/Content/ContentScroll/Body/UpgradeButton
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
@onready var level_up_popup: Control = $LevelUpPopup

@onready var storage_label: Label = $Layout/StorageLabel
@onready var build_panel: PanelContainer = $ShopBuildPanel/Margin/Content/Tabs/BuildPanel
@onready var build_rows: VBoxContainer = $ShopBuildPanel/Margin/Content/Tabs/BuildPanel/Margin/Content/Scroll/Rows
@onready var recipe_selector: OptionButton = $StationPanel/Margin/Content/ContentScroll/Body/RecipeSelector
@onready var animal_panel: PanelContainer = $ShopBuildPanel/Margin/Content/Tabs/AnimalPanel
@onready var animal_cards_grid: GridContainer = $ShopBuildPanel/Margin/Content/Tabs/AnimalPanel/Margin/Content/Scroll/Cards
var dog_status_label: Label


func _ready() -> void:
	add_to_group("farm_hud")
	if not DiscoveryManager.cosmetic_unlocked.is_connected(_on_cosmetic_unlocked):
		DiscoveryManager.cosmetic_unlocked.connect(_on_cosmetic_unlocked)
	collection_book = PanelContainer.new()
	collection_book.name = "CollectionBook"
	collection_book.set_script(preload("res://collection_book.gd"))
	add_child(collection_book)
	land_panel = PanelContainer.new()
	land_panel.name = "LandPurchasePanel"
	land_panel.set_script(preload("res://land_purchase_panel.gd"))
	add_child(land_panel)
	edit_farm = Node.new()
	edit_farm.name = "FarmEditMode"
	edit_farm.set_script(preload("res://farm_edit_mode.gd"))
	add_child(edit_farm)
	get_viewport().size_changed.connect(_fit_order_panel)
	get_viewport().size_changed.connect(_fit_native_popups)
	market_stall_panel = PanelContainer.new()
	market_stall_panel.name = "MarketStallPanel"
	market_stall_panel.z_index = 29
	market_stall_panel.set_script(preload("res://market_stall_panel.gd"))
	add_child(market_stall_panel)
	wandering_merchant_panel = PanelContainer.new()
	wandering_merchant_panel.name = "WanderingMerchantPanel"
	wandering_merchant_panel.z_index = 29
	wandering_merchant_panel.set_script(preload("res://wandering_merchant_panel.gd"))
	add_child(wandering_merchant_panel)
	bakery_panel = PanelContainer.new()
	bakery_panel.name = "BakeryPanel"
	bakery_panel.z_index = 29
	bakery_panel.set_script(preload("res://bakery_panel.gd"))
	add_child(bakery_panel)
	dairy_panel = PanelContainer.new()
	dairy_panel.name = "DairyPanel"
	dairy_panel.z_index = 29
	dairy_panel.set_script(preload("res://dairy_panel.gd"))
	add_child(dairy_panel)
	spinning_machine_panel = PanelContainer.new()
	spinning_machine_panel.name = "SpinningMachinePanel"
	spinning_machine_panel.z_index = 29
	spinning_machine_panel.set_script(preload("res://spinning_machine_panel.gd"))
	add_child(spinning_machine_panel)
	$ResetControls/SettingsButton.pressed.connect(_toggle_settings)
	$SettingsPanel/Margin/Content/Footer/CloseButton.pressed.connect(settings_panel.hide)
	_setup_shop_build()
	if OS.is_debug_build():
		debug_panel = PanelContainer.new()
		debug_panel.z_index = 40
		debug_panel.set_script(preload("res://dev_debug_panel.gd"))
		add_child(debug_panel)
		debug_panel.visibility_changed.connect(_on_main_panel_visibility_changed)
	for panel in [collection_book, market_stall_panel, wandering_merchant_panel, land_panel, bakery_panel, dairy_panel, spinning_machine_panel, settings_panel, shop_build_panel, station_panel, house_panel, order_panel, fish_market_panel, storage_panel, reset_confirmation, animal_sale_confirmation, plot_purchase, tools_unlock_popup, fishing_ui.panel, level_up_popup]:
		panel.visibility_changed.connect(_on_main_panel_visibility_changed)
	DiscoveryManager.discovery_found.connect(_on_discovery_found)
	crop_ids = CropData.CROPS.keys()
	var content: VBoxContainer = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent
	for item in Inventory.DairyData.RECIPES:
		var button := Button.new()
		button.text = tr("UI_SELL_CROP") % [Localization.display_name(item),Inventory.DairyData.RECIPES[item]["price"]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_sell_dairy_item.bind(item))
		content.add_child(button)
		product_sell_buttons[item] = button
	for item in Inventory.BakeryData.RECIPES:
		var button := Button.new()
		button.text = tr("UI_SELL_CROP") % [Localization.display_name(item), Inventory.BakeryData.RECIPES[item]["price"]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_sell_bakery_item.bind(item))
		content.add_child(button)
		product_sell_buttons[item] = button
	for crop in crop_ids:
		crop_selector.add_item(Localization.display_name(CropData.CROPS[crop]["name"]))
		var prefix: String = "" if crop == "WHEAT" else crop.capitalize()
		var buy: Button = content.get_node_or_null(prefix + "BuyButton")
		var sell: Button = content.get_node_or_null(prefix + "SellButton")
		if buy == null:
			buy = Button.new()
			buy.name = prefix + "BuyButton"
			buy.focus_mode = Control.FOCUS_NONE
			content.add_child(buy)
		if sell == null:
			sell = Button.new()
			sell.name = prefix + "SellButton"
			sell.focus_mode = Control.FOCUS_NONE
			content.add_child(sell)
		buy_buttons[crop] = buy
		sell_buttons[crop] = sell
		buy.pressed.connect(_buy_seed.bind(crop))
		sell.pressed.connect(_sell_crop.bind(crop))
		sell.text = tr("UI_SELL_CROP") % [Localization.display_name(CropData.CROPS[crop]["name"]), CropData.CROPS[crop]["sell_price"]]
	crop_selector.add_item(tr("ITEM_MYSTERY_SEED"))
	_create_build_rows()
	_create_tool_rows()
	_create_rod_row()
	house_upgrade_button.pressed.connect(_upgrade_house)
	$HousePanel/Margin/Content/Footer/CloseButton.pressed.connect(close_house)
	recipe_ids = Progression.RECIPES.keys()
	for recipe in recipe_ids:
		recipe_selector.add_item(Localization.display_name(Progression.RECIPES[recipe]["name"]))
	recipe_selector.item_selected.connect(_on_recipe_selected)
	Inventory.action_failed.connect(_show_message)
	$Layout/Actions/BuildButton.pressed.connect(open_build)
	$Layout/Actions/StorageButton.pressed.connect(_toggle_storage)
	$Layout/Actions/OrdersButton.pressed.connect(open_orders)
	$ShopBuildPanel/Margin/Content/Tabs/BuildPanel/Margin/Content/CloseButton.pressed.connect(_close_game_panels)
	$ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/MilkSellButton.pressed.connect(_sell_milk)
	$ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/DiscardChickenFeed.pressed.connect(_discard_feed.bind("chicken_feed"))
	$ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/DiscardCowFeed.pressed.connect(_discard_feed.bind("cow_feed"))
	Inventory.inventory_changed.connect(_update_inventory)
	SaveManager.player_name_changed.connect(_update_inventory)
	shop_button.pressed.connect(_toggle_shop)
	reset_button.pressed.connect(_show_reset_confirmation)
	reset_confirmation.confirmed.connect(_reset_game)
	animal_sale_confirmation.confirmed.connect(_confirm_animal_sale)
	animal_sale_confirmation.visibility_changed.connect(_on_animal_sale_visibility_changed)
	reset_confirmation.visibility_changed.connect(_on_reset_visibility_changed)
	plot_purchase.confirmed.connect(_confirm_plot_purchase)
	plot_purchase.visibility_changed.connect(_on_plot_popup_visibility_changed)
	plot_purchase.get_label().theme_type_variation = &"PlotPurchaseText"
	plot_purchase.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plot_purchase.get_label().vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plot_purchase.get_ok_button().theme_type_variation = &"PurchaseButton"
	plot_purchase.get_cancel_button().theme_type_variation = &"PlotCancelButton"
	crop_selector.item_selected.connect(_select_crop)
	egg_sell_button.pressed.connect(_sell_egg)
	dog_buy_button.pressed.connect(_buy_dog)
	produce_button.pressed.connect(_produce)
	collect_button.pressed.connect(_collect)
	$StationPanel/Margin/Content/Footer/CloseButton.pressed.connect(close_station)
	$OrderPanel/Margin/Content/Footer/CloseButton.pressed.connect(order_panel.hide)
	OrderManager.orders_changed.connect(_refresh_orders)
	OrderManager.order_completed.connect(_on_order_completed)
	_setup_cozy_ui()
	_setup_feed_presentation()
	_apply_ui_theme(self)
	_setup_profile_hud()
	_update_inventory()


func _setup_shop_build() -> void:
	decoration_panel = ScrollContainer.new()
	decoration_panel.name = "DecorationPanel"
	decoration_panel.set_script(preload("res://decoration_catalog.gd"))
	shop_build_tabs.add_child(decoration_panel)
	shop_build_tabs.set_tab_title(2, tr("UI_ANIMALS_SHORT"))
	shop_build_tabs.set_tab_title(3,tr("DECOR_TAB"))
	shop_build_tabs.set_tab_title(0, tr("SHOP_BUILD_SHOP_TAB"))
	shop_build_tabs.set_tab_title(1, tr("SHOP_BUILD_BUILD_TAB"))
	$ShopBuildPanel/Margin/Content/Footer/CloseButton.pressed.connect(_close_game_panels)
	$ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/TitleLabel.hide()
	$ShopBuildPanel/Margin/Content/Tabs/BuildPanel/Margin/Content/Title.hide()
	$ShopBuildPanel/Margin/Content/Tabs/BuildPanel/Margin/Content/CloseButton.hide()
	transaction_feedback = VBoxContainer.new()
	transaction_feedback.set_script(preload("res://transaction_feedback.gd"))
	transaction_feedback.name = "TransactionFeedback"
	transaction_feedback.z_index = 100
	transaction_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(transaction_feedback)
	transaction_feedback.hide()
	get_viewport().size_changed.connect(_fit_shop_build)
	_fit_shop_build.call_deferred()


func _fit_shop_build() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var desired: Vector2 = Vector2(920, 600).min(viewport_size - Vector2(24, 32))
	for grid in catalog_grids:
		grid.columns = maxi(1,int((desired.x-112)/260))
	for card in catalog_cards:
		card.actions.columns = 1 if viewport_size.x < 700 else 2
	shop_build_panel.size = desired
	shop_build_panel.position = (viewport_size - shop_build_panel.size) / 2.0


func _open_shop_build(tab: int) -> void:
	shop_build_panel.show()
	shop_build_tabs.current_tab = tab
	shop_panel.visible = tab == 0
	build_panel.visible = tab == 1
	animal_panel.visible = tab == 2
	decoration_panel.visible = tab == 3
	_fit_shop_build()


func show_transaction_feedback(text: String) -> void:
	transaction_feedback.show_message(text)


func show_floating_feedback(text: String) -> void:
	floating_feedback.show_floating_feedback(text)

func _on_cosmetic_unlocked(decoration_id: String) -> void:
	var data: Dictionary = DecorationData.TYPES.get(decoration_id, {})
	if data.is_empty():
		return
	show_floating_feedback(tr("COLLECTION_COSMETIC_UNLOCK") % tr(data.get("name_key", "")))


func _on_discovery_found(_category_id: String, item_id: String) -> void:
	show_floating_feedback(tr("DISCOVERY_TOAST") % Localization.display_name(item_id))


func open_collection_book() -> void:
	if blocks_world_input() and not settings_panel.visible:
		return
	_close_game_panels()
	collection_book.open()


func show_inventory_change(item_id: String, amount: int) -> void:
	floating_feedback.show_inventory_change(item_id, amount)


func show_harvest_feedback(item_id: String, amount: int = 1, base_crop: String = "") -> void:
	var crop_id: String = base_crop if not base_crop.is_empty() else item_id.to_upper()
	var crop_info: Dictionary = CropData.CROPS.get(crop_id, {})
	var feedback: String = tr("TRADE_ITEM") % [amount, Localization.display_name(item_id)]
	if not crop_info.is_empty():
		feedback += "\n" + tr("HARVEST_EXP_FEEDBACK") % crop_info["harvest_exp"]
	show_transaction_feedback(feedback)


func _sell_bakery_item(item: String) -> void:
	if not _trade(Inventory.sell_bakery_item.bind(item), item, -1):
		show_transaction_feedback(tr("TRADE_NO_ITEM"))


func open_bakery(bakery: Node) -> void:
	if blocks_world_input() or not bakery.can_interact():
		return
	_close_game_panels()
	bakery_panel.open(bakery)

func open_dairy(dairy: Node) -> void:
	if blocks_world_input() or not is_instance_valid(dairy) or not dairy.can_interact():
		return
	_close_game_panels()
	dairy_panel.open(dairy)

func _sell_dairy_item(item: String) -> void:
	if not _trade(Inventory.sell_dairy_item.bind(item),item,-1):
		show_transaction_feedback(tr("TRADE_NO_ITEM"))

func open_spinning_machine(machine: Node) -> void:
	if blocks_world_input() or not is_instance_valid(machine) or not machine.can_interact():
		return
	_close_game_panels()
	spinning_machine_panel.open(machine)


func _trade(action: Callable, item: String, amount: int) -> bool:
	var previous_coins: int = Inventory.coins
	if not action.call():
		return false
	show_transaction_feedback(tr("TRADE_ITEM") % [amount, Localization.display_name(item)] + "\n" + tr("TRADE_COINS") % (Inventory.coins - previous_coins))
	AudioManager.play_sfx("ui_success")
	return true


func _apply_ui_theme(node: Node) -> void:
	if node is Control:
		node.theme = UI_THEME
		node.scale = Vector2.ONE
	elif node is Window:
		node.theme = UI_THEME
	for child in node.get_children():
		_apply_ui_theme(child)



func _setup_profile_hud() -> void:
	inventory_label.hide()

	var layout: VBoxContainer = $Layout
	layout.add_theme_constant_override("separation", 5)

	$StatsBackdrop.offset_bottom = 158.0
	layout.offset_bottom = 148.0

	var header := HBoxContainer.new()
	header.name = "ProfileHeader"
	header.custom_minimum_size.y = 24
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(header)
	layout.move_child(header, 0)

	player_name_label = Label.new()
	player_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name_label.clip_text = true
	player_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	player_name_label.theme_type_variation = &"SectionTitle"
	player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(player_name_label)

	player_level_label = Label.new()
	player_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_level_label.theme_type_variation = &"MutedLabel"
	player_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(player_level_label)

	var coin_row := HBoxContainer.new()
	coin_row.name = "CoinRow"
	coin_row.custom_minimum_size.y = 24
	coin_row.add_theme_constant_override("separation", 6)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(coin_row)
	layout.move_child(coin_row, 1)

	var coin_icon := Control.new()
	coin_icon.custom_minimum_size = Vector2(22, 22)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_icon.set_script(preload("res://item_icon.gd"))
	coin_icon.item_id = "coins"
	coin_row.add_child(coin_icon)

	coin_count_label = Label.new()
	coin_count_label.theme_type_variation = &"CurrencyLabel"
	coin_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_child(coin_count_label)

	$Layout/Experience/Title.theme_type_variation = &"MutedLabel"
	$Layout/Experience/ExperienceValue.theme_type_variation = &"MutedLabel"
	$Layout/Materials/WoodCount.theme_type_variation = &"MutedLabel"
	$Layout/Materials/StoneCount.theme_type_variation = &"MutedLabel"


func _update_inventory() -> void:
	save_status.text = ""
	var display_name := SaveManager.player_name.strip_edges()
	if display_name.is_empty():
		display_name = "Farmer"
	if is_instance_valid(player_name_label):
		player_name_label.text = display_name
	if is_instance_valid(player_level_label):
		player_level_label.text = "Cấp %d" % Inventory.player_level
	if is_instance_valid(coin_count_label):
		coin_count_label.text = _format_number(Inventory.coins)
	$Layout/Materials/WoodCount.text = "%s: %d" % [Localization.display_name("wood"), Inventory.wood]
	$Layout/Materials/StoneCount.text = "%s: %d" % [Localization.display_name("stone"), Inventory.stone]
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
	for i in range(crop_ids.size()):
		var crop: String = crop_ids[i]
		var info: Dictionary = CropData.CROPS[crop]
		var unlocked: bool = Inventory.is_unlocked(crop)
		var choice: String = Localization.display_name(info["name"])
		if not unlocked:
			choice += " | " + tr("CROP_LOCKED_LEVEL") % info["unlock_level"]
		crop_selector.set_item_text(i, choice)
		crop_selector.set_item_disabled(i, not unlocked)
		var buy: Button = buy_buttons[crop]
		buy.disabled = not unlocked
		buy.text = tr("UI_BUY_SEED") % [Localization.display_name(info["name"]), info["seed_buy_price"]]
		if not unlocked:
			buy.text += " | " + tr("CROP_LOCKED_LEVEL") % info["unlock_level"]
	var mystery_index := crop_ids.size()
	crop_selector.set_item_text(mystery_index, tr("ITEM_MYSTERY_SEED") + " (%d)" % Inventory.mystery_seed)
	crop_selector.set_item_disabled(mystery_index, Inventory.mystery_seed <= 0)
	crop_selector.select(mystery_index if Inventory.selected_crop == "MYSTERY" else crop_ids.find(Inventory.selected_crop))
	_refresh_shop_cards()
	_update_station_panel()
	_update_house_panel()
	if order_panel.visible:
		_refresh_orders()


func _select_crop(index: int) -> void:
	if index == crop_ids.size():
		Inventory.select_crop("MYSTERY")
	elif index >= 0 and index < crop_ids.size():
		Inventory.select_crop(crop_ids[index])


func _toggle_settings() -> void:
	if _native_dialog_open():
		return
	var was_open: bool = settings_panel.visible
	_close_game_panels()
	settings_panel.visible = not was_open
	_fit_menu()


func open_animal_sale(animal: Node2D) -> void:
	if blocks_world_input() or not is_instance_valid(animal) or not animal.can_interact():
		return
	if Inventory.animal_trade_busy(animal.animal_type):
		Inventory.fail(tr("ERROR_BUSY_ANIMALS"))
		return
	_close_game_panels()
	pending_sale_animal = animal
	# Keep the selected animal nearby while the player decides.
	animal.rest()
	animal.idle_timer.stop()
	animal.tree_exiting.connect(animal_sale_confirmation.hide)
	animal_sale_confirmation.dialog_text = tr("ANIMAL_SALE_QUESTION") % [Localization.display_name(animal.animal_type), Progression.ANIMALS[animal.animal_type]["sell"]]
	animal_sale_confirmation.get_ok_button().disabled = false
	animal_sale_confirmation.popup_centered_clamped(Vector2i(380,180),0.9)
	animal_sale_confirmation.get_cancel_button().grab_focus()


func _confirm_animal_sale() -> void:
	if not animal_sale_confirmation.visible or not is_instance_valid(pending_sale_animal):
		return
	animal_sale_confirmation.get_ok_button().disabled = true
	# Inventory rechecks busy state and resources at the actual confirmation.
	pending_sale_animal.sell_confirmed()
	animal_sale_confirmation.hide()


func _on_animal_sale_visibility_changed() -> void:
	if animal_sale_confirmation.visible:
		return
	var animal: Node2D = pending_sale_animal
	pending_sale_animal = null
	if is_instance_valid(animal):
		if animal.tree_exiting.is_connected(animal_sale_confirmation.hide):
			animal.tree_exiting.disconnect(animal_sale_confirmation.hide)
		if animal.is_inside_tree() and not animal.sale_pending:
			animal.rest()


func _show_reset_confirmation() -> void:
	close_all_panels()
	reset_confirmation.popup_centered()
	reset_confirmation.get_cancel_button().grab_focus()


func _reset_game() -> void:
	if SaveManager.reset_for_character_selection():
		plot_purchase.hide()
		pending_plot_number = 0
		_close_game_panels()
		message_label.text = ""

		get_tree().change_scene_to_file.call_deferred(
			"res://start_menu.tscn"
		)
	else:
		save_status.text = tr("RESET_FAILED")
		show_transaction_feedback(tr("RESET_FAILED"))


func _toggle_shop() -> void:
	if _native_dialog_open():
		return
	var was_open: bool = shop_build_panel.visible
	_close_game_panels()
	if not was_open:
		_open_shop_build(0)
	shop_button.text = tr("UI_SHOP_SHORT")
	message_label.text = ""


func _buy_seed(crop: String = "WHEAT") -> void:
	if _trade(Inventory.buy_seed.bind(crop), crop.to_lower() + "_seed", 1):
		message_label.text = tr("MSG_BOUGHT_SEED") % Localization.display_name(CropData.CROPS[crop]["name"])
	elif not Inventory.is_unlocked(crop):
		message_label.text = tr("MSG_CROP_LOCKED")
	else:
		message_label.text = tr("MSG_COINS_OR_SILO")
		show_transaction_feedback(tr("TRADE_NO_COINS") if Inventory.coins < CropData.CROPS[crop]["seed_buy_price"] else tr("ERROR_SILO_BUY"))


func _sell_crop(crop: String) -> void:
	if _trade(Inventory.sell_crop.bind(crop), crop.to_lower(), -1):
		message_label.text = tr("MSG_SOLD_CROP") % Localization.display_name(CropData.CROPS[crop]["name"])
	else:
		message_label.text = tr("MSG_NO_CROP") % Localization.display_name(CropData.CROPS[crop]["name"])
		show_transaction_feedback(tr("TRADE_NO_ITEM"))


func _sell_egg() -> void:
	if not _trade(Inventory.sell_egg, "egg", -1):
		show_transaction_feedback(tr("TRADE_NO_ITEM"))


func _buy_dog() -> void:
	if _trade(Inventory.buy_dog, "dog", 1):
		message_label.text = tr("MSG_DOG_BOUGHT")
	else:
		message_label.text = tr("MSG_DOG_OWNED") if Inventory.has_dog else tr("MSG_NEED_COINS") % Inventory.DOG_PRICE
		show_transaction_feedback(tr("MSG_DOG_OWNED") if Inventory.has_dog else tr("TRADE_NO_COINS"))


func open_station(station: Node) -> void:
	if _native_dialog_open() or not is_instance_valid(station) or not station.can_interact():
		return
	_close_game_panels()
	active_station = station
	station_layout.preferred_size = Vector2(900,620) if station.station_id == "feed_mill" else Vector2(480,560)
	active_station.state_changed.connect(_update_station_panel)
	shop_button.text = tr("UI_SHOP_SHORT")
	station_panel.show()
	station_layout.fit()
	_update_station_panel()


func close_station() -> void:
	if is_instance_valid(active_station) and active_station.state_changed.is_connected(_update_station_panel):
		active_station.state_changed.disconnect(_update_station_panel)
	active_station = null
	feed_presentation.bind_machine(null)
	feed_presentation.hide()
	feed_queue.hide()
	station_panel.hide()


func _update_station_panel() -> void:
	if not is_instance_valid(active_station):
		return
	var id: String = active_station.station_id
	var is_mill: bool = id == "feed_mill"
	feed_presentation.visible = is_mill
	station_info.visible = not is_mill
	produce_button.visible = not is_mill
	collect_button.visible = not is_mill
	station_title.text = tr("BUILDING_FEED_MILL") if is_mill else Localization.display_name(Progression.BUILDINGS[id]["name"])
	station_info.add_theme_font_size_override("font_size",14 if is_mill else 16)
	$StationPanel/Margin/Content/ContentScroll/Body.add_theme_constant_override("separation",6 if is_mill else 12)
	recipe_selector.hide()
	feed_queue.visible = is_mill
	if is_mill:
		var recipe: String = recipe_ids[maxi(0, recipe_selector.selected)]
		var info: Dictionary = Progression.RECIPES[recipe]
		station_info.text = tr("FEED_RECIPE_INFO") % info["time"]
		for item in info["requirements"]:
			station_info.text += tr("STATION_INGREDIENT") % [info["requirements"][item], Localization.display_name(item), Inventory.get(item)]
		for index in range(recipe_ids.size()):
			recipe_selector.set_item_disabled(index, Inventory.player_level < Progression.RECIPES[recipe_ids[index]]["level"])
		produce_button.text = tr("FEED_ENQUEUE")
		collect_button.text = tr("FEED_COLLECT_ALL")
		produce_button.disabled = not active_station.can_produce(recipe) or not active_station.player_near
		collect_button.disabled = active_station.outputs.is_empty() or active_station.collecting or not active_station.player_near
		feed_queue.refresh(active_station)
		feed_presentation.bind_machine(active_station)
	else:
		var product: Dictionary = Progression.PRODUCTS[id]
		var animal: String = product["animal"]
		var info: Dictionary = Progression.ANIMALS[animal]
		station_info.text = tr("STATION_ANIMALS_INFO") % [Localization.display_name(Progression.BUILDINGS[id]["name"]), Localization.display_name(info["name"]), Inventory.get(animal + "_count"), Inventory.animal_capacity(animal), Localization.state(active_station.state), Localization.display_name(product["feed"]), Inventory.get(product["feed"]), product["time"], product["level"]]
		produce_button.text = tr("UI_FEED_PREFIX") + Localization.display_name(info["name"])
		collect_button.text = tr("UI_COLLECT_PREFIX") + Localization.display_name(product["item"])
		produce_button.disabled = not active_station.can_produce() or not active_station.player_near
	if not is_mill:
		feed_presentation.bind_machine(null)
		collect_button.disabled = active_station.state != "READY" or not active_station.player_near

func _setup_feed_presentation() -> void:
	feed_presentation = VBoxContainer.new()
	feed_presentation.set_script(preload("res://production_ui.gd"))
	feed_presentation.machine_kind = "feed_mill"
	feed_presentation.recipe_data = Progression.RECIPES
	feed_presentation.queue_view = feed_queue
	$StationPanel/Margin/Content/ContentScroll/Body.add_child(feed_presentation)
	feed_presentation.hide()
	var header := HBoxContainer.new()
	$StationPanel/Margin/Content.add_child(header)
	$StationPanel/Margin/Content.move_child(header,0)
	station_title.reparent(header,false)
	station_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = tr("UI_CLOSE")
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(36,36)
	close.pressed.connect(close_station)
	header.add_child(close)

func _produce() -> void:
	if is_instance_valid(active_station) and active_station.player_near:
		active_station.produce(recipe_ids[maxi(0, recipe_selector.selected)])


func _collect() -> void:
	if is_instance_valid(active_station) and active_station.player_near:
		collect_button.disabled = true
		active_station.collect()
		_update_station_panel()


func blocks_world_input() -> bool:
	return level_up_popup.visible or collection_book.visible or market_stall_panel.visible or wandering_merchant_panel.visible or animal_sale_confirmation.visible or land_panel.visible or edit_farm.active or bakery_panel.visible or dairy_panel.visible or spinning_machine_panel.visible or settings_panel.visible or shop_build_panel.visible or storage_panel.visible or fish_market_panel.visible or (is_instance_valid(debug_panel) and debug_panel.visible) or house_panel.visible or plot_purchase.visible or tools_unlock_popup.visible or station_panel.visible or order_panel.visible or reset_confirmation.visible or crop_selector.get_popup().visible or recipe_selector.get_popup().visible


func _input(event: InputEvent) -> void:
	# Handle UI keys before any farm node receives _unhandled_input.
	if level_up_popup.visible:
		if event is InputEventKey and (
			event.is_action_pressed("ui_cancel")
			or event.is_action("toggle_shop_build")
			or event.is_action("toggle_inventory")
			or event.is_action("interact")
		):
			# Do not let gameplay shortcuts dismiss or open panels over a reward.
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_MIDDLE]:
			get_viewport().set_input_as_handled()
			return
	if edit_farm.active:
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			edit_farm.cancel_or_exit()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("rotate_placement") and not event.is_echo():
			edit_farm.rotate_preview()
			get_viewport().set_input_as_handled()
		elif event.is_action("interact") or event.is_action("toggle_shop_build") or event.is_action("toggle_inventory") or (event is InputEventKey and event.keycode == KEY_F3):
			get_viewport().set_input_as_handled()
		return
	if event.is_action("toggle_shop_build"):
		if event.is_action_pressed("toggle_shop_build") and not event.is_echo():
			_toggle_shop()
		get_viewport().set_input_as_handled()
	elif event.is_action("toggle_inventory"):
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
	if level_up_popup.visible:
		return
	elif collection_book.visible:
		collection_book.close()
	elif animal_sale_confirmation.visible:
		animal_sale_confirmation.hide()
	elif reset_confirmation.visible:
		reset_confirmation.hide()
	elif plot_purchase.visible:
		plot_purchase.hide()
	elif land_panel.visible:
		land_panel.close()
	elif settings_panel.visible:
		settings_panel.hide()
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
	elif market_stall_panel.visible:
		market_stall_panel.close()
	elif wandering_merchant_panel.visible:
		wandering_merchant_panel.close()
	elif bakery_panel.visible:
		bakery_panel.close()
	elif dairy_panel.visible:
		dairy_panel.close()
	elif spinning_machine_panel.visible:
		spinning_machine_panel.close()
	elif house_panel.visible:
		close_house()
	elif order_panel.visible:
		order_panel.hide()
	elif shop_build_panel.visible:
		_close_game_panels()
	elif station_panel.visible:
		close_station()
	elif is_instance_valid(fishing_ui.active_spot):
		fishing_ui.close_session()


func _close_game_panels() -> void:
	collection_book.close()
	market_stall_panel.close()
	wandering_merchant_panel.close()
	animal_sale_confirmation.hide()
	land_panel.close()
	bakery_panel.close()
	dairy_panel.close()
	spinning_machine_panel.close()
	settings_panel.hide()
	shop_build_panel.hide()
	storage_panel.hide()
	fish_market_panel.close()
	fishing_ui.close_session()
	if is_instance_valid(debug_panel):
		debug_panel.hide()
	crop_selector.get_popup().hide()
	recipe_selector.get_popup().hide()
	close_house()
	close_station()
	order_panel.hide()
	shop_button.text = tr("UI_SHOP_SHORT")
	var player = get_tree().get_first_node_in_group("farm_player")
	if player != null and is_instance_valid(player.active_resource):
		player.active_resource.cancel_harvest()


func _native_dialog_open() -> bool:
	return level_up_popup.visible or collection_book.visible or animal_sale_confirmation.visible or edit_farm.active or reset_confirmation.visible or plot_purchase.visible or tools_unlock_popup.visible


func open_land_purchase(id: String) -> void:
	if blocks_world_input() or not SaveManager.LandData.ZONES.has(id) or id in SaveManager.unlocked_land_zones:
		return
	_close_game_panels()
	land_panel.open(id)


func open_warehouse(warehouse: Node) -> void:
	if not is_instance_valid(warehouse) or blocks_world_input() or not warehouse.can_interact():
		return
	_toggle_storage()


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

func open_market_stall(stall: Node) -> void:
	if blocks_world_input() or not is_instance_valid(stall) or not stall.can_interact():
		return
	_close_game_panels()
	market_stall_panel.open(stall)

func open_wandering_merchant(merchant: Node) -> void:
	if blocks_world_input() or not is_instance_valid(merchant) or not merchant.can_interact():
		return
	_close_game_panels()
	wandering_merchant_panel.open(merchant)


func close_all_panels() -> void:
	if edit_farm.active:
		edit_farm.exit_mode()
	_close_game_panels()
	reset_confirmation.hide()
	plot_purchase.hide()
	tools_unlock_popup.hide()


func _on_main_panel_visibility_changed() -> void:
	clear_item_hint(item_hint_source)
	# A HUD dropdown must not stack over an existing modal or fishing session.
	crop_selector.disabled = _native_dialog_open() or fishing_ui.panel.visible or [collection_book, market_stall_panel, wandering_merchant_panel, land_panel, bakery_panel, dairy_panel, spinning_machine_panel, settings_panel, shop_build_panel, station_panel, house_panel, order_panel, fish_market_panel, storage_panel].any(func(panel): return panel.visible) or (is_instance_valid(debug_panel) and debug_panel.visible)
	if is_instance_valid(hotbar):
		hotbar.visible = not crop_selector.disabled
	$ModalBackdrop.visible = crop_selector.disabled and not edit_farm.active and not fishing_ui.panel.visible and not level_up_popup.visible
	# z_index controls drawing, not GUI picking. Keep the active panel after
	# the backdrop and hotbar in tree order so its tabs/buttons receive clicks.
	for panel in [collection_book,market_stall_panel,wandering_merchant_panel,land_panel,bakery_panel,dairy_panel,spinning_machine_panel,settings_panel,shop_build_panel,station_panel,house_panel,order_panel,fish_market_panel,storage_panel,debug_panel,level_up_popup]:
		if is_instance_valid(panel) and panel.visible:
			move_child(panel,get_child_count()-1)
	transaction_feedback.set_popup_mode($ModalBackdrop.visible)
	# Stall sales keep the existing small text above the player's screen position,
	# visible even when the compact sale panel overlaps that position.
	floating_feedback.z_index = order_panel.z_index+1 if order_panel.visible else (market_stall_panel.z_index+1 if market_stall_panel.visible else (wandering_merchant_panel.z_index+1 if wandering_merchant_panel.visible else 17))
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
	house_info.text += "\n" + tr("HOUSE_STORAGE_BONUS") % Inventory.house_storage_bonus()
	var cost: Dictionary = Inventory.next_upgrade("house")
	house_upgrade_button.disabled = cost.is_empty()
	if cost.is_empty():
		house_info.text += tr("HOUSE_MAX")
		return
	var next_bonus: int = Inventory.house_storage_bonus(Inventory.house_level + 1)
	house_info.text += tr("HOUSE_NEXT") % [Inventory.house_level + 1, Inventory.coins, cost["coins"], Inventory.wood, cost["wood"], Inventory.stone, cost["stone"]]
	house_info.text += "\n" + tr("HOUSE_NEXT_STORAGE_BONUS") % next_bonus


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
	_fit_order_panel()


func _fit_order_panel() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	order_panel.size = Vector2(860, 560).min(viewport_size - Vector2(32, 32))
	order_panel.position = (viewport_size - order_panel.size) / 2.0


func _refresh_orders() -> void:
	for index in range(OrderManager.orders.size()):
		if order_cards.get_child_count() <= index:
			var card := PanelContainer.new()
			card.set_script(preload("res://order_card.gd"))
			order_cards.add_child(card)
			card.deliver_requested.connect(_complete_order)
			card.cancel_requested.connect(_cancel_order)
		order_cards.get_child(index).refresh(OrderManager.orders[index])


func _complete_order(order_id: String) -> void:
	if OrderManager.complete_order(order_id):
		order_message.text = ""
	else:
		order_message.text = tr("ERROR_ITEMS")

func _cancel_order(order_id: String) -> void:
	if OrderManager.cancel_order(order_id):
		order_message.text = ""

func _on_order_completed(_coins: int, experience: int) -> void:
	# Coin changes already use the shared Inventory floating feedback.
	AudioManager.play_sfx("ui_success")
	if experience > 0:
		show_floating_feedback(tr("ORDER_EXP_FEEDBACK") % experience)

func _show_message(message: String) -> void:
	save_status.text = message
	show_transaction_feedback(message)


func _sell_milk() -> void:
	if not _trade(Inventory.sell_milk, "milk", -1):
		show_transaction_feedback(tr("TRADE_NO_ITEM"))


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
	_open_shop_build(1)
	_update_build_rows()


func _create_build_rows() -> void:
	var edit_button := Button.new()
	edit_button.name = "EditFarmButton"
	edit_button.text = tr("EDIT_FARM")
	edit_button.focus_mode = Control.FOCUS_NONE
	edit_button.pressed.connect(edit_farm.enter_mode)
	build_rows.add_child(edit_button)
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
		var label := Label.new()
		var buy := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		buy.pressed.connect(_buy_animal.bind(animal))
		animal_buttons[animal] = {"label": label, "buy": buy}


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
		row["label"].text = "%d / %d" % [count, Inventory.animal_capacity(animal)]
		var locked: bool = Inventory.player_level < info["level"] or not Inventory.owns_building(info["building"])
		var busy: bool = Inventory.animal_trade_busy(animal)
		if busy:
			row["label"].text += tr("UI_COLLECT_BEFORE_TRADE")
		row["buy"].disabled = locked or busy or count >= Inventory.animal_capacity(animal)
		row["buy"].text = tr("UI_LOCKED_LEVEL") % info["level"] if locked else tr("UI_BUY_COMPACT") % info["buy"]
	if is_instance_valid(dog_status_label):
		dog_status_label.text = tr("UI_OWNED") if Inventory.has_dog else tr("UI_PRICE_COINS") % Inventory.DOG_PRICE


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
			row["button"].text = tr("UI_UPGRADE")
			row["label"].text += "\n" + tr("UI_UPGRADE_MATERIALS_OWNED") % [Inventory.wood,cost["wood"],Inventory.stone,cost["stone"],Inventory.coins,cost["coins"]]
			if cost.has("capacity"):
				row["label"].text += tr("UI_CAPACITY_NEXT") % [Inventory.structure_capacity(id),cost["capacity"]]
			elif id == "house":
				row["label"].text += "\n" + tr("HOUSE_NEXT_STORAGE_BONUS") % Inventory.house_storage_bonus(current + 1)
	dog_house_button.disabled = Inventory.has_dog_house
	var dog_house_cost: Dictionary = Progression.DOG_HOUSE_COST
	dog_house_button.text = tr("UI_OWNED") if Inventory.has_dog_house else tr("UI_DOG_HOUSE_COMPACT") % dog_house_cost["wood"]

func _buy_building(id: String) -> void:
	if Progression.BUILDINGS[id].get("placement_required",false):
		edit_farm.begin_building_placement(id)
		return
	_trade(Inventory.buy_building.bind(id), id, 1)


func _buy_animal(animal: String) -> void:
	_trade(Inventory.buy_animal.bind(animal), animal, 1)


func _upgrade_structure(id: String) -> void:
	Inventory.upgrade_structure(id)


func _build_dog_house() -> void:
	Inventory.build_dog_house()
func _create_tool_rows() -> void:
	var content: VBoxContainer = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent
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
	plot_purchase.popup_centered_clamped(Vector2i(380,180),0.9)


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
	var content = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent
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


func _setup_cozy_ui() -> void:
	hotbar = PanelContainer.new()
	hotbar.name = "Hotbar"
	hotbar.set_script(preload("res://hotbar.gd"))
	add_child(hotbar)
	hotbar.visible = not storage_panel.visible
	var menu: VBoxContainer = $SettingsPanel/Margin/Content/ContentScroll/Body
	var audio_controls := VBoxContainer.new()
	audio_controls.name = "AudioSettings"
	audio_controls.set_script(preload("res://audio_settings_controls.gd"))
	menu.add_child(audio_controls)
	var shortcuts: Array = [
		["UI_MENU_SHOP",_toggle_shop], ["UI_MENU_STORAGE",_toggle_storage],
		["UI_MENU_ORDERS",open_orders], ["COLLECTION_TITLE",open_collection_book]
	]
	for i in range(shortcuts.size()):
		var button := Button.new()
		button.text = tr(shortcuts[i][0])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(shortcuts[i][1])
		menu.add_child(button)
		menu.move_child(button,i)
	for entry in [[station_panel,Vector2(480,560)],[house_panel,Vector2(460,460)],[fish_market_panel,Vector2(500,560)]]:
		var layout = preload("res://popup_layout.gd").new()
		if entry[0] == station_panel:
			station_layout = layout
		layout.preferred_size = entry[1]
		entry[0].add_child(layout)
	get_viewport().size_changed.connect(_fit_menu)
	_setup_shop_cards()
	_setup_build_cards()
	_setup_animal_cards()
	_setup_item_hints()
	_fit_menu.call_deferred()
	_fit_shop_build.call_deferred()


func _fit_menu() -> void:
	settings_panel.size = Vector2(390,510).min(get_viewport().get_visible_rect().size-Vector2(24,32))
	settings_panel.position = (get_viewport().get_visible_rect().size-settings_panel.size)/2


func _fit_native_popups() -> void:
	for entry in [[animal_sale_confirmation,Vector2i(380,180)],[plot_purchase,Vector2i(380,180)],[reset_confirmation,Vector2i(360,180)],[tools_unlock_popup,Vector2i(430,250)]]:
		if entry[0].visible:
			entry[0].popup_centered_clamped(entry[1],0.9)


func _catalog(parent: Control, title: String) -> GridContainer:
	var heading := Label.new()
	heading.text = title
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size",18)
	parent.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	parent.add_child(grid)
	catalog_grids.append(grid)
	return grid


func _card(parent: GridContainer, id: String, title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.set_script(ItemCard)
	parent.add_child(card)
	card.build(id,title)
	catalog_cards.append(card)
	return card


func _setup_shop_cards() -> void:
	var content: VBoxContainer = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent
	content.add_theme_constant_override("separation",14)
	for child in content.get_children():
		child.hide()
	var seeds: GridContainer = _catalog(content,tr("UI_SHOP_SEEDS"))
	for crop in crop_ids:
		var id: String = crop.to_lower()+"_seed"
		var card = _card(seeds,id,Localization.display_name(crop))
		card.add_action(buy_buttons[crop])
		card.add_action(sell_buttons[crop])
		shop_cards[id] = card
	var goods: GridContainer = _catalog(content,tr("UI_SHOP_GOODS"))
	product_sell_buttons["egg"] = egg_sell_button
	product_sell_buttons["milk"] = $ShopBuildPanel/Margin/Content/Tabs/ShopPanel/Margin/Scroll/ShopContent/MilkSellButton
	for item in product_sell_buttons:
		var card = _card(goods,item,Localization.display_name(item))
		card.add_action(product_sell_buttons[item])
		shop_cards[item] = card
	for item in ["chicken_feed","cow_feed"]:
		var card = _card(goods,item,Localization.display_name(item))
		var button: Button = content.get_node("DiscardChickenFeed" if item == "chicken_feed" else "DiscardCowFeed")
		button.text = tr("UI_DISCARD_COMPACT")
		card.add_action(button)
		shop_cards[item] = card
	var tools: GridContainer = _catalog(content,tr("UI_TOOLS_SHORT"))
	for id in tool_rows:
		var card = _card(tools,id,Localization.display_name(id))
		card.add_action(tool_rows[id]["button"])
		shop_cards[id] = card
	var rod_card = _card(tools,"fishing_rod",Localization.display_name("fishing_rod"))
	rod_card.add_action(rod_upgrade)
	shop_cards["fishing_rod"] = rod_card
	message_label.show()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.move_child(message_label,content.get_child_count()-1)


func _refresh_shop_cards() -> void:
	for id in shop_cards:
		var card = shop_cards[id]
		if id.ends_with("_seed"):
			var crop: String = id.trim_suffix("_seed").to_upper()
			var info: Dictionary = CropData.CROPS[crop]
			card.stats.text = tr("UI_SEED_CROP_COUNTS") % [Inventory.seed_count(crop),Inventory.crop_count(crop)]
			buy_buttons[crop].text = tr("UI_BUY_COMPACT") % info["seed_buy_price"]
			sell_buttons[crop].text = tr("UI_SELL_COMPACT") % info["sell_price"]
			if not Inventory.is_unlocked(crop):
				buy_buttons[crop].text = tr("UI_LOCKED")
				card.stats.text = tr("CROP_LOCKED_LEVEL") % info["unlock_level"]
		elif id in tool_rows:
			card.stats.text = tool_rows[id]["label"].text
		elif id == "fishing_rod":
			card.stats.text = rod_info.text
		else:
			card.stats.text = tr("UI_ITEM_COUNT") % Inventory.get(id)
			if id in product_sell_buttons:
				var price: int = Inventory.EGG_PRICE if id == "egg" else Inventory.MILK_PRICE
				if Inventory.BakeryData.RECIPES.has(id):
					price = Inventory.BakeryData.RECIPES[id]["price"]
				elif Inventory.DairyData.RECIPES.has(id):
					price = Inventory.DairyData.RECIPES[id]["price"]
				product_sell_buttons[id].text = tr("UI_SELL_COMPACT") % price
		if item_hint_source == card:
			card._show_hint()


func _use_card_label(card: PanelContainer, label: Label) -> void:
	var container: VBoxContainer = card.get_child(0)
	container.remove_child(card.stats)
	card.stats.queue_free()
	if label.get_parent() == null:
		container.add_child(label)
	else:
		label.reparent(container)
	label.custom_minimum_size.x = 0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.move_child(label,1)
	label.show()
	card.stats = label


func _setup_build_cards() -> void:
	for child in build_rows.get_children():
		if child.name != "EditFarmButton":
			child.hide()
	var buildings: GridContainer = _catalog(build_rows,tr("UI_BUILD_SHORT"))
	for id in building_buttons:
		var card = _card(buildings,id,Localization.display_name(id))
		card.stats.hide()
		card.add_action(building_buttons[id])
	var upgrades: GridContainer = _catalog(build_rows,tr("UI_FARM_UPGRADES"))
	for id in upgrade_rows:
		var card = _card(upgrades,id,Localization.display_name(id))
		_use_card_label(card,upgrade_rows[id]["label"])
		card.add_action(upgrade_rows[id]["button"])
	var dog_house = _card(upgrades,"dog_house",Localization.display_name("dog_house"))
	dog_house.stats.hide()
	dog_house.add_action(dog_house_button)


func _setup_animal_cards() -> void:
	for id in animal_buttons:
		var card = _card(animal_cards_grid, id, Localization.display_name(id))
		_use_card_label(card, animal_buttons[id]["label"])
		card.add_action(animal_buttons[id]["buy"])
	var dog_card = _card(animal_cards_grid, "dog", Localization.display_name("dog"))
	dog_status_label = Label.new()
	dog_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_use_card_label(dog_card, dog_status_label)
	dog_card.add_action(dog_buy_button)
	catalog_grids.append(animal_cards_grid)


func _setup_item_hints() -> void:
	for panel in [storage_panel,shop_build_panel]:
		var content: VBoxContainer = panel.get_node("Margin/Content")
		var hint := Label.new()
		hint.name = "ItemHint"
		hint.custom_minimum_size.y = 22
		hint.clip_text = true
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size",14)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(hint)
		content.move_child(hint,content.get_node("Footer").get_index())
		item_hints.append(hint)


func has_item_hint_area() -> bool:
	return storage_panel.visible or shop_build_panel.visible


func show_item_hint(source: Control, message: String) -> void:
	item_hint_source = source
	for hint in item_hints:
		hint.text = message.replace("\n"," · ") if hint.is_visible_in_tree() else ""



func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result

func clear_item_hint(source: Control) -> void:
	if source != item_hint_source:
		return
	item_hint_source = null
	for hint in item_hints:
		hint.text = ""
