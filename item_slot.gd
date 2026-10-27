extends Button

const Icon = preload("res://item_icon.gd")
const ItemData = preload("res://item_ui_data.gd")
var item_id: String = ""
var quantity: int = 0
var item_visual: Control
var amount: Label
var key_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(64,64)
	focus_mode = Control.FOCUS_NONE
	theme_type_variation = &"ItemSlot"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item_visual = Control.new()
	item_visual.set_script(Icon)
	item_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_visual.offset_left = 10
	item_visual.offset_right = -10
	item_visual.offset_top = 5
	item_visual.offset_bottom = -9
	add_child(item_visual)
	amount = Label.new()
	amount.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	amount.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	amount.grow_vertical = Control.GROW_DIRECTION_BEGIN
	amount.offset_right = -6
	amount.offset_bottom = -3
	amount.theme_type_variation = &"ItemQuantity"
	amount.add_theme_font_size_override("font_size",13)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(amount)
	key_label = Label.new()
	key_label.position = Vector2(6,1)
	key_label.theme_type_variation = &"ItemKey"
	key_label.add_theme_font_size_override("font_size",11)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)
	mouse_entered.connect(_show_hint)
	mouse_exited.connect(_hide_hint)

func _get_tooltip(_at_position: Vector2) -> String:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null and hud.storage_panel.visible:
		return tooltip_text
	# The reserved hint row keeps item details away from other action buttons.
	return "" if hud != null and hud.has_item_hint_area() else tooltip_text

func _show_hint() -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null:
		hud.show_item_hint(self,tooltip_text)

func _hide_hint() -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null:
		hud.clear_item_hint(self)

func display(id: String, count: int, locked: bool = false, hint: String = "") -> void:
	item_id = id
	quantity = count
	item_visual.item_id = id
	item_visual.modulate.a = 0.38 if locked else (0.35 if count == 0 else 1.0)
	amount.modulate.a = 0.55 if count == 0 else 1.0
	amount.text = str(count)
	tooltip_text = tr("ITEM_TOOLTIP") % [Localization.display_name(id),count]
	var price: int = ItemData.sell_price(id)
	if price > 0:
		tooltip_text += "\n" + tr("ITEM_SELL_TOOLTIP") % price
	if not hint.is_empty():
		tooltip_text += "\n"+hint
	disabled = locked
	if is_inside_tree():
		var hud = get_tree().get_first_node_in_group("farm_hud")
		if hud != null and hud.item_hint_source == self:
			_show_hint()

func highlight(selected: bool) -> void:
	theme_type_variation = &"SelectedSlot" if selected else &"ItemSlot"
