extends PanelContainer

const Icon = preload("res://item_icon.gd")
const UI_THEME: Theme = preload("res://assets/ui/ui_theme.tres")

var active_merchant: Node
var rows: Array[Dictionary] = []
var list: VBoxContainer

func _ready() -> void:
	theme = UI_THEME
	var layout = preload("res://popup_layout.gd").new()
	layout.preferred_size = Vector2(460, 390)
	add_child(layout)
	list = layout.build(tr("MERCHANT_TITLE"))
	list.add_theme_constant_override("separation", 8)
	for index in range(5):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size.y = 44
		list.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.set_script(Icon)
		row.add_child(icon)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(info)
		var buy := Button.new()
		buy.text = tr("UI_BUY")
		buy.custom_minimum_size.x = 92
		buy.focus_mode = Control.FOCUS_NONE
		buy.pressed.connect(_buy.bind(index))
		row.add_child(buy)
		rows.append({"row":row, "icon":icon, "info":info, "buy":buy})
	layout.close_button.pressed.connect(close)
	FarmEventManager.merchant_changed.connect(refresh)
	Inventory.inventory_changed.connect(refresh)
	hide()
	refresh()

func open(merchant: Node) -> void:
	active_merchant = merchant
	refresh()
	var viewport_size := get_viewport_rect().size
	size = Vector2(460, 390).min(viewport_size - Vector2(32, 48))
	position = (viewport_size - size) * 0.5
	show()

func close() -> void:
	hide()
	active_merchant = null

func refresh() -> void:
	var stock: Array = FarmEventManager.merchant_stock
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if index >= stock.size():
			row["row"].hide()
			continue
		var entry: Dictionary = stock[index]
		var item: String = entry["item"]
		var price: int = int(entry["price"])
		var quantity: int = int(entry["quantity"])
		row["row"].show()
		row["icon"].item_id = item
		row["info"].text = tr("MERCHANT_STOCK_ROW") % [Localization.display_name(item), price, quantity]
		row["buy"].disabled = quantity <= 0 or Inventory.coins < price or not Inventory.can_add_item(item, 1) or FarmEventManager.merchant_busy

func _buy(index: int) -> void:
	if not visible or FarmEventManager.merchant_busy or index >= FarmEventManager.merchant_stock.size():
		return
	var entry: Dictionary = FarmEventManager.merchant_stock[index]
	if FarmEventManager.buy_merchant_stock(index):
		var hud := get_tree().get_first_node_in_group("farm_hud")
		if is_instance_valid(hud):
			hud.show_inventory_change(str(entry["item"]), 1)
			hud.show_inventory_change("coins", -int(entry["price"]))
	refresh()
