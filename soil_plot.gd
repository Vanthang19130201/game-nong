extends Area2D

const CropData = preload("res://crop_data.gd")

enum PlotState { EMPTY, GROWING, READY }

@export var plot_id: String = ""

var state: PlotState = PlotState.EMPTY
var player_near: bool = false
var crop_type: String = ""
var planted_at: float = 0.0
var ready_at: float = 0.0

@onready var plant_label: Label = $PlantLabel
@onready var grow_timer: Timer = $GrowTimer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	grow_timer.timeout.connect(_on_grow_timer_timeout)
	SaveManager.register_plot(self)


func get_save_data() -> Dictionary:
	return {
		"plot_id": plot_id, "state": PlotState.keys()[state],
		"crop_type": crop_type, "planted_at": planted_at, "ready_at": ready_at
	}


func restore_save_data(data: Dictionary) -> void:
	grow_timer.stop()
	crop_type = data["crop_type"]
	planted_at = data["planted_at"]
	ready_at = data["ready_at"]
	match data["state"]:
		"GROWING":
			state = PlotState.GROWING
			var remaining: float = ready_at - Time.get_unix_time_from_system()
			if remaining > 0.0:
				grow_timer.start(remaining)
			else:
				state = PlotState.READY
				SaveManager.save_game.call_deferred()
		"READY":
			state = PlotState.READY
		_:
			_clear_crop()
	_update_label()


func _update_label() -> void:
	if state == PlotState.EMPTY:
		plant_label.text = ""
	elif state == PlotState.GROWING:
		plant_label.text = crop_type + "..."
	else:
		plant_label.text = crop_type + "\nREADY"


func _unhandled_input(event: InputEvent) -> void:
	if player_near and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if state == PlotState.EMPTY:
			try_plant()
		elif state == PlotState.READY:
			harvest()


func try_plant() -> void:
	var selected: String = Inventory.selected_crop
	if state != PlotState.EMPTY or not Inventory.can_plant(selected):
		return
	# Finish the plot state BEFORE consuming seed and saving the whole game.
	crop_type = selected
	planted_at = Time.get_unix_time_from_system()
	ready_at = planted_at + CropData.CROPS[crop_type]["grow_time"]
	state = PlotState.GROWING
	grow_timer.start(ready_at - planted_at)
	_update_label()
	Inventory.use_seed(crop_type)


func _on_grow_timer_timeout() -> void:
	if state != PlotState.GROWING:
		return
	# Unix time is authoritative, including after suspend or a clock change.
	var remaining: float = ready_at - Time.get_unix_time_from_system()
	if remaining > 0.0:
		grow_timer.start(remaining)
		return
	state = PlotState.READY
	_update_label()
	SaveManager.save_game()


func harvest() -> void:
	if state != PlotState.READY:
		return
	var harvested_crop: String = crop_type
	_clear_crop()
	_update_label()
	Inventory.collect_crop(harvested_crop)


func _clear_crop() -> void:
	grow_timer.stop()
	state = PlotState.EMPTY
	crop_type = ""
	planted_at = 0.0
	ready_at = 0.0


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false