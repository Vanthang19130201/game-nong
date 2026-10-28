extends PanelContainer

const Icon = preload("res://item_icon.gd")
var active_stall: Node
var rows: Dictionary = {}
var row_group := ButtonGroup.new()
var list: VBoxContainer
var selected_item: String = ""
var quantity: int = 1
var selling: bool = false
var selection: Label
var quantity_label: Label
var minus: Button
var plus: Button
var sell: Button
var sell_one: Button
var sell_five: Button
var sell_all: Button

func _ready() -> void:
	var layout = preload("res://popup_layout.gd").new()
	layout.preferred_size = Vector2(540,520)
	add_child(layout)
	list = layout.build(tr("STALL_TITLE"))
	list.add_theme_constant_override("separation",4)
	var headings := HBoxContainer.new()
	headings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(headings)
	var item_heading: Label = _label(headings)
	item_heading.text = tr("STALL_ITEM")
	item_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(headings,70).text = tr("STALL_OWNED")
	_label(headings,75).text = tr("STALL_PRICE")
	var controls := VBoxContainer.new()
	controls.name = "SaleControls"
	controls.add_theme_constant_override("separation",6)
	var content: VBoxContainer = layout.footer.get_parent()
	content.add_child(controls)
	content.move_child(controls,layout.footer.get_index())
	selection = Label.new()
	selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(selection)
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation",8)
	controls.add_child(amount_row)
	minus = _button("−",_change_quantity.bind(-1),amount_row)
	quantity_label = Label.new()
	quantity_label.custom_minimum_size.x = 48
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_row.add_child(quantity_label)
	plus = _button("+",_change_quantity.bind(1),amount_row)
	for button in [minus,plus]:
		button.custom_minimum_size = Vector2(40,40)
	sell = _button(tr("UI_SELL"),func(): _sell(quantity),amount_row)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation",8)
	controls.add_child(quick)
	sell_one = _button(tr("UI_SELL_ONE"),_sell.bind(1),quick)
	sell_five = _button(tr("STALL_SELL_FIVE"),_sell.bind(5),quick)
	sell_all = _button(tr("UI_SELL_ALL"),_sell_all,quick)
	for button in [sell_one,sell_five,sell_all]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.close_button.pressed.connect(close)
	Inventory.inventory_changed.connect(refresh)
	hide()
	refresh()

func _button(text: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, width: float = 0) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = width
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _create_row(item: String) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = row_group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 40
	button.tooltip_text = Localization.display_name(item)
	button.pressed.connect(_select_item.bind(item))
	list.add_child(button)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,6)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",8)
	margin.add_child(row)
	var icon := Control.new()
	icon.set_script(Icon)
	icon.item_id = item
	icon.custom_minimum_size = Vector2(24,24)
	row.add_child(icon)
	var name_label: Label = _label(row,120)
	name_label.text = Localization.display_name(item)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var owned: Label = _label(row,50)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var price: Label = _label(row,75)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rows[item] = {"button":button,"content":row,"owned":owned,"price":price}

func open(stall: Node) -> void:
	active_stall = stall
	show()
	refresh()

func close() -> void:
	hide()
	active_stall = null

func refresh() -> void:
	var available: Array[String] = Inventory.sellable_items()
	for item in available:
		if not rows.has(item):
			_create_row(item)
		list.move_child(rows[item]["button"],available.find(item)+1)
	for item in rows:
		var row: Dictionary = rows[item]
		row["button"].visible = item in available
		row["owned"].text = str(Inventory.get(item))
		row["price"].text = tr("UI_PRICE_COINS") % Inventory.sell_price(item)
		row["content"].modulate.a = 0.5 if Inventory.get(item) == 0 else 1.0
	if selected_item not in available:
		selected_item = available[0] if not available.is_empty() else ""
		quantity = 1
	_refresh_selection()

func _select_item(item: String) -> void:
	if item not in Inventory.sellable_items():
		return
	selected_item = item
	quantity = 1
	_refresh_selection()

func _refresh_selection() -> void:
	for item in rows:
		rows[item]["button"].set_pressed_no_signal(item == selected_item)
	var owned: int = Inventory.get(selected_item) if not selected_item.is_empty() else 0
	quantity = clampi(quantity,1,maxi(1,owned))
	quantity_label.text = str(quantity)
	selection.text = tr("STALL_SELECTION") % [Localization.display_name(selected_item),owned,Inventory.sell_price(selected_item)] if not selected_item.is_empty() else ""
	var blocked: bool = selling or not is_instance_valid(active_stall) or not active_stall.can_interact()
	minus.disabled = blocked or quantity <= 1
	plus.disabled = blocked or quantity >= owned
	sell.disabled = blocked or owned < quantity
	sell_one.disabled = blocked or owned < 1
	sell_five.disabled = blocked or owned < 5
	sell_all.disabled = blocked or owned < 1

func _change_quantity(change: int) -> void:
	quantity += change
	_refresh_selection()

func _sell_all() -> void:
	if not selected_item.is_empty():
		_sell(Inventory.get(selected_item))

func _sell(amount: int) -> void:
	if not visible or selling or not is_instance_valid(active_stall) or not active_stall.can_interact():
		return
	selling = true
	_refresh_selection()
	if not Inventory.sell_item(selected_item,amount):
		get_tree().call_group("farm_hud","show_floating_feedback",tr("STALL_NOT_ENOUGH_ITEMS"))
	else:
		AudioManager.play_sfx("ui_success")
	selling = false
	refresh()
