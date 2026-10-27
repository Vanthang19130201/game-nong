extends PanelContainer

const Icon = preload("res://item_icon.gd")
var item_id: String = ""
var stats: Label
var actions: HBoxContainer

func build(id: String, title: String) -> void:
	item_id = id
	custom_minimum_size.x = 190
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	content.add_child(header)
	var icon := Control.new()
	icon.set_script(Icon)
	icon.item_id = id
	icon.custom_minimum_size = Vector2(40,40)
	header.add_child(icon)
	var label := Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	stats = Label.new()
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size",13)
	content.add_child(stats)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	content.add_child(actions)

func add_action(button: Button) -> void:
	button.reparent(actions)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0,36)
	button.show()
