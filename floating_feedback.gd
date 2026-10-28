extends Control

const Toast = preload("res://transaction_feedback.gd")
const TreasureData = preload("res://treasure_data.gd")
const MAX_VISIBLE: int = 6
var previous: Dictionary = {}
var tracked_items: Array = []
var player: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 17 # World feedback stays behind main popup panels.
	tracked_items = Inventory.SILO_ITEMS + Inventory.BARN_ITEMS + ["wood", "stone", "coins"]
	_take_snapshot()
	Inventory.inventory_changed.connect(_on_inventory_changed)
	set_process(false)

func _take_snapshot() -> void:
	for item in tracked_items:
		previous[item] = Inventory.get(item)

func _on_inventory_changed() -> void:
	if SaveManager.resetting:
		_take_snapshot()
		clear()
		return
	for item in tracked_items:
		var current: int = Inventory.get(item)
		var amount: int = current - int(previous.get(item, current))
		# Update before showing anything: repeated signals produce no extra popup.
		previous[item] = current
		if amount != 0:
			show_inventory_change(item, amount)

# Automatic inventory_changed feedback already calls this for committed deltas.
# These helpers only display UI; they never grant, remove or save an item.
func show_inventory_change(item_id: String, amount: int) -> void:
	if amount == 0:
		return
	if amount > 0 and TreasureData.ITEMS.has(item_id) and TreasureData.is_rare_or_better(item_id):
		show_rare_loot_feedback(item_id, amount)
		return
	show_floating_feedback(tr("TRADE_ITEM") % [amount, Localization.display_name(item_id)])
	if get_child_count() > 0 and item_id in ["egg", "milk", "chicken_feed", "cow_feed"]:
		var item_icon: Control = preload("res://item_icon.gd").new()
		item_icon.item_id = item_id
		item_icon.position = Vector2(-24, 0)
		item_icon.size = Vector2(20, 20)
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_child(get_child_count() - 1).add_child(item_icon)


func show_rare_loot_feedback(item_id: String, amount: int) -> void:
	var rarity_key := "RARITY_" + TreasureData.rarity_of(item_id).to_upper()
	var text := tr(rarity_key).to_upper() + "!\n" + Localization.display_name(item_id) + " ×%d" % amount
	var sell_value: int = Inventory.sell_price(item_id)
	if sell_value > 0:
		text += "\n" + (tr("ITEM_SELL_TOOLTIP") % sell_value)
	show_floating_feedback(text)
	if get_child_count() <= 0:
		return
	var item_icon: Control = preload("res://item_icon.gd").new()
	item_icon.item_id = item_id
	item_icon.position = Vector2(-28, 2)
	item_icon.size = Vector2(24, 24)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_child(get_child_count() - 1).add_child(item_icon)

func show_floating_feedback(text: String) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("farm_player")
	if player == null or text.is_empty():
		return
	if get_child_count() >= MAX_VISIBLE:
		_remove(get_child(0))
	var used: Array = []
	for child in get_children():
		used.append(child.get_meta("slot"))
	var slot: int = 0
	while slot in used:
		slot += 1
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Toast.LOSS_COLOR if text.begins_with("-") else Toast.GAIN_COLOR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.set_meta("slot", slot)
	add_child(label)
	label.reset_size()
	var side: float = -12.0 if slot % 2 == 0 else 12.0
	label.position = Vector2(side-label.size.x/2.0, -label.size.y-slot*22.0)
	_update_anchor()
	set_process(true)
	var tween := label.create_tween().set_parallel(true)
	label.set_meta("tween", tween)
	tween.tween_property(label, "position:y", label.position.y-26.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.45)
	tween.chain().tween_callback(_remove.bind(label))

func _process(_delta: float) -> void:
	_update_anchor()

func _update_anchor() -> void:
	if is_instance_valid(player):
		# Project world coordinates into HUD space: font size stays readable at
		# every zoom, and feedback follows the player's head as the camera moves.
		position = player.get_global_transform_with_canvas() * Vector2(0,-44)

func _remove(label: Label) -> void:
	if not is_instance_valid(label) or label.get_parent() != self:
		return
	var tween: Tween = label.get_meta("tween", null)
	if tween != null and tween.is_running():
		tween.kill()
	remove_child(label)
	label.queue_free()
	set_process(get_child_count() > 0)

func clear() -> void:
	for label in get_children():
		_remove(label)
