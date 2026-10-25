extends PanelContainer

var active_market: Node = null
var rows: Dictionary = {}

func _ready() -> void:
	for fish in Inventory.FishingData.FISH:
		var row := VBoxContainer.new()
		var label := Label.new()
		var buttons := HBoxContainer.new()
		var sell_one := Button.new()
		var sell_all := Button.new()
		sell_one.text = "Sell 1"
		sell_all.text = "Sell All"
		sell_one.focus_mode = Control.FOCUS_NONE
		sell_all.focus_mode = Control.FOCUS_NONE
		sell_one.pressed.connect(_sell.bind(fish, false))
		sell_all.pressed.connect(_sell.bind(fish, true))
		row.add_child(label)
		buttons.add_child(sell_one)
		buttons.add_child(sell_all)
		row.add_child(buttons)
		$Margin/Content/Rows.add_child(row)
		rows[fish] = {"label": label, "one": sell_one, "all": sell_all}
	$Margin/Content/Close.pressed.connect(close)
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
		rows[fish]["label"].text = "%s\nOwned: %d | Sell: %d Coins" % [info["name"], owned, info["sell_price"]]
		rows[fish]["one"].disabled = owned <= 0
		rows[fish]["all"].disabled = owned <= 0


func _sell(fish: String, all: bool) -> void:
	if not visible or not is_instance_valid(active_market) or not active_market.can_interact():
		return
	Inventory.sell_fish(fish, all)
