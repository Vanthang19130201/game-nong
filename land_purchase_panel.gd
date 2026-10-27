extends PanelContainer

var active_zone: String = ""
var info: Label
var buy_button: Button

func _ready() -> void:
	z_index = 32
	var layout = preload("res://popup_layout.gd").new()
	layout.preferred_size = Vector2(480,500)
	add_child(layout)
	var content: VBoxContainer = layout.build(tr("LAND_PURCHASE_TITLE"))
	info = Label.new()
	info.custom_minimum_size.x = 240
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	buy_button = Button.new()
	buy_button.text = tr("LAND_UNLOCK")
	buy_button.theme_type_variation = &"PurchaseButton"
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.pressed.connect(_purchase)
	content.add_child(buy_button)
	layout.close_button.pressed.connect(close)
	Inventory.inventory_changed.connect(refresh)
	hide()

func open(id: String) -> void:
	active_zone = id
	show()
	refresh()

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
