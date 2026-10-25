extends Area2D

signal state_changed

@export_enum("feed_mill", "chicken_coop") var station_id: String = "feed_mill"

var state: String = "IDLE"
var production_type: String = ""
var started_at: float = 0.0
var ready_at: float = 0.0
var chicken_count: int = 3
var player_near: bool = false

@onready var status_label: Label = $StatusLabel
@onready var production_timer: Timer = $ProductionTimer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	production_timer.timeout.connect(_finish_production)
	SaveManager.register_station(self)


func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"state": state, "production_type": production_type,
		"started_at": started_at, "ready_at": ready_at
	}
	if station_id == "chicken_coop":
		data["chicken_count"] = chicken_count
	return data


func restore_save_data(data: Dictionary) -> void:
	production_timer.stop()
	state = data["state"]
	production_type = data["production_type"]
	started_at = data["started_at"]
	ready_at = data["ready_at"]
	chicken_count = data.get("chicken_count", 3)
	if state == "PRODUCING":
		var remaining: float = ready_at - Time.get_unix_time_from_system()
		if remaining > 0.0:
			production_timer.start(remaining)
		else:
			state = "READY"
			SaveManager.save_game.call_deferred()
	_update_display()


func can_produce() -> bool:
	if station_id == "feed_mill":
		return state == "IDLE" and Inventory.wheat >= 1 and Inventory.corn >= 1
	return state == "HUNGRY" and Inventory.chicken_feed >= 1


func produce() -> bool:
	if not can_produce():
		return false
	started_at = Time.get_unix_time_from_system()
	var duration: float = 10.0 if station_id == "feed_mill" else 20.0
	ready_at = started_at + duration
	production_type = "CHICKEN_FEED" if station_id == "feed_mill" else "EGG"
	state = "PRODUCING"
	production_timer.start(duration)
	# Complete station state before the inventory signal saves everything.
	if station_id == "feed_mill":
		Inventory.wheat -= 1
		Inventory.corn -= 1
	else:
		Inventory.chicken_feed -= 1
	_update_display()
	Inventory.inventory_changed.emit()
	return true


func collect() -> bool:
	if state != "READY":
		return false
	production_timer.stop()
	state = "IDLE" if station_id == "feed_mill" else "HUNGRY"
	production_type = ""
	started_at = 0.0
	ready_at = 0.0
	if station_id == "feed_mill":
		Inventory.chicken_feed += 1
	else:
		Inventory.egg += chicken_count
		Inventory.player_exp += chicken_count * 5
		Inventory.normalize_exp()
	_update_display()
	Inventory.inventory_changed.emit()
	return true


func _finish_production() -> void:
	if state != "PRODUCING":
		return
	var remaining: float = ready_at - Time.get_unix_time_from_system()
	if remaining > 0.0:
		production_timer.start(remaining)
		return
	state = "READY"
	_update_display()
	SaveManager.save_game()


func _update_display() -> void:
	if station_id == "feed_mill":
		status_label.text = "Feed Mill\nFEED: " + state
	else:
		status_label.text = "CHICKENS: %d\n%s" % [chicken_count, "EGGS READY" if state == "READY" else state]
	state_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not player_near or not event.is_action_pressed("interact") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if station_id == "feed_mill" and state == "READY":
		collect()
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null:
		hud.open_station(self)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false
		var hud = get_tree().get_first_node_in_group("farm_hud")
		if hud != null and hud.active_station == self:
			hud.close_station()