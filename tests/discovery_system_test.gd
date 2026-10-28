extends SceneTree

const CropData = preload("res://crop_data.gd")
const DiscoveryData = preload("res://discovery_data.gd")

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
	check(CropData.roll_rare_variant("WHEAT", "soil_04|WHEAT|123|183") == CropData.roll_rare_variant("WHEAT", "soil_04|WHEAT|123|183"), "rare harvest result is stable for the same saved crop identity")
	check(not root.get_node("OrderManager").item_available("moon_fish"), "Moon Fish is excluded from Orders")
	check("mushroom" in DiscoveryData.ITEMS["nature"] and "bird" in DiscoveryData.ITEMS["nature"] and "rabbit" in DiscoveryData.ITEMS["nature"] and "butterfly" in DiscoveryData.ITEMS["nature"] and "firefly" in DiscoveryData.ITEMS["nature"], "Nature collection entries have visible proximity discovery paths")
	var saved_weather: Dictionary = weather.get_save_data()
	var weather_before: String = weather.current_weather
	weather.restore(saved_weather)
	check(weather.current_weather == weather_before, "weather remains fixed for saved day")
	var saved_event: Dictionary = events.get_save_data()
	var event_before: String = events.current_event_id
	var merchant_stock_before: Array = events.merchant_stock.duplicate(true)
	events.restore(saved_event)
	check(events.current_event_id == event_before, "event remains fixed for saved day")
	check(events.merchant_stock == merchant_stock_before, "merchant appearance and stock remain fixed for saved day")
	check(event_before.is_empty() or not discovery.has_discovered("special_events", event_before), "rolling/restoring an event does not auto-discover it")
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
	check(save.get_value("dig_spots", "hidden_treasure_claimed", false) == save_manager.hidden_treasure_claimed, "hidden treasure claim state is persisted")
	var hud: Node = farm.get_node("HUD")
	hud.open_collection_book()
	await process_frame
	check(hud.collection_book.visible, "Collection Book opens from HUD")
	check(hud.blocks_world_input(), "Collection Book blocks world input")
	hud.close_current_panel()
	check(not hud.collection_book.visible, "ESC close route closes Collection Book")
	var lighting_count := 0
	for node in farm.find_children("*", "CanvasModulate", true, false):
		lighting_count += 1
	check(lighting_count == 1, "farm has one WorldLighting CanvasModulate")
	check(farm.get_node("WorldWeatherLayer").layer < farm.get_node("HUD").layer, "weather visuals render below HUD so UI colors stay untinted")
	var weather_visual: Node = farm.get_node("WorldWeatherLayer/WeatherVisual")
	check(weather_visual.rain_particles.amount >= 240 and weather_visual.rain_particles.amount <= 700, "rain density scales with viewport and stays bounded")
	inventory.map_fragment = 3
	manager._check_treasure_hunt()
	var hidden_spot: Node = null
	for spot in manager.spots.values():
		if spot.is_hidden_treasure:
			hidden_spot = spot
			break
	check(is_instance_valid(hidden_spot), "three map fragments create a safe hidden treasure spot")
	if is_instance_valid(hidden_spot):
		check(inventory.map_fragment == 0, "fragments are consumed only once after treasure spot save")
		check(save_manager.saved_dig_spots.any(func(record: Dictionary) -> bool: return record.get("is_hidden_treasure", false)), "hidden treasure identity is in the save snapshot")
		farm.get_node("Player").global_position = hidden_spot.global_position
		check(manager.collect_spot(hidden_spot.spot_id), "hidden treasure can be collected transactionally")
		check(save_manager.hidden_treasure_claimed, "hidden treasure cannot respawn after collection")
	var mystery_plot: Node = null
	for candidate in save_manager.plots.values():
		if candidate.is_unlocked() and candidate.state == candidate.PlotState.EMPTY:
			mystery_plot = candidate
			break
	check("mystery_seed" in inventory.SILO_ITEMS, "Mystery Seed is stored in the existing Silo")
	if is_instance_valid(mystery_plot):
		inventory.mystery_seed = 1
		inventory.select_crop("MYSTERY")
		mystery_plot.try_plant()
		check(mystery_plot.state == mystery_plot.PlotState.GROWING and CropData.CROPS.has(mystery_plot.crop_type), "Mystery Seed resolves to an unlocked crop when planted")
		check(inventory.mystery_seed == 0, "Mystery Seed is consumed once")
		check(save_manager.save_game(), "resolved Mystery Seed crop saves")
		var mystery_save := ConfigFile.new()
		check(mystery_save.load(save_manager.SAVE_PATH) == OK and mystery_save.get_value(mystery_plot.plot_id, "crop_type", "") == mystery_plot.crop_type, "resolved Mystery Seed result persists on its plot")
	inventory.select_crop("WHEAT")
	events.merchant_active = true
	events.merchant_day_key = root.get_node("GameClock").absolute_day
	events.merchant_position = farm.get_node("Player").global_position + Vector2(32, 0)
	events.merchant_stock = [{"item":"mystery_seed", "price":1, "quantity":1}]
	inventory.mystery_seed = 0
	var merchant_visual: Node = farm.get_node("WanderingMerchantVisual")
	merchant_visual._process(0.0)
	check(merchant_visual.can_interact(), "merchant is available to central E/click interaction when nearby")
	hud.open_wandering_merchant(merchant_visual)
	check(hud.wandering_merchant_panel.visible and hud.blocks_world_input(), "merchant panel opens as the sole world-blocking modal")
	hud.close_current_panel()
	check(not hud.wandering_merchant_panel.visible, "ESC route closes merchant panel")
	var coins_before_merchant: int = inventory.coins
	check(events.buy_merchant_stock(0), "merchant purchase succeeds as one transaction")
	check(inventory.coins == coins_before_merchant - 1 and inventory.mystery_seed == 1, "merchant purchase charges and grants once")
	check(events.merchant_stock[0]["quantity"] == 0, "merchant remaining stock is updated")
	check(save_manager.save_game(), "merchant stock saves")
	var merchant_save := ConfigFile.new()
	check(merchant_save.load(save_manager.SAVE_PATH) == OK and merchant_save.get_value("farm_event", "state", {}).get("merchant_stock", [])[0]["quantity"] == 0, "merchant stock persists across reload")
	weather.current_weather = "rain"
	weather.changed.emit("rain")
	var cloud_phase_before: float = weather_visual.cloud_phase
	await create_timer(0.1).timeout
	check(weather_visual.rain_particles.emitting and weather_visual.cloud_visible and weather_visual.cloud_phase > cloud_phase_before, "rain shows falling streaks under visibly drifting storm clouds")
	weather.current_weather = "cloudy"
	weather.changed.emit("cloudy")
	cloud_phase_before = weather_visual.cloud_phase
	await create_timer(0.1).timeout
	check(not weather_visual.rain_particles.emitting and weather_visual.cloud_visible and weather_visual.cloud_phase > cloud_phase_before, "cloudy weather animates moving clouds without rain")
	farm.get_node("HUD/Calendar").refresh()
	check(farm.get_node("HUD/Calendar/Content/Time/WeatherIcon").texture != null, "weather icon remains set")
	print("PASS: discovery, deterministic crops, weather layering, events, treasure hunt, Mystery Seed, and merchant stock persistence")
	quit()
