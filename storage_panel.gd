extends PanelContainer

@onready var tabs: TabBar = $Margin/Content/TabBar
@onready var content_scroll: ScrollContainer = $Margin/Content/ContentScroll
@onready var pages: VBoxContainer = $Margin/Content/ContentScroll/Items
var upgrade_rows: Dictionary = {}
const Slot = preload("res://item_slot.gd")
const Icon = preload("res://item_icon.gd")
const TAB_ICONS: Array[Texture2D] = [preload("res://assets/ui/tab_produce.svg"),preload("res://assets/ui/tab_goods.svg"),preload("res://assets/ui/tab_materials.svg")]
var item_cells: Dictionary = {}
var grids: Array[GridContainer] = []
var capacity_labels: Dictionary = {}
var upgrade_grid: GridContainer
var sorted_items: bool = false

func _ready() -> void:
	for title in ["STORAGE_PRODUCE","STORAGE_GOODS","STORAGE_MATERIALS"]:
		tabs.add_tab(tr(title),TAB_ICONS[tabs.get_tab_count()])
	tabs.tab_changed.connect(_show_tab)
	_create_item_grids()
	_create_upgrade_rows()
	Inventory.inventory_changed.connect(refresh)
	$Margin/Content/Footer/CloseButton.pressed.connect(hide)
	$Margin/Content/Header/SortButton.pressed.connect(sort_items)
	$Margin/Content/Header/SortButton.tooltip_text = tr("STORAGE_SORT_HINT")
	get_viewport().size_changed.connect(_fit_viewport)
	refresh()
	_show_tab(tabs.current_tab)
	_fit_viewport.call_deferred()


func _fit_viewport() -> void:
	var desired: Vector2 = Vector2(780,640).min(get_viewport_rect().size-Vector2(24,32))
	for grid in grids:
		grid.columns = maxi(3,int((desired.x-104)/76))
	upgrade_grid.columns = 2 if desired.x >= 700 else 1
	# On small windows upgrades scroll below the items, keeping Close visible.
	var compact: bool = desired.x < 700 or get_viewport_rect().size.y < 600
	var target: Node = pages if compact else $Margin/Content
	if upgrade_grid.get_parent() != target:
		upgrade_grid.reparent(target, false)
		if not compact:
			target.move_child(upgrade_grid,$Margin/Content/ContentGap.get_index())
	content_scroll.custom_minimum_size.y = 24 if get_viewport_rect().size.y < 540 else 48
	size = desired
	position = (get_viewport_rect().size - size) / 2.0
	_refresh_upgrades()


func _show_tab(index: int) -> void:
	for i in range(3):
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
	if sorted_items:
		_sort_grids()


func sort_items() -> void:
	sorted_items = true
	_sort_grids()


func _sort_grids() -> void:
	for grid in grids:
		var cells: Array = grid.get_children()
		cells.sort_custom(func(a, b):
			if (a.quantity > 0) != (b.quantity > 0):
				return a.quantity > 0
			return Localization.display_name(a.item_id).naturalnocasecmp_to(Localization.display_name(b.item_id)) < 0)
		for index in range(cells.size()):
			grid.move_child(cells[index],index)


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
	seeds.append("mystery_seed")
	for rare_crop in Inventory.CropData.RARE_VARIANTS:
		crops.append(rare_crop)
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
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation",8)
		row.add_child(header)
		var label := Label.new()
		label.custom_minimum_size.x = 140
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size",14)
		header.add_child(label)
		var button := Button.new()
		button.text = tr("UI_UPGRADE")
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(104, 36)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_upgrade.bind(storage))
		button.mouse_entered.connect(func(): get_parent().show_item_hint(button,button.get_meta("hint","")))
		button.mouse_exited.connect(func(): get_parent().clear_item_hint(button))
		header.add_child(button)
		var costs := ScrollContainer.new()
		costs.custom_minimum_size.y = 26
		costs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		row.add_child(costs)
		var amounts: Dictionary = {}
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation",12)
		costs.add_child(cost_row)
		for item in ["wood","stone","coins"]:
			var part := HBoxContainer.new()
			part.add_theme_constant_override("separation",4)
			part.tooltip_text = Localization.display_name(item)
			cost_row.add_child(part)
			var icon := Control.new()
			icon.set_script(Icon)
			icon.item_id = item
			icon.custom_minimum_size = Vector2(18,18)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			part.add_child(icon)
			var amount := Label.new()
			amount.add_theme_font_size_override("font_size",14)
			amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
			part.add_child(amount)
			amounts[item] = amount
		upgrades.add_child(row)
		upgrade_rows[storage] = {"label": label, "button": button, "costs":costs, "amounts":amounts}


func _refresh_upgrades() -> void:
	for storage in upgrade_rows:
		var cost: Dictionary = Inventory.next_upgrade(storage)
		var level: int = Inventory.get(storage + "_level")
		var capacity: int = Inventory.get(storage + "_capacity")
		var title: String = tr("WAREHOUSE_SILO") if storage == "silo" else tr("WAREHOUSE_BARN")
		var label: Label = upgrade_rows[storage]["label"]
		label.text = tr("WAREHOUSE_UPGRADE_INFO") % [title, level, capacity, maxi(capacity, cost.get("capacity", capacity))]
		upgrade_rows[storage]["button"].disabled = cost.is_empty()
		upgrade_rows[storage]["costs"].visible = not cost.is_empty()
		if cost.is_empty():
			label.text += "\n" + tr("UI_MAX_LEVEL")
			upgrade_rows[storage]["button"].set_meta("hint",tr("UI_MAX_LEVEL"))
		else:
			var details: String = tr("WAREHOUSE_UPGRADE_COST") % [Inventory.wood,cost["wood"],Inventory.stone,cost["stone"],Inventory.coins,cost["coins"]]
			upgrade_rows[storage]["button"].set_meta("hint",details)
			for item in upgrade_rows[storage]["amounts"]:
				var amount: Label = upgrade_rows[storage]["amounts"][item]
				amount.text = "%d/%d" % [Inventory.get(item),cost[item]]
				amount.modulate = Color("416f35") if Inventory.get(item) >= cost[item] else Color("9e482e")


func _upgrade(storage: String) -> void:
	Inventory.upgrade_structure(storage)
