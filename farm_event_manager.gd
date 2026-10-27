extends Node

signal changed(event_id: String)

const EventData = preload("res://farm_event_data.gd")
const WeatherData = preload("res://weather_data.gd")
var current_event_id: String = ""
var current_day_key: int = 0

func _ready() -> void:
	current_day_key = WeatherData.day_key()
	GameClock.changed.connect(_on_clock_changed)

func is_active(event_id: String) -> bool:
	return current_event_id == event_id

func get_save_data() -> Dictionary:
	return {"event_id": current_event_id, "day_key": current_day_key}

func restore(data: Variant) -> void:
	var key := WeatherData.day_key()
	if data is Dictionary and int(data.get("day_key", -1)) == key:
		var id := str(data.get("event_id", ""))
		current_event_id = id if id.is_empty() or EventData.EVENTS.has(id) else ""
		current_day_key = key
	else:
		_roll_for_day(key)
	if not current_event_id.is_empty():
		DiscoveryManager.discover("special_events", current_event_id)
		if current_event_id == "mushroom_growth":
			DiscoveryManager.discover("nature", "mushroom")
	changed.emit(current_event_id)

func reset() -> void:
	current_event_id = ""
	current_day_key = WeatherData.day_key()
	changed.emit(current_event_id)

func _on_clock_changed() -> void:
	var key := WeatherData.day_key()
	if key == current_day_key:
		return
	_roll_for_day(key)
	changed.emit(current_event_id)
	if is_instance_valid(SaveManager):
		SaveManager.save_game.call_deferred()

func _roll_for_day(key: int) -> void:
	current_day_key = key
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x45564E54 + key * 3571
	current_event_id = ""
	if rng.randf() >= EventData.EVENT_CHANCE:
		return
	var total := 0
	for data in EventData.EVENTS.values():
		total += int(data["weight"])
	var roll := rng.randi_range(1, total)
	for id in EventData.EVENTS:
		roll -= int(EventData.EVENTS[id]["weight"])
		if roll <= 0:
			current_event_id = id
			DiscoveryManager.discover("special_events", id)
			if id == "mushroom_growth":
				DiscoveryManager.discover("nature", "mushroom")
			return
