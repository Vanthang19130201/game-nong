extends PanelContainer

const Icon = preload("res://item_icon.gd")
var item_id: String = ""
var stats: Label
var actions: GridContainer

func build(id: String, title: String) -> void:
	item_id = id
	custom_minimum_size.x = 190
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("f7edcf")
	card_style.border_color = Color("a97750")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(11)
	card_style.set_content_margin_all(9)
	add_theme_stylebox_override("panel", card_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	content.add_child(header)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(54, 54)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color("efe0b9")
	icon_style.border_color = Color("d2b780")
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(8)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	header.add_child(icon_frame)
	var icon := Control.new()
	icon.set_script(Icon)
	icon.item_id = id
	icon.custom_minimum_size = Vector2(46,46)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_frame.add_child(icon)
	var label := Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	stats = Label.new()
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size",13)
	content.add_child(stats)
	actions = GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation",6)
	actions.add_theme_constant_override("v_separation",6)
	content.add_child(actions)
	mouse_entered.connect(_show_hint)
	mouse_exited.connect(_hide_hint)

func _show_hint() -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null:
		hud.show_item_hint(self,Localization.display_name(item_id)+" · "+stats.text)

func _hide_hint() -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null:
		hud.clear_item_hint(self)

func add_action(button: Button) -> void:
	if button.get_parent() == null:
		actions.add_child(button)
	else:
		button.reparent(actions)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0,36)
	button.show()
