extends PanelContainer

var active_bakery: Node
var selector: OptionButton
var info: Label
var queue_label: Label
var recipes: Array = Inventory.BakeryData.RECIPES.keys()

func _ready() -> void:
	Inventory.inventory_changed.connect(refresh)
	var layout = preload("res://popup_layout.gd").new()
	add_child(layout)
	var content: VBoxContainer = layout.build(tr("BUILDING_BAKERY"))
	selector = OptionButton.new()
	selector.focus_mode = Control.FOCUS_NONE
	for item in recipes:
		selector.add_item(Localization.display_name(item))
	selector.item_selected.connect(func(_index): refresh())
	content.add_child(selector)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	queue_label = Label.new()
	queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(queue_label)
	var produce := Button.new()
	produce.text = tr("BAKERY_ADD")
	produce.focus_mode = Control.FOCUS_NONE
	produce.pressed.connect(_produce)
	content.add_child(produce)
	var collect := Button.new()
	collect.text = tr("UI_COLLECT")
	collect.focus_mode = Control.FOCUS_NONE
	collect.pressed.connect(_collect)
	content.add_child(collect)
	layout.close_button.pressed.connect(close)
	hide()

func open(bakery: Node) -> void:
	close()
	active_bakery = bakery
	active_bakery.state_changed.connect(refresh)
	show()
	refresh()

func close() -> void:
	if is_instance_valid(active_bakery) and active_bakery.state_changed.is_connected(refresh):
		active_bakery.state_changed.disconnect(refresh)
	active_bakery = null
	selector.get_popup().hide()
	hide()

func refresh() -> void:
	if not visible or not is_instance_valid(active_bakery):
		return
	var recipe: Dictionary = Inventory.BakeryData.RECIPES[recipes[maxi(selector.selected, 0)]]
	info.text = tr("BAKERY_RECIPE") % [recipe["level"], recipe["time"]]
	for ingredient in recipe["requirements"]:
		info.text += "\n%s: %d / %d" % [Localization.display_name(ingredient), Inventory.get(ingredient), recipe["requirements"][ingredient]]
	for i in range(recipes.size()):
		selector.set_item_disabled(i, Inventory.player_level < Inventory.BakeryData.RECIPES[recipes[i]]["level"])
	queue_label.text = tr("BAKERY_QUEUE") % SaveManager.bakery_queue.size()
	for entry in SaveManager.bakery_queue:
		queue_label.text += "\n%s — %s" % [Localization.display_name(entry["item"]), Localization.state(entry["state"])]

func _produce() -> void:
	if is_instance_valid(active_bakery) and active_bakery.can_interact():
		active_bakery.enqueue(recipes[maxi(selector.selected, 0)])

func _collect() -> void:
	if is_instance_valid(active_bakery) and active_bakery.can_interact():
		active_bakery.collect()
