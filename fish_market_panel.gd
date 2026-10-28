extends PanelContainer

var active_market: Node = null
var rows: Dictionary = {}

func _ready() -> void:
	for fish in Inventory.FishingData.FISH:
		var row := VBoxContainer.new()
		var label := Label.new()
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation",8)
		row.add_theme_constant_override("separation",8)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sell_one := Button.new()
		var sell_all := Button.new()
		sell_one.text = tr("UI_SELL_ONE")
		sell_all.text = tr("UI_SELL_ALL")
		sell_one.focus_mode = Control.FOCUS_NONE
		sell_all.focus_mode = Control.FOCUS_NONE
		sell_one.pressed.connect(_sell.bind(fish, false))
		sell_all.pressed.connect(_sell.bind(fish, true))
		row.add_child(label)
		buttons.add_child(sell_one)
		buttons.add_child(sell_all)
		row.add_child(buttons)
		$Margin/Content/ContentScroll/Rows.add_child(row)
		rows[fish] = {"label": label, "one": sell_one, "all": sell_all}
	$Margin/Content/Footer/Close.pressed.connect(close)
	Inventory.inventory_changed.connect(refresh)
	hide()


func open(market: Node) -> void:
	active_market = market
	show()
	refresh()


func close() -> void:
	hide()
	active_market = null


func refresh() -> void:
	for fish in rows:
		var info: Dictionary = Inventory.FishingData.FISH[fish]
		var owned: int = Inventory.get(fish)
		rows[fish]["label"].text = tr("MARKET_ROW") % [Localization.display_name(info["name"]), owned, info["sell_price"]]
		rows[fish]["one"].disabled = owned <= 0
		rows[fish]["all"].disabled = owned <= 0


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
