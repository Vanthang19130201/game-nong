extends PanelContainer

const Icon = preload("res://item_icon.gd")

var active_market: Node = null
var rows: Dictionary = {}
@onready var rows_root: VBoxContainer = $Margin/Content/ContentScroll/Rows

func _ready() -> void:
	$Margin/Content/Footer/Close.pressed.connect(close)
	Inventory.inventory_changed.connect(refresh)
	refresh()
	hide()


func open(market: Node) -> void:
	active_market = market
	show()
	refresh()


func close() -> void:
	hide()
	active_market = null


func _visible_fish_ids() -> Array[String]:
	var ids: Array[String] = []
	for fish_id in Inventory.FishingData.CATCHABLE_FISH_IDS:
		ids.append(fish_id)
	# Old-save catches remain visible and sellable. Their row is explicitly
	# tagged as legacy rather than silently removing a player's saved items.
	for fish_id in Inventory.FishingData.LEGACY_FISH_IDS:
		ids.append(fish_id)
	return ids


func refresh() -> void:
	if not is_instance_valid(rows_root):
		return
	for child in rows_root.get_children():
		child.queue_free()
	rows.clear()
	for fish_id in _visible_fish_ids():
		_add_row(fish_id)


func _add_row(fish_id: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 58
	row.add_theme_constant_override("separation", 10)
	var icon := Control.new()
	icon.set_script(Icon)
	icon.item_id = fish_id
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var sell_one := Button.new()
	var sell_all := Button.new()
	sell_one.text = tr("UI_SELL_ONE")
	sell_all.text = tr("UI_SELL_ALL")
	sell_one.focus_mode = Control.FOCUS_NONE
	sell_all.focus_mode = Control.FOCUS_NONE
	sell_one.pressed.connect(_sell.bind(fish_id, false))
	sell_all.pressed.connect(_sell.bind(fish_id, true))
	buttons.add_child(sell_one)
	buttons.add_child(sell_all)
	details.add_child(buttons)
	row.add_child(details)
	rows_root.add_child(row)
	var info: Dictionary = Inventory.FishingData.FISH[fish_id]
	var owned: int = Inventory.get(fish_id)
	label.text = tr("MARKET_ROW") % [Localization.display_name(fish_id), owned, info["sell_price"]]
	if Inventory.FishingData.is_legacy_fish(fish_id):
		row.tooltip_text = tr("FISHING_LEGACY_FISH")
	sell_one.disabled = owned <= 0
	sell_all.disabled = owned <= 0
	rows[fish_id] = {"label": label, "one": sell_one, "all": sell_all}


func _sell(fish: String, all: bool) -> void:
	if not visible or not is_instance_valid(active_market) or not active_market.can_interact():
		return
	var amount: int = Inventory.get(fish) if all else 1
	var previous_coins: int = Inventory.coins
	if Inventory.sell_fish(fish, all):
		AudioManager.play_sfx("ui_success")
		var hud = get_tree().get_first_node_in_group("farm_hud")
		if hud != null:
			hud.show_transaction_feedback(tr("TRADE_ITEM") % [-amount, Localization.display_name(fish)] + "\n" + tr("TRADE_COINS") % (Inventory.coins - previous_coins))
