extends PanelContainer

@onready var tabs: TabBar = $Margin/Content/TabBar
@onready var content_scroll: ScrollContainer = $Margin/Content/ContentScroll
@onready var pages: VBoxContainer = $Margin/Content/ContentScroll/Items
var upgrade_rows: Dictionary = {}
const Slot = preload("res://item_slot.gd")
var item_cells: Dictionary = {}
var grids: Array[GridContainer] = []
var capacity_labels: Dictionary = {}
var upgrade_grid: GridContainer

func _ready() -> void:
	for title in ["STORAGE_PRODUCE","STORAGE_GOODS","STORAGE_MATERIALS"]:
		tabs.add_tab(tr(title))
	tabs.tab_changed.connect(_show_tab)
	_create_item_grids()
	_create_upgrade_rows()
	Inventory.inventory_changed.connect(refresh)
	$Margin/Content/Footer/CloseButton.pressed.connect(hide)
	get_viewport().size_changed.connect(_fit_viewport)
	refresh()
	_show_tab(tabs.current_tab)
	_fit_viewport.call_deferred()


func _fit_viewport() -> void:
	var desired: Vector2 = Vector2(780,640).min(get_viewport_rect().size-Vector2(24,32))
	for grid in grids:
		grid.columns = maxi(3,int((desired.x-104)/76))
	upgrade_grid.columns = 2 if desired.x >= 700 else 1
	size = desired
	position = (get_viewport_rect().size - size) / 2.0
	_refresh_upgrades()


func _show_tab(index: int) -> void:
	for i in range(pages.get_child_count()):
		pages.get_child(i).visible = i == index
	content_scroll.scroll_vertical = 0


func refresh() -> void:
	tabs.set_tab_title(0, tr("STORAGE_PRODUCE"))
	tabs.set_tab_title(1, tr("STORAGE_GOODS"))
	tabs.set_tab_title(2, tr("STORAGE_MATERIALS"))
	for storage in capacity_labels:
		capacity_labels[storage].text = tr("STORAGE_CAPACITY") % [tr("BUILDING_SILO") if storage == "silo" else tr("BUILDING_BARN"),Inventory.storage_used(storage),Inventory.get(storage+"_capacity")]
	for id in item_cells:
		var locked: bool = id.ends_with("_seed") and not Inventory.is_unlocked(id.trim_suffix("_seed").to_upper())
		var hint: String = tr("SEED_SELECT_HINT") if id.ends_with("_seed") else ""
		if locked:
			hint = tr("CROP_LOCKED_LEVEL") % Inventory.CropData.CROPS[id.trim_suffix("_seed").to_upper()]["unlock_level"]
		item_cells[id].display(id,Inventory.get(id),locked,hint)
		item_cells[id].highlight(id == Inventory.selected_crop.to_lower()+"_seed")
	_refresh_upgrades()


func _create_item_grids() -> void:
	var produce: VBoxContainer = $Margin/Content/ContentScroll/Items/Produce
	var goods: VBoxContainer = $Margin/Content/ContentScroll/Items/Goods
	for storage in ["silo","barn"]:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(produce if storage == "silo" else goods).add_child(label)
		capacity_labels[storage] = label
	var seeds: Array[String] = []
	var crops: Array[String] = []
	for crop in Inventory.CropData.CROPS:
		seeds.append(crop.to_lower()+"_seed")
		crops.append(crop.to_lower())
	_add_grid(produce,tr("STORAGE_SEEDS"),seeds)
	_add_grid(produce,tr("STORAGE_CROPS"),crops)
	_add_grid(goods,"",Inventory.BARN_ITEMS)
	_add_grid($Margin/Content/ContentScroll/Items/Materials,"",["wood","stone"])


func _add_grid(parent: VBoxContainer, heading: String, items: Array) -> void:
	if not heading.is_empty():
		var label := Label.new()
		label.text = heading
		parent.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	parent.add_child(grid)
	grids.append(grid)
	for item in items:
		var slot := Button.new()
		slot.set_script(Slot)
		slot.name = item
		slot.custom_minimum_size = Vector2(64,64)
		grid.add_child(slot)
		item_cells[item] = slot
		if item.ends_with("_seed"):
			slot.pressed.connect(_choose_seed.bind(item.trim_suffix("_seed").to_upper()))
		else:
			slot.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _choose_seed(crop: String) -> void:
	get_parent().hotbar.choose_seed(crop)


func _create_upgrade_rows() -> void:
	var upgrades := GridContainer.new()
	upgrade_grid = upgrades
	upgrades.name = "StorageUpgrades"
	upgrades.add_theme_constant_override("h_separation",24)
	upgrades.add_theme_constant_override("v_separation",12)
	var content: VBoxContainer = $Margin/Content
	content.add_child(upgrades)
	content.move_child(upgrades, $Margin/Content/ContentGap.get_index())
	for storage in ["silo", "barn"]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		button.mouse_entered.connect(func(): get_parent().show_item_hint(button,button.get_meta("hint","")))
		button.mouse_exited.connect(func(): get_parent().clear_item_hint(button))
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
			upgrade_rows[storage]["button"].set_meta("hint",tr("UI_MAX_LEVEL"))
		else:
			var details: String = tr("WAREHOUSE_UPGRADE_COST") % [Inventory.wood,cost["wood"],Inventory.stone,cost["stone"],Inventory.coins,cost["coins"]]
			upgrade_rows[storage]["button"].set_meta("hint",details)
			# Keep the item list and 80 px footer usable on narrow windows.
			if size.x >= 700 and get_viewport_rect().size.y >= 540:
				label.text += "\n"+details


func _upgrade(storage: String) -> void:
	Inventory.upgrade_structure(storage)
