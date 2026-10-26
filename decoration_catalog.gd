extends ScrollContainer

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	add_child(content)
	for id in preload("res://decoration_data.gd").TYPES:
		var data: Dictionary = preload("res://decoration_data.gd").TYPES[id]
		var label := Label.new()
		label.text = tr("DECOR_CATALOG_ROW") % [tr(data["name_key"]),data["coins"],data["wood"],data["stone"]]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
		var button := Button.new()
		button.name = id
		button.text = tr("DECOR_PLACE")
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(get_tree().get_first_node_in_group("farm_hud").edit_farm.begin_decoration.bind(id))
		content.add_child(button)
