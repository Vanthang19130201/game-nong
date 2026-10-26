extends PanelContainer

@onready var tabs: TabContainer = $Margin/Content/Tabs
var upgrade_rows: Dictionary = {}

func _ready() -> void:
	_create_upgrade_rows()
	Inventory.inventory_changed.connect(refresh)
	$Margin/Content/CloseButton.pressed.connect(hide)
	get_viewport().size_changed.connect(_fit_viewport)
	tabs.get_tab_bar().custom_minimum_size.y = 48
	refresh()
	_fit_viewport.call_deferred()


func _fit_viewport() -> void:
	size = Vector2(600, 600).min(get_viewport_rect().size - Vector2(24, 32))
	position = (get_viewport_rect().size - size) / 2.0


func refresh() -> void:
	tabs.set_tab_title(0, tr("STORAGE_PRODUCE"))
	tabs.set_tab_title(1, tr("STORAGE_GOODS"))
	tabs.set_tab_title(2, tr("STORAGE_MATERIALS"))
	var produce: String = tr("STORAGE_CAPACITY") % [tr("BUILDING_SILO"), Inventory.storage_used("silo"), Inventory.silo_capacity]
	produce += "\n\n" + tr("STORAGE_SEEDS")
	for crop in Inventory.CropData.CROPS:
		produce += "\n" + _item_line(crop.to_lower() + "_seed", Localization.display_name(crop))
	produce += "\n\n" + tr("STORAGE_CROPS")
	for crop in Inventory.CropData.CROPS:
		produce += "\n" + _item_line(crop.to_lower())
	$Margin/Content/Tabs/Produce/Items.text = produce
	var goods: String = tr("STORAGE_CAPACITY") % [tr("BUILDING_BARN"), Inventory.storage_used("barn"), Inventory.barn_capacity]
	goods += "\n"
	for item in Inventory.BARN_ITEMS:
		goods += "\n" + _item_line(item)
	$Margin/Content/Tabs/Goods/Items.text = goods
	$Margin/Content/Tabs/Materials/Items.text = _item_line("wood") + "\n" + _item_line("stone")
	_refresh_upgrades()


func _create_upgrade_rows() -> void:
	var upgrades := VBoxContainer.new()
	upgrades.name = "StorageUpgrades"
	upgrades.add_theme_constant_override("separation", 12)
	var content: VBoxContainer = $Margin/Content
	content.add_child(upgrades)
	content.move_child(upgrades, $Margin/Content/CloseButton.get_index())
	for storage in ["silo", "barn"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.custom_minimum_size.x = 140
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var button := Button.new()
		button.text = tr("UI_UPGRADE")
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(116, 44)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_upgrade.bind(storage))
		row.add_child(button)
		upgrades.add_child(row)
		upgrade_rows[storage] = {"label": label, "button": button}


func _refresh_upgrades() -> void:
	for storage in upgrade_rows:
		var cost: Dictionary = Inventory.next_upgrade(storage)
		var level: int = Inventory.get(storage + "_level")
		var capacity: int = Inventory.get(storage + "_capacity")
		var title: String = tr("WAREHOUSE_SILO") if storage == "silo" else tr("WAREHOUSE_BARN")
		var label: Label = upgrade_rows[storage]["label"]
		label.text = tr("WAREHOUSE_UPGRADE_INFO") % [title, level, capacity, maxi(capacity, cost.get("capacity", capacity))]
		upgrade_rows[storage]["button"].disabled = cost.is_empty()
		if cost.is_empty():
			label.text += "\n" + tr("UI_MAX_LEVEL")
		else:
			label.text += "\n" + tr("WAREHOUSE_UPGRADE_COST") % [Inventory.wood, cost["wood"], Inventory.stone, cost["stone"], Inventory.coins, cost["coins"]]


func _upgrade(storage: String) -> void:
	Inventory.upgrade_structure(storage)


func _item_line(item: String, display_name: String = "") -> String:
	return tr("STORAGE_ITEM") % [Localization.display_name(item) if display_name.is_empty() else display_name, Inventory.get(item)]
