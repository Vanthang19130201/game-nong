extends PanelContainer

const Slot = preload("res://item_slot.gd")
const SLOT_COUNT: int = 8
# This is a UI shortcut list, not a second inventory or a new save format.
var items: Array[String] = ["wheat_seed","corn_seed","carrot_seed","soybean_seed","sugarcane_seed","axe","hammer","fishing_rod"]
var selected_slot: int = 0
var slots: Array[Button] = []
var caption: Label
@onready var hud: Node = get_parent()

func _ready() -> void:
	z_index = 12
	tooltip_text = tr("HOTBAR_HINT")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",5)
	add_child(content)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",12)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	content.add_child(row)
	for i in range(SLOT_COUNT):
		var slot := Button.new()
		slot.set_script(Slot)
		slot.name = "Slot%d" % (i+1)
		slot.key_label.text = str(i+1)
		slot.pressed.connect(select_slot.bind(i))
		row.add_child(slot)
		slots.append(slot)
	Inventory.inventory_changed.connect(refresh)
	get_viewport().size_changed.connect(_fit)
	refresh()
	_fit.call_deferred()

func _fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	var width: float = clampf(floorf((view.x-76)/SLOT_COUNT),34,60)
	for slot in slots:
		slot.custom_minimum_size = Vector2(width,width)
	size = get_combined_minimum_size()
	position = Vector2((view.x-size.x)/2,view.y-size.y-12)

func refresh() -> void:
	var selected_seed: String = Inventory.selected_crop.to_lower()+"_seed"
	# Seeds chosen from the inventory use an existing seed slot, including new crops.
	if not items.has(selected_seed):
		items[0] = selected_seed
	if SaveManager.resetting:
		selected_slot = items.find(selected_seed)
	if items[selected_slot].ends_with("_seed") and items[selected_slot] != selected_seed:
		selected_slot = items.find(selected_seed)
	for i in range(SLOT_COUNT):
		var id: String = items[i]
		var count: int = owned_count(id)
		var hint: String = ""
		if id.ends_with("_seed") and not Inventory.is_unlocked(id.trim_suffix("_seed").to_upper()):
			hint = tr("CROP_LOCKED_LEVEL") % Inventory.CropData.CROPS[id.trim_suffix("_seed").to_upper()]["unlock_level"]
		elif id in ["axe","hammer"] and count == 0:
			hint = tr("TOOLS_LOCKED")
		elif id == "fishing_rod" and count == 0:
			hint = tr("FISHING_UNLOCK")
		slots[i].display(id,count,not hint.is_empty(),hint)
		slots[i].highlight(i == selected_slot)
	caption.text = tr("HOTBAR_SELECTED") % Localization.display_name(items[selected_slot])

func owned_count(id: String) -> int:
	if id in ["axe","hammer"]:
		return 1 if Inventory.can_use_tool(id) else 0
	if id == "fishing_rod":
		return 1 if Inventory.has_fishing_rod else 0
	var value = Inventory.get(id)
	return value if value is int else 0

func select_slot(index: int) -> void:
	if not _available() or index < 0 or index >= SLOT_COUNT or slots[index].disabled:
		return
	selected_slot = index
	var id: String = items[index]
	if id.ends_with("_seed"):
		Inventory.select_crop(id.trim_suffix("_seed").to_upper())
	refresh()

func choose_seed(crop: String) -> void:
	# Inventory is already a modal: only selection changes here, never item counts.
	if not Inventory.is_unlocked(crop):
		return
	var id: String = crop.to_lower()+"_seed"
	if not items.has(id):
		items[0] = id
	selected_slot = items.find(id)
	Inventory.select_crop(crop)
	refresh()

func _available() -> bool:
	return not hud.blocks_world_input() and not is_instance_valid(hud.fishing_ui.active_spot)

func _unhandled_input(event: InputEvent) -> void:
	if not _available() or event.is_echo():
		return
	for i in range(SLOT_COUNT):
		if event.is_action_pressed("hotbar_slot_%d" % (i+1)):
			select_slot(i)
			get_viewport().set_input_as_handled()
			return
	if get_viewport().gui_get_hovered_control() == null:
		_scroll(event)

func _gui_input(event: InputEvent) -> void:
	_scroll(event)

func _scroll(event: InputEvent) -> void:
	if not _available() or not (event is InputEventMouseButton) or not event.pressed or event.ctrl_pressed:
		return
	var step: int = 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
	if event.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		return
	for offset in range(1,SLOT_COUNT+1):
		var candidate: int = posmod(selected_slot+offset*step,SLOT_COUNT)
		if not slots[candidate].disabled:
			select_slot(candidate)
			break
	get_viewport().set_input_as_handled()
