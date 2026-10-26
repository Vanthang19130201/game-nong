extends PanelContainer

var active_machine: Node
var info: Label
var queue_label: Label

func _ready() -> void:
	Inventory.inventory_changed.connect(refresh)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	margin.add_child(content)
	var title := Label.new()
	title.text = tr("BUILDING_SPINNING_MACHINE")
	title.theme_type_variation = &"Heading"
	content.add_child(title)
	var product := Label.new()
	product.text = tr("ITEM_COTTON_THREAD")
	content.add_child(product)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	queue_label = Label.new()
	queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(queue_label)
	for action in [["BAKERY_ADD",_produce],["UI_COLLECT",_collect],["UI_CLOSE",close]]:
		var button := Button.new()
		button.text = tr(action[0])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action[1])
		content.add_child(button)
	hide()

func open(machine: Node) -> void:
	close()
	active_machine = machine
	active_machine.state_changed.connect(refresh)
	var view_size: Vector2 = get_viewport_rect().size
	size = Vector2(460,460).min(view_size-Vector2(24,32))
	position = (view_size-size)/2.0
	show()
	refresh()

func close() -> void:
	if is_instance_valid(active_machine) and active_machine.state_changed.is_connected(refresh):
		active_machine.state_changed.disconnect(refresh)
	active_machine = null
	hide()

func refresh() -> void:
	if not visible or not is_instance_valid(active_machine):
		return
	var recipe: Dictionary = Inventory.SpinningData.RECIPES["cotton_thread"]
	info.text = tr("BAKERY_RECIPE") % [recipe["level"],recipe["time"]]
	for ingredient in recipe["requirements"]:
		info.text += "\n%s: %d / %d" % [Localization.display_name(ingredient),Inventory.get(ingredient),recipe["requirements"][ingredient]]
	queue_label.text = tr("BAKERY_QUEUE") % SaveManager.spinning_machine_queue.size()
	for entry in SaveManager.spinning_machine_queue:
		queue_label.text += "\n%s — %s" % [Localization.display_name(entry["item"]),Localization.state(entry["state"])]

func _produce() -> void:
	if visible and is_instance_valid(active_machine) and active_machine.can_interact():
		active_machine.enqueue()

func _collect() -> void:
	if visible and is_instance_valid(active_machine) and active_machine.can_interact():
		active_machine.collect()
