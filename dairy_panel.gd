extends PanelContainer

var active_dairy: Node
var selector: OptionButton
var info: Label
var queue_label: Label
var recipes: Array = Inventory.DairyData.RECIPES.keys()

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
	title.text = tr("BUILDING_DAIRY")
	title.theme_type_variation = &"Heading"
	content.add_child(title)
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
	for action in [["BAKERY_ADD",_produce],["UI_COLLECT",_collect],["UI_CLOSE",close]]:
		var button := Button.new()
		button.text = tr(action[0])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action[1])
		content.add_child(button)
	hide()

func open(dairy: Node) -> void:
	close()
	active_dairy = dairy
	active_dairy.state_changed.connect(refresh)
	var view_size: Vector2 = get_viewport_rect().size
	size = Vector2(460,460).min(view_size-Vector2(24,32))
	position = (view_size-size)/2.0
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
