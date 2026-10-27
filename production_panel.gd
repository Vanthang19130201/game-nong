extends PanelContainer

var machine_kind: String
var active_machine: Node
var view: VBoxContainer
var layout: Node

func _ready() -> void:
	layout = preload("res://popup_layout.gd").new()
	layout.preferred_size = Vector2(900,620)
	add_child(layout)
	var body: VBoxContainer = layout.build(tr("BUILDING_"+machine_kind.to_upper()))
	view = VBoxContainer.new()
	view.set_script(preload("res://production_ui.gd"))
	view.machine_kind = machine_kind
	match machine_kind:
		"bakery": view.recipe_data = Inventory.BakeryData.RECIPES
		"dairy": view.recipe_data = Inventory.DairyData.RECIPES
		"spinning_machine": view.recipe_data = Inventory.SpinningData.RECIPES
	body.add_child(view)
	_add_close_button()
	layout.close_button.pressed.connect(close)
	Inventory.inventory_changed.connect(refresh)
	hide()

func _add_close_button() -> void:
	var title: Label = $Margin/Content/Title
	var header := HBoxContainer.new()
	$Margin/Content.add_child(header)
	$Margin/Content.move_child(header,0)
	title.reparent(header,false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := Button.new()
	button.text = "×"
	button.tooltip_text = tr("UI_CLOSE")
	button.custom_minimum_size = Vector2(36,36)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(close)
	header.add_child(button)

func open(machine: Node) -> void:
	close()
	active_machine = machine
	active_machine.state_changed.connect(refresh)
	show()
	refresh()
	layout.fit()

func close() -> void:
	if is_instance_valid(active_machine) and active_machine.state_changed.is_connected(refresh):
		active_machine.state_changed.disconnect(refresh)
	active_machine = null
	view.bind_machine(null)
	hide()

func refresh() -> void:
	if visible and is_instance_valid(active_machine):
		view.bind_machine(active_machine)
