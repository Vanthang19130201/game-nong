extends PanelContainer

signal enqueue_requested(item: String)
const Icon = preload("res://item_icon.gd")
var item_id: String
var recipe: Dictionary
var ingredient_labels: Dictionary = {}
var content: VBoxContainer
var lock_label: Label
var add_button: Button

func _ready() -> void:
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",6)
	add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",8)
	content.add_child(header)
	_add_icon(header,item_id,32)
	var title := Label.new()
	title.text = Localization.display_name(item_id)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for ingredient in recipe["requirements"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",5)
		content.add_child(row)
		_add_icon(row,ingredient,18)
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size",13)
		row.add_child(label)
		ingredient_labels[ingredient] = label
	var duration := Label.new()
	duration.text = tr("PRODUCTION_DURATION") % recipe["time"]
	duration.add_theme_font_size_override("font_size",13)
	content.add_child(duration)
	lock_label = Label.new()
	lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_label.add_theme_font_size_override("font_size",13)
	content.add_child(lock_label)
	add_button = Button.new()
	add_button.text = tr("FEED_ENQUEUE")
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.add_theme_font_size_override("font_size",13)
	add_button.pressed.connect(func(): enqueue_requested.emit(item_id))
	content.add_child(add_button)

func _add_icon(parent: Node, item: String, side: float) -> void:
	var icon := Control.new()
	icon.set_script(Icon)
	icon.item_id = item
	icon.custom_minimum_size = Vector2(side,side)
	parent.add_child(icon)

func refresh(can_enqueue: bool) -> void:
	var unlocked: bool = Inventory.player_level >= recipe["level"]
	var enough: bool = true
	for ingredient in ingredient_labels:
		var owned: int = Inventory.get(ingredient)
		var required: int = recipe["requirements"][ingredient]
		var label: Label = ingredient_labels[ingredient]
		label.text = tr("PRODUCTION_INGREDIENT") % [Localization.display_name(ingredient),required,owned]
		label.add_theme_color_override("font_color",Color("68462f") if owned >= required else Color("a34532"))
		enough = enough and owned >= required
	content.modulate.a = 1.0 if unlocked else 0.5
	lock_label.visible = not unlocked or not enough
	lock_label.text = tr("PRODUCTION_UNLOCK") % recipe["level"] if not unlocked else tr("PRODUCTION_MISSING")
	add_button.disabled = not can_enqueue or not unlocked or not enough
