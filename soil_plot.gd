extends Area2D

enum PlotState {
	EMPTY,
	GROWING,
	READY
}

var state: PlotState = PlotState.EMPTY
var player_near: bool = false

@onready var plant_label: Label = $PlantLabel
@onready var grow_timer: Timer = $GrowTimer


func _ready():
	plant_label.text = ""

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	grow_timer.timeout.connect(_on_grow_timer_timeout)


func _unhandled_input(event: InputEvent) -> void:
	if player_near and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if state == PlotState.EMPTY:
			try_plant()

		elif state == PlotState.READY:
			harvest()


func try_plant() -> void:
	if state != PlotState.EMPTY:
		return

	if Inventory.use_wheat_seed():
		state = PlotState.GROWING
		plant_label.text = "MAM"
		grow_timer.start()

		print("Da trong lua!")
	else:
		print("Het hat giong!")


func _on_grow_timer_timeout() -> void:
	if state != PlotState.GROWING:
		return

	state = PlotState.READY
	plant_label.text = "CHIN"

	print("Lua da chin!")


func harvest() -> void:
	if state != PlotState.READY:
		return

	state = PlotState.EMPTY
	plant_label.text = ""

	Inventory.add_wheat(1)

	print("Thu hoach +1 lua!")


func _on_body_entered(body):
	if body.name == "Player":
		player_near = true
		print("Nhan E de tuong tac")


func _on_body_exited(body):
	if body.name == "Player":
		player_near = false
