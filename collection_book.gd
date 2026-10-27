extends PanelContainer

const DiscoveryData = preload("res://discovery_data.gd")
const ItemIcon = preload("res://item_icon.gd")
const UI_THEME: Theme = preload("res://assets/ui/ui_theme.tres")

var _tabs: TabContainer
var _built := false

func _ready() -> void:
	theme = UI_THEME
	visible = false
	z_index = 32
	custom_minimum_size = Vector2(680, 500)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = tr("COLLECTION_TITLE")
	title.theme_type_variation = &"SectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = tr("UI_CLOSE")
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)

func open() -> void:
	if not _built:
		_build_categories()
		_built = true
	else:
		_refresh_categories()
	var viewport_size := get_viewport_rect().size
	size = Vector2(680, 500).min(viewport_size - Vector2(32, 48))
	position = (viewport_size - size) * 0.5
	show()

func close() -> void:
	hide()

func _build_categories() -> void:
	for category in DiscoveryData.CATEGORIES:
		var id: String = category["id"]
		var scroll := ScrollContainer.new()
		scroll.name = id
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var list := VBoxContainer.new()
		list.name = "List"
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 7)
		scroll.add_child(list)
		_tabs.add_child(scroll)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr(category["title_key"]))
	_refresh_categories()

func _refresh_categories() -> void:
	for category in DiscoveryData.CATEGORIES:
		var id: String = category["id"]
		var list: VBoxContainer = _tabs.get_node_or_null(NodePath(id + "/List"))
		if list == null:
			continue
		for child in list.get_children():
			child.queue_free()
		var progress := DiscoveryManager.get_progress(id)
		var count := Label.new()
		count.text = tr("COLLECTION_PROGRESS") % [progress.x, progress.y]
		count.theme_type_variation = &"MutedLabel"
		list.add_child(count)
		for item_id in DiscoveryData.ITEMS[id]:
			var row := PanelContainer.new()
			row.theme_type_variation = &"CardPanel"
			row.custom_minimum_size.y = 56
			list.add_child(row)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 12)
			row.add_child(line)
			var known := DiscoveryManager.has_discovered(id, item_id)
			if known:
				var icon := Control.new()
				icon.custom_minimum_size = Vector2(38, 38)
				icon.set_script(ItemIcon)
				icon.set("item_id", item_id)
				line.add_child(icon)
			var label := Label.new()
			label.text = Localization.display_name(item_id) if known else "???"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var info_column := VBoxContainer.new()
			info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_column.add_child(label)
			if known and DiscoveryData.DESCRIPTIONS.has(item_id):
				var description := Label.new()
				description.text = tr(DiscoveryData.DESCRIPTIONS[item_id])
				description.theme_type_variation = &"MutedLabel"
				description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				info_column.add_child(description)
			line.add_child(info_column)
			var marker := Label.new()
			marker.text = "✓" if known else "?"
			marker.theme_type_variation = &"MutedLabel" if not known else &"RewardLabel"
			line.add_child(marker)
