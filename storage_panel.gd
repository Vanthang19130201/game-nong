extends PanelContainer

@onready var tabs: TabContainer = $Margin/Content/Tabs

func _ready() -> void:
	Inventory.inventory_changed.connect(refresh)
	$Margin/Content/CloseButton.pressed.connect(hide)
	get_viewport().size_changed.connect(_fit_viewport)
	tabs.get_tab_bar().custom_minimum_size.y = 48
	tabs.get_tab_bar().add_theme_font_size_override("font_size", 14)
	refresh()
	_fit_viewport.call_deferred()


func _fit_viewport() -> void:
	size = Vector2(600, 480).min(get_viewport_rect().size - Vector2(24, 32))
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


func _item_line(item: String, display_name: String = "") -> String:
	return tr("STORAGE_ITEM") % [Localization.display_name(item) if display_name.is_empty() else display_name, Inventory.get(item)]
