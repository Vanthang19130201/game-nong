extends SceneTree

const CropData = preload("res://crop_data.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func run_checks() -> void:
	await process_frame
	await process_frame
	var inventory: Node = root.get_node("Inventory")
	var save_manager: Node = root.get_node("SaveManager")
	var discovery: Node = root.get_node("DiscoveryManager")
	var weather: Node = root.get_node("WeatherManager")
	var events: Node = root.get_node("FarmEventManager")
	var farm: Node2D = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await process_frame
	await process_frame
	var manager: Node = farm.get_node("DigSpotManager")
	check(save_manager.reset_game(), "start from clean isolated state")
	for item in inventory.BARN_ITEMS:
		check(inventory.get(item) != null, "inventory has storage field " + item)
	check(discovery.discover_item("wheat"), "first crop discovery recorded")
	check(not discovery.discover_item("wheat"), "repeat discovery does not notify twice")
	check(discovery.get_progress("crops").x >= 1, "collection progress updated")
	check(CropData.inventory_defaults().has("golden_wheat"), "rare crop save field exists")
	check("golden_corn" in CropData.silo_items() and "giant_carrot" in CropData.silo_items(), "rare crops use Silo")
	var saved_weather: Dictionary = weather.get_save_data()
	var weather_before: String = weather.current_weather
	weather.restore(saved_weather)
	check(weather.current_weather == weather_before, "weather remains fixed for saved day")
	var saved_event: Dictionary = events.get_save_data()
	var event_before: String = events.current_event_id
	events.restore(saved_event)
	check(events.current_event_id == event_before, "event remains fixed for saved day")
	var day_key: int = save_manager.saved_dig_spots_day_key
	var spot_count: int = manager.spots.size()
	manager._on_clock_changed()
	check(manager.spots.size() == spot_count and save_manager.saved_dig_spots_day_key == day_key, "dig spots do not reroll during same day, including zero-spot days")
	var probe: Node2D = load("res://dig_spot.tscn").instantiate()
	probe.spot_id = "test_dig_probe"
	probe.reward = {"type":"coins", "amount":37}
	probe.position = farm.get_node("Player").global_position
	farm.add_child(probe)
	manager.spots[probe.spot_id] = probe
	var previous_coins: int = inventory.coins
	check(manager.collect_spot(probe.spot_id), "dig reward can be collected")
	check(inventory.coins == previous_coins + 37, "dig reward granted exactly once")
	check(not manager.spots.has("test_dig_probe"), "collected spot removed from active state")
	var save := ConfigFile.new()
	check(save.load(save_manager.SAVE_PATH) == OK, "save snapshot readable after collection")
	check(save.get_value("discovery", "state", {}).get("discovered", {}).get("crops", []).has("wheat"), "discoveries persisted")
	check(save.get_value("weather", "state", {}).get("weather_id", "") == weather_before, "weather persisted")
	check(save.get_value("calendar", "absolute_day", -1) == root.get_node("GameClock").absolute_day, "absolute game day persisted for daily rolls")
	var hud: Node = farm.get_node("HUD")
	hud.open_collection_book()
	await process_frame
	check(hud.collection_book.visible, "Collection Book opens from HUD")
	check(hud.blocks_world_input(), "Collection Book blocks world input")
	hud.close_current_panel()
	check(not hud.collection_book.visible, "ESC close route closes Collection Book")
	weather.current_weather = "rain"
	farm.get_node("HUD/Calendar").refresh()
	check(farm.get_node("HUD/Calendar/Content/Time/WeatherIcon").texture != null, "weather icon remains set")
	print("PASS: discovery, weather, event, dig spot persistence")
	quit()
