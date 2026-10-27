extends PanelContainer

signal deliver_requested(order_id: String)
signal cancel_requested(order_id: String)
const Icon = preload("res://item_icon.gd")
var order_id: String = ""
var displayed_requirements: Dictionary = {}
var item_rows: Dictionary = {}
var title: Label
var badge: Label
var badge_panel: PanelContainer
var items: VBoxContainer
var rewards: Label
var waiting_label: Label
var countdown: Label
var complete: Button
var cancel: Button

func _ready() -> void:
	custom_minimum_size = Vector2(230,250)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	add_child(content)
	title = Label.new()
	title.add_theme_font_size_override("font_size",12)
	content.add_child(title)
	badge_panel = PanelContainer.new()
	badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(badge_panel)
	badge = Label.new()
	badge.add_theme_font_size_override("font_size",12)
	badge_panel.add_child(badge)
	items = VBoxContainer.new()
	items.add_theme_constant_override("separation",6)
	content.add_child(items)
	waiting_label = Label.new()
	waiting_label.text = tr("ORDER_WAITING")
	waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(waiting_label)
	countdown = Label.new()
	countdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(countdown)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)
	rewards = Label.new()
	rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rewards)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	content.add_child(actions)
	complete = Button.new()
	complete.name = "Complete"
	complete.text = tr("ORDER_DELIVER")
	complete.focus_mode = Control.FOCUS_NONE
	complete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	complete.pressed.connect(func(): deliver_requested.emit(order_id))
	actions.add_child(complete)
	cancel = Button.new()
	cancel.text = tr("UI_CANCEL")
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): cancel_requested.emit(order_id))
	actions.add_child(cancel)

func refresh(order: Dictionary) -> void:
	order_id = order["order_id"]
	title.text = tr("ORDER_NUMBER") % order_id.trim_prefix("order_")
	var waiting: bool = OrderManager.is_waiting(order)
	waiting_label.visible = waiting
	countdown.visible = waiting
	badge_panel.visible = not waiting
	items.visible = not waiting
	rewards.visible = not waiting
	complete.visible = not waiting
	cancel.visible = not waiting
	if waiting:
		var seconds: int = OrderManager.cooldown_remaining(order)
		countdown.text = tr("ORDER_COUNTDOWN") % [floori(seconds/60.0),seconds%60]
		return
	var difficulty: String = order.get("difficulty","EASY")
	badge.text = tr("ORDER_TIER_"+difficulty)
	if badge_panel.get_meta("difficulty","") != difficulty:
		var style := StyleBoxFlat.new()
		style.bg_color = OrderManager.Data.TIERS[difficulty]["color"]
		style.set_corner_radius_all(5)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		badge_panel.add_theme_stylebox_override("panel",style)
		badge_panel.set_meta("difficulty",difficulty)
	if displayed_requirements != order["requirements"]:
		_build_items(order["requirements"])
	for item in item_rows:
		var owned: int = Inventory.get(item)
		var required: int = order["requirements"][item]
		item_rows[item].text = "%d/%d" % [owned,required]
		item_rows[item].add_theme_color_override("font_color",Color("42623b") if owned >= required else Color("8b4934"))
	rewards.text = tr("ORDER_CARD_REWARD") % [order["coin_reward"],order["exp_reward"]]
	complete.disabled = not OrderManager.can_complete_order(order_id)
	cancel.disabled = OrderManager.busy

func _build_items(requirements: Dictionary) -> void:
	for child in items.get_children():
		items.remove_child(child)
		child.queue_free()
	item_rows.clear()
	displayed_requirements = requirements.duplicate()
	for item in requirements:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",6)
		items.add_child(row)
		var icon := Control.new()
		icon.set_script(Icon)
		icon.item_id = item
		icon.custom_minimum_size = Vector2(24,24)
		row.add_child(icon)
		var label := Label.new()
		label.text = Localization.display_name(item)
		label.tooltip_text = label.text
		label.custom_minimum_size.x = 70
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size",14)
		row.add_child(label)
		var amount := Label.new()
		amount.add_theme_font_size_override("font_size",14)
		row.add_child(amount)
		item_rows[item] = amount
