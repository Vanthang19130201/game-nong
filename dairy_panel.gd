extends PanelContainer

var active_dairy: Node
var selector: OptionButton
var info: Label
var queue_label: Label
var recipes: Array = Inventory.DairyData.RECIPES.keys()

func _ready() -> void:
	Inventory.inventory_changed.connect(refresh)
	var layout = preload("res://popup_layout.gd").new()
	add_child(layout)
	var content: VBoxContainer = layout.build(tr("BUILDING_DAIRY"))
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
	for action in [["BAKERY_ADD",_produce],["UI_COLLECT",_collect]]:
		var button := Button.new()
		button.text = tr(action[0])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action[1])
		content.add_child(button)
	layout.close_button.pressed.connect(close)
	hide()

func open(dairy: Node) -> void:
	close()
	active_dairy = dairy
	active_dairy.state_changed.connect(refresh)
	show()
	refresh()

func close() -> void:
	if is_instance_valid(active_dairy) and active_dairy.state_changed.is_connected(refresh):
		active_dairy.state_changed.disconnect(refresh)
	active_dairy = null
	selector.get_popup().hide()
	hide()

func refresh() -> void:
	if not visible or not is_instance_valid(active_dairy):
		return
	var recipe: Dictionary = Inventory.DairyData.RECIPES[recipes[maxi(selector.selected,0)]]
	info.text = tr("BAKERY_RECIPE") % [recipe["level"],recipe["time"]]
	for ingredient in recipe["requirements"]:
		info.text += "\n%s: %d / %d" % [Localization.display_name(ingredient),Inventory.get(ingredient),recipe["requirements"][ingredient]]
	for i in range(recipes.size()):
		selector.set_item_disabled(i,Inventory.player_level < Inventory.DairyData.RECIPES[recipes[i]]["level"])
	queue_label.text = tr("BAKERY_QUEUE") % SaveManager.dairy_queue.size()
	for entry in SaveManager.dairy_queue:
		queue_label.text += "\n%s — %s" % [Localization.display_name(entry["item"]),Localization.state(entry["state"])]

func _produce() -> void:
	if visible and is_instance_valid(active_dairy) and active_dairy.can_interact():
		active_dairy.enqueue(recipes[maxi(selector.selected,0)])

func _collect() -> void:
	if visible and is_instance_valid(active_dairy) and active_dairy.can_interact():
		active_dairy.collect()
