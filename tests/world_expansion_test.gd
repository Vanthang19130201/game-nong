extends SceneTree

var inv: Node
var manager: Node
var event_manager: Node
var farm: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func save_disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK, "save readable")
	return data

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	event_manager = root.get_node("FarmEventManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	var stage := OS.get_cmdline_user_args()[0]
	match stage:
		"expansion_core":
			check(manager.reset_game(), "reset fixture")
			farm = load("res://main.tscn").instantiate()
			root.add_child(farm)
			current_scene = farm
			await create_timer(0.12).timeout
			var data = inv.FarmData
			check(data.BUILDABLE_LAND == Rect2(-600,0,2400,3400), "buildable mainland includes the western and southern plots")
			check(manager.LandData.ZONES["farm_core"]["area"] == Rect2(0,0,1800,1680) and manager.LandData.ZONES["land_01"]["area"] == Rect2(0,1680,600,260), "starting unlocked area gains 200px without overlapping purchased plots")
			check(data.GRID_ORIGIN == Vector2(1100,520) and data.MAX_PLOTS == 32, "field origin and plot count unchanged")
			check(farm.get_node("Player").farm_bounds == Rect2(-600,0,3000,3400), "player stays inside the restored map bounds")
			var camera: Camera2D = farm.get_node("Player/Camera2D")
			check(camera.limit_left == -600 and camera.limit_top == 0 and camera.limit_right == 2400 and camera.limit_bottom == 3400 and camera.min_zoom == 0.65, "camera includes the west plots and keeps a useful zoom")
			check(manager.buildings["house"].position == Vector2(700,400), "house position unchanged")
			check(data.BUILDINGS["loom"]["position"] == Vector2(720,1320), "loom default unchanged")
			check(data.BUILDINGS["pig_pen"]["position"] == Vector2(1260,1580) and data.BUILDINGS["sheep_barn"]["position"] == Vector2(960,1580), "animal buildings keep old defaults")
			check(farm.get_node("Ground").position == Vector2(-600,0) and farm.get_node("Ground").size == Vector2(3000,3400), "ground covers the farm and western/southern expansion")
			check(farm.get_node("River/Placeholder").size.y == 3400 and farm.get_node("River/Visuals/RiverSprite").target_size.y == 3400, "river visuals cover the restored map height")
			var lower: CollisionShape2D = farm.get_node("RiverWalls/Lower")
			var upper: CollisionShape2D = farm.get_node("RiverWalls/Upper")
			check(upper.position.y - upper.shape.size.y / 2.0 == 0 and lower.position.y + lower.shape.size.y / 2.0 == 3400 and lower.shape.size.x == 140, "river collision matches restored map height without widening")
			check(farm.get_node("Bridge").position == Vector2(1870,850), "existing bridge unchanged")
			check(farm.get_node("FishingArea").size == Vector2(460,3400) and farm.get_node("FishingSpot") != null, "pond returns to its previous footprint with one fishing spot")
			check(get_nodes_in_group("land_zones").size() == 17, "farm core, twelve southern plots, and four western plots are created")
			check(manager.LandData.is_adjacent("land_07", ["land_04"]) and manager.LandData.is_adjacent("land_08", ["land_05"]) and manager.LandData.is_adjacent("land_09", ["land_06"]), "new southern access connects to all three legacy bottom zones")
			check(manager.LandData.is_adjacent("land_08", ["land_07"]) and manager.LandData.is_adjacent("land_11", ["land_10"]) and manager.LandData.is_adjacent("land_12", ["land_11"]), "expansion land adjacency forms a purchasable connected route")
			check(manager.LandData.ZONES.size() == 17 and manager.LandData.ZONES.has("land_13") and manager.LandData.ZONES.has("land_16") and not manager.LandData.ZONES.has("land_17"), "west plots return while north plots stay removed")
			check(manager.LandData.is_adjacent("land_13", ["farm_core"]) and manager.LandData.is_adjacent("land_16", ["land_04"]), "western plots connect to the owned farm and southern zones")
			check(manager.unlocked_land_zones == ["farm_core"], "new game leaves all expansion zones locked")
			inv.coins = 60000
			inv.wood = 400
			inv.stone = 250
			var spot_rng := RandomNumberGenerator.new()
			spot_rng.seed = 881
			for point in farm.get_node("DigSpotManager")._candidate_points(spot_rng):
				check(manager.LandData.zone_at(point) in manager.unlocked_land_zones, "dig spot candidate stays on owned land")
			var event_point: Vector2 = event_manager._choose_position(42)
			check(event_point != Vector2.ZERO and manager.LandData.zone_at(event_point) in manager.unlocked_land_zones, "farm event only uses accessible land")
			var resource_ids := ["tree_south_01","tree_south_02","tree_south_03","tree_south_04","tree_south_05","tree_south_06","tree_south_07","tree_south_08","rock_south_01","rock_south_02","rock_south_03","rock_south_04","rock_south_05","rock_south_06"]
			for id in resource_ids:
				check(manager.resources.has(id), "stable resource exists: " + id)
				var resource: Node2D = manager.resources[id]
				check(not resource.visible and not resource.zone_active and resource.zone_id.begins_with("land_"), "locked southern resource is inactive: " + id)
			check(manager.resources["tree_south_01"].position == Vector2(180,2570), "resource position remains in its authored zone")
			check(manager.LandData.restore_unlocked(["farm_core","land_01","land_06","land_17","unknown"]) == ["farm_core","land_01","land_06"], "old ownership IDs remain intact and removed north plot IDs are ignored")
			check(manager.reset_game(), "cleanup")
		"expansion_write":
			check(manager.reset_game(), "write fixture reset")
			manager.unlocked_land_zones = manager.LandData.restore_unlocked(["farm_core","land_01","land_04"])
			inv.coins = 200000
			inv.wood = 1000
			inv.stone = 1000
			check(manager.save_game(), "save old adjacent ownership before expansion")
			var original := [inv.coins,inv.wood,inv.stone]
			for id in ["land_07","land_08","land_09","land_12","land_11","land_10"]:
				check(manager.purchase_land(id), "adjacent south purchase " + id)
			check(inv.coins == original[0]-104500 and inv.wood == original[1]-870 and inv.stone == original[2]-525, "all six configured costs deducted exactly")
			check(manager.unlocked_land_zones.size() == 9, "all south land IDs added without changing old ownership")
			check(manager.save_game(), "save expanded ownership")
		"expansion_read":
			farm = load("res://main.tscn").instantiate()
			root.add_child(farm)
			current_scene = farm
			await create_timer(0.12).timeout
			check(manager.unlocked_land_zones == ["farm_core","land_01","land_04","land_07","land_08","land_09","land_12","land_11","land_10"], "expanded ownership round-trips")
			check(manager.resources["tree_south_01"].visible and manager.resources["tree_south_01"].zone_active, "purchased land activates its saved resource")
			check(manager.resources["rock_south_06"].visible and manager.resources["rock_south_06"].zone_active, "last purchased zone activates its resource")
			var expansion_rng := RandomNumberGenerator.new()
			expansion_rng.seed = 121
			for point in farm.get_node("DigSpotManager")._candidate_points(expansion_rng):
				check(manager.LandData.zone_at(point) in manager.unlocked_land_zones, "dig spot remains inside owned expansion")
			var expanded_event: Vector2 = event_manager._choose_position(84)
			check(expanded_event != Vector2.ZERO and manager.LandData.zone_at(expanded_event) in manager.unlocked_land_zones, "events can use unlocked expanded map only")
			check(manager.LandData.owns_rect(Rect2(560,2470,100,90),manager.unlocked_land_zones), "building footprint on owned south zone is valid")
			check(not manager.LandData.owns_rect(Rect2(560,2470,100,90),["farm_core","land_01","land_04"]), "same placement remains invalid while locked")
			check(manager.reset_game(), "reset relocks expansion")
		"expansion_legacy_write":
			check(manager.reset_game(), "legacy fixture reset")
			manager.unlocked_land_zones = manager.LandData.restore_unlocked(["farm_core","land_01","land_06"])
			check(manager.save_game(), "write pre-expansion ownership")
		"expansion_legacy_read":
			check(manager.unlocked_land_zones == ["farm_core","land_01","land_06"], "old save retains exactly prior land ownership")
			for id in ["land_07","land_08","land_09","land_10","land_11","land_12"]:
				check(id not in manager.unlocked_land_zones, "new land stays locked in old save: " + id)
			var save := save_disk()
			check(save.get_value("building_positions","house") == Vector2(700,400) and save.get_value("building_positions","loom") == Vector2(720,1320), "old building coordinates survive save migration")
			check(inv.unlocked_plot_count == 8 and manager.PLOT_IDS.size() == 32, "field progression remains unchanged")
			check(manager.reset_game(), "cleanup")
		_:
			check(false, "unknown expansion test stage: " + stage)
	if is_instance_valid(farm):
		current_scene = null
		farm.queue_free()
		await process_frame
		manager.resources.clear()
		manager.stations.clear()
		manager.buildings.clear()
		manager.plots.clear()
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null:
		for player in [audio_manager._music_player, audio_manager._farm_ambience, audio_manager._rain_ambience]:
			if is_instance_valid(player):
				player.stop()
				player.stream = null
		audio_manager._streams.clear()
	print("PASS: " + stage)
	quit()
