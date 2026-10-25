extends PanelContainer

# Instantiated only by debug builds. Every mutation also checks that guard.
func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	name = "DevDebugPanel"
	z_index = 40
	position = Vector2(320, 190)
	custom_minimum_size = Vector2(430, 300)
	hide()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	var title := Label.new()
	title.text = "DEV DEBUG (F3 / ESC)\nActions update the CURRENT save."
	content.add_child(title)
	for entry in [["coins", 1000], ["wood", 10], ["stone", 10], ["player_exp", 100]]:
		_add_button(content, "+%d %s" % [entry[1], entry[0]], _add_value.bind(entry[0], entry[1]))
	var levels := HBoxContainer.new()
	content.add_child(levels)
	for level in [1, 6, 8, 10, 12]:
		_add_button(levels, "Level %d" % level, _set_level.bind(level))
	_add_button(content, "Close", hide)


func _add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)


func _add_value(item: String, amount: int) -> void:
	if not OS.is_debug_build():
		return
	Inventory.set(item, Inventory.get(item) + amount)
	Inventory.normalize_exp()
	Inventory.inventory_changed.emit()


func _set_level(level: int) -> void:
	if not OS.is_debug_build() or level not in [1, 6, 8, 10, 12]:
		return
	Inventory.player_level = level
	Inventory.player_exp = 0
	Inventory.fishing_unlocked = level >= Inventory.FarmData.FISHING_LEVEL
	if not Inventory.is_unlocked(Inventory.selected_crop):
		Inventory.selected_crop = "WHEAT"
	Inventory.normalize_exp()
	Inventory.inventory_changed.emit()
