extends PanelContainer

var active_zone: String = ""
var info: Label
var buy_button: Button

func _ready() -> void:
	z_index = 32
	size = Vector2(440,380)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",14)
	add_child(content)
	var title := Label.new()
	title.text = tr("LAND_PURCHASE_TITLE")
	title.theme_type_variation = &"Heading"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	info = Label.new()
	info.custom_minimum_size.x = 240
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	buy_button = Button.new()
	buy_button.text = tr("LAND_UNLOCK")
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.pressed.connect(_purchase)
	content.add_child(buy_button)
	var cancel := Button.new()
	cancel.text = tr("UI_CANCEL")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(close)
	content.add_child(cancel)
	Inventory.inventory_changed.connect(refresh)
	get_viewport().size_changed.connect(_fit_viewport)
	hide()

func open(id: String) -> void:
	active_zone = id
	show()
	refresh()
	_fit_viewport.call_deferred()

func close() -> void:
	active_zone = ""
	hide()

func refresh() -> void:
	if active_zone.is_empty():
		return
	if active_zone in SaveManager.unlocked_land_zones:
		close()
		return
	var data: Dictionary = SaveManager.LandData.ZONES[active_zone]
	info.text = tr("LAND_PURCHASE_INFO") % [tr(data["name_key"]), Inventory.coins, data["cost_coins"], Inventory.wood, data["cost_wood"], Inventory.stone, data["cost_stone"]]
	buy_button.disabled = not SaveManager.LandData.is_adjacent(active_zone,SaveManager.unlocked_land_zones)
	if buy_button.disabled:
		info.text += "\n" + tr("LAND_NEEDS_NEIGHBOR")

func _purchase() -> void:
	if not visible or active_zone.is_empty():
		return
	if SaveManager.purchase_land(active_zone):
		close()

func _fit_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	size = Vector2(440,380).min(viewport_size-Vector2(24,32))
	position = (viewport_size-size)/2
