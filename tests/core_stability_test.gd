extends SceneTree

# Run ONLY through run_core_stability.ps1: its copy redirects all save paths.
var inv: Node
var manager: Node
var farm: Node
var hud: Node
var player: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, description: String) -> void:
	if not value:
		push_error("TEST FAILED: " + description)
		quit(1)
		assert(value, description)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.05).timeout
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await create_timer(0.05).timeout

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK, "read test save")
	return data

func run_checks() -> void:
	await process_frame
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated test save required")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage.ends_with("_write"):
		write_fixture(stage)
	else:
		farm = load("res://main.tscn").instantiate()
		root.add_child(farm)
		current_scene = farm
		hud = farm.get_node("HUD")
		player = farm.get_node("Player")
		await create_timer(0.15).timeout
		match stage:
			"core": await check_core()
			"invalid_read": check_invalid()
			"legacy_read": check_legacy()
			"offline_read": await check_offline()
			"backup_read": check(inv.coins == 4321 and inv.house_level == 3, "recover backup")
			"defaults_read": check(inv.coins == 100 and inv.house_level == 1, "both corrupt fallback")
			"position_read":
				check(farm.get_node("CowShed").position == Vector2(960,1080), "saved cow shed position")
				check(farm.get_node("DogHouse").position == Vector2(580,740), "saved dog house position")
				inv.add_coins(1)
				check(farm.get_node("CowShed").position == Vector2(960,1080), "inventory must not move building")
			"duplicates": await check_duplicates()
			_: check(false, "unknown test stage")
	print("PASS: stability ", stage)
	quit()

func write_fixture(stage: String) -> void:
	var data := ConfigFile.new()
	data.set_value("game", "version", 8)
	data.set_value("inventory", "coins", 4321)
	match stage:
		"invalid_write":
			for item in manager.INVENTORY_DEFAULTS:
				data.set_value("inventory", item, -50)
			data.set_value("player", "player_level", -9)
			data.set_value("player", "player_exp", "bad")
			data.set_value("farm", "unlocked_plot_count", 999)
			data.set_value("upgrades", "house_level", 999)
			data.set_value("upgrades", "chicken_coop_level", 999)
			data.set_value("buildings", "owns_chicken_coop", true)
			data.set_value("animals", "chicken_count", 999)
			data.set_value("animals", "cow_count", -1)
			data.set_value("tools", "has_axe", true)
			data.set_value("tools", "axe_level", 999)
			data.set_value("tools", "hammer_level", 3)
			data.set_value("building_positions", "cow_shed", Vector2.ZERO)
			data.set_value("building_positions", "feed_mill", "bad")
			data.set_value("resources", "tree_1", {"respawn_at": NAN})
			data.set_value("feed_mill", "state", "PRODUCING")
		"legacy_write":
			data.set_value("game", "version", 7)
			data.set_value("soil_1", "state", "READY")
			data.set_value("soil_1", "crop_type", "CORN")
			data.set_value("soil_1", "planted_at", 1000.0)
			data.set_value("soil_1", "ready_at", 1020.0)
			data.set_value("buildings", "owns_cow_shed", true)
		"offline_write":
			data.set_value("player", "player_level", 10)
			data.set_value("tools", "unlock_notified", true)
			data.set_value("animals", "chicken_count", 2)
			data.set_value("animals", "cow_count", 3)
			var now: float = Time.get_unix_time_from_system()
			for id in manager.STATION_IDS:
				data.set_value("buildings", "owns_" + id, true)
				data.set_value(id, "state", "PRODUCING")
				data.set_value(id, "production_type", "CHICKEN_FEED" if id == "feed_mill" else "MILK")
				data.set_value(id, "started_at", now-60)
				data.set_value(id, "ready_at", now+120 if id == "chicken_coop" else now-1)
			for id in ["soil_01", "soil_02"]:
				data.set_value(id, "state", "GROWING")
				data.set_value(id, "crop_type", "WHEAT")
				data.set_value(id, "planted_at", now-5)
				data.set_value(id, "ready_at", now+120 if id == "soil_02" else now-1)
			data.set_value("resources", "tree_1", {"respawn_at": now-1})
			data.set_value("resources", "rock_1", {"respawn_at": now+120})
		"backup_write":
			data.set_value("upgrades", "house_level", 3)
			check(data.save(manager.BACKUP_PATH) == OK, "write backup fixture")
			FileAccess.open(manager.SAVE_PATH, FileAccess.WRITE).store_string("[broken")
			return
		"defaults_write":
			for path in [manager.SAVE_PATH, manager.BACKUP_PATH]:
				FileAccess.open(path, FileAccess.WRITE).store_string("[broken")
			return
		"position_write":
			data.set_value("buildings", "owns_cow_shed", true)
			data.set_value("buildings", "has_dog_house", true)
			data.set_value("building_positions", "cow_shed", Vector2(960,1080))
			data.set_value("building_positions", "dog_house", Vector2(580,740))
	check(data.save(manager.SAVE_PATH) == OK, "write fixture")

func check_invalid() -> void:
	check(inv.coins >= 0 and inv.wood >= 0 and inv.stone >= 0, "nonnegative resources")
	check(inv.player_level == 1 and inv.player_exp == 0, "safe level/exp")
	check(inv.house_level == 4 and inv.chicken_coop_level == 3, "upgrade caps")
	check(inv.chicken_count == 8 and inv.cow_count == 0, "animal caps")
	check(inv.unlocked_plot_count == 32, "plot cap")
	check(inv.axe_level == 4 and inv.hammer_level == 0, "tool ownership/levels")
	check(farm.get_node("CowShed").position == inv.FarmData.BUILDINGS["cow_shed"]["position"], "invalid position fallback")
	check(farm.get_node("tree1").state == "AVAILABLE", "invalid resource timestamp fallback")
	check(farm.get_node("FeedMill").state == "IDLE" and not farm.get_node("FeedMill").visible, "unowned production disabled")

func check_legacy() -> void:
	check(inv.coins == 4321 and inv.house_level == 1 and inv.unlocked_plot_count == 8, "legacy values/defaults")
	check(inv.owns_cow_shed and farm.get_node("CowShed").visible, "old owned building appears")
	var plot = manager.plots["soil_01"]
	check(plot.state == 2 and plot.crop_type == "CORN" and plot.ready_at == 1020.0, "legacy crop preserved")
	check(disk().has_section("soil_01"), "canonical ID persisted")

func check_offline() -> void:
	var mill = farm.get_node("FeedMill")
	var coop = farm.get_node("ChickenCoop")
	var cows = farm.get_node("CowShed")
	check(mill.state == "READY" and cows.state == "READY", "expired station timers ready")
	check(coop.state == "PRODUCING" and coop.production_timer.time_left > 100, "remaining timer not restarted")
	check(manager.plots["soil_01"].state == 2 and manager.plots["soil_02"].grow_timer.time_left > 100, "crop offline states")
	check(farm.get_node("tree1").state == "AVAILABLE" and farm.get_node("rock1").respawn_timer.time_left > 100, "resource offline states")
	check(inv.chicken_feed == 0 and inv.milk == 0, "load grants no rewards")
	check(mill.collect() and not mill.collect() and inv.chicken_feed == 1, "collect feed once")
	check(cows.collect() and not cows.collect() and inv.milk == 3, "collect milk once")
	check(inv.player_exp == 30, "milk EXP exactly once")
	manager.plots["soil_01"].harvest()
	manager.plots["soil_01"].harvest()
	check(inv.wheat == 1 and inv.player_exp == 40, "crop harvest exactly once")
	var tree = farm.get_node("tree4")
	tree.zone_id = "future_2"
	tree.restore_save_data({"respawn_at": 1.0})
	await create_timer(0.1).timeout
	check(not tree.visible and not tree.zone_active and not tree.is_processing() and tree.respawn_timer.is_stopped(), "locked zone inactive")
	check(tree.get_node("CollisionShape2D").disabled and not tree.harvest(), "locked zone no collision/rewards")

func check_core() -> void:
	check(manager.reset_game(), "reset isolated game")
	check(manager.plots.size() == 32 and inv.unlocked_plot_count == 8, "32 plots, eight unlocked")
	await key(KEY_F3)
	check(hud.debug_panel.visible and hud.blocks_world_input(), "F3 debug modal")
	hud.debug_panel._add_value("coins",1000)
	hud.debug_panel._add_value("wood",10)
	hud.debug_panel._add_value("stone",10)
	hud.debug_panel._add_value("player_exp",100)
	check(inv.coins == 1100 and inv.wood == 10 and inv.stone == 10 and inv.player_level == 2, "debug transactions")
	hud.debug_panel._set_level(10)
	check(inv.has_axe and inv.has_hammer and inv.fishing_unlocked, "level debug unlocks")
	check(not hud.tools_unlock_popup.visible, "tools popup waits for modal")
	await key(KEY_ESCAPE)
	await create_timer(0.1).timeout
	check(hud.tools_unlock_popup.visible, "queued tools popup after closing debug")
	await key(KEY_ESCAPE)
	check(not hud.blocks_world_input(), "ESC resumes game")
	# All production buildings recover if missing from the world at purchase time.
	for id in manager.STATION_IDS:
		var info: Dictionary = inv.FarmData.BUILDINGS[id]
		var old = farm.get_node(info["node"])
		farm.remove_child(old)
		old.free()
		inv.coins = 10000
		player.position = info["position"]
		check(inv.buy_building(id), "purchase " + id)
		await create_timer(0.15).timeout
		var building = farm.get_node(info["node"])
		check(building.visible and building.scale == Vector2.ONE and building.can_interact(), "visible/near purchased " + id)
		check(not building.get_node("CollisionShape2D").disabled, "owned collision " + id)
		await key(KEY_E)
		check(hud.active_station == building and hud.station_panel.visible, "E opens purchased " + id)
		await key(KEY_ESCAPE)
	# House transaction remains atomic and saved; max level survives load in other tests.
	player.position = Vector2(700,500)
	await create_timer(0.1).timeout
	await key(KEY_E)
	check(hud.house_panel.visible, "house E")
	inv.coins = 500
	inv.wood = 30
	inv.stone = 14
	hud.house_upgrade_button.pressed.emit()
	check(inv.house_level == 1 and inv.coins == 500 and inv.wood == 30, "failed upgrade atomic")
	inv.stone = 15
	hud.house_upgrade_button.pressed.emit()
	check(inv.house_level == 2 and disk().get_value("upgrades","house_level") == 2, "house upgrade saved")
	check(hud.house_info.text.contains(tr("HOUSE_CURRENT") % 2) and not hud.storage_label.visible, "House level appears in panel, not main HUD")
	hud._show_reset_confirmation()
	check(hud.reset_confirmation.visible and not hud.house_panel.visible, "reset replaces house modal")
	hud.open_build()
	check(not hud.build_panel.visible, "confirmation refuses another panel")
	await key(KEY_ESCAPE)
	check(not hud.blocks_world_input() and inv.house_level == 2, "cancel reset changes nothing")
	# Overlapping interactables: one E chooses the closer OrderBoard, not House too.
	var board = farm.get_node("OrderBoard")
	board.position = player.position
	await create_timer(0.1).timeout
	await key(KEY_E)
	check(hud.order_panel.visible and not hud.house_panel.visible, "nearest interaction only")
	hud.open_build()
	check(hud.build_panel.visible and not hud.order_panel.visible, "main modal switching")
	hud._toggle_shop()
	check(hud.shop_panel.visible and not hud.build_panel.visible, "shop replaces build")
	var before: Vector2 = player.position
	Input.action_press("move_right")
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	check(player.position == before, "modal locks movement")
	await key(KEY_ESCAPE)
	board.position = Vector2(920,420)
	var plot = manager.plots["soil_01"]
	player.position = plot.position
	await create_timer(0.1).timeout
	await key(KEY_E)
	check(plot.state == 1 and inv.wheat_seed == 9, "one E one seed")
	await key(KEY_E)
	check(inv.wheat_seed == 9, "growing plot does not consume seed twice")
	inv.coins = 100
	player.position = manager.plots["soil_09"].position
	await create_timer(0.1).timeout
	await key(KEY_E)
	check(hud.plot_purchase.visible, "plot purchase popup")
	hud._confirm_plot_purchase()
	check(inv.unlocked_plot_count == 9 and inv.coins == 0, "buy ninth plot")
	check(FileAccess.file_exists(manager.BACKUP_PATH), "backup created")
	# Gather cancellation happens immediately on opening any main panel.
	player.position = farm.get_node("tree1").position
	await create_timer(0.1).timeout
	await key(KEY_E)
	check(is_instance_valid(player.active_resource), "resource gathering started")
	hud.open_build()
	check(not is_instance_valid(player.active_resource), "UI cancels gathering")
	# DogHouse recovery and position persistence must share normal ownership signals.
	var old_house = farm.get_node("DogHouse")
	farm.remove_child(old_house)
	old_house.free()
	inv.wood = 15
	inv.stone = 5
	check(inv.build_dog_house(), "build missing dog house")
	check(farm.get_node("DogHouse").visible, "dog house recovered")
	inv.coins = 300
	check(inv.buy_dog() and is_instance_valid(farm.dog), "pet spawns")
	farm.get_node("CowShed").position = Vector2(960,1080)
	inv.add_coins(1)
	check(farm.get_node("CowShed").position == Vector2(960,1080), "no forced position on inventory signal")
	check(disk().get_value("building_positions","cow_shed") == Vector2(960,1080), "save position")
	player.position = Vector2(2100,850)
	check(manager.reset_game(), "reset all systems")
	await create_timer(0.1).timeout
	check(player.position.x < 1800 and not inv.fishing_unlocked, "reset fishing relocks safely")
	check(not inv.has_dog and not inv.has_dog_house and not is_instance_valid(farm.dog), "reset pets")
	check(inv.house_level == 1 and inv.wood == 0 and inv.stone == 0 and inv.axe_level == 0, "reset upgrades/tools/resources")
	check(not hud.blocks_world_input() and inv.unlocked_plot_count == 8, "reset closes UI/restores plots")
	for node in manager.plots.values():
		check(node.state == 0 and node.ready_at == 0.0 and node.grow_timer.is_stopped(), "reset crop")
	for id in manager.STATION_IDS:
		var node = manager.stations[id]
		check(not node.visible and node.production_timer.is_stopped() and node.ready_at == 0.0, "reset building/production")
	for node in manager.resources.values():
		check(node.respawn_at == 0.0 and node.harvest_timer.is_stopped(), "reset resource timer")
	check(farm.get_node("CowShed").position == Vector2(900,1020), "reset building position")
	check(not FileAccess.file_exists(manager.BACKUP_PATH), "reset deletes old backup")

func check_duplicates() -> void:
	for id in ["soil_01", "tree_1", "cow_shed"]:
		var node: Node
		if id == "soil_01":
			node = load("res://soil_plot.tscn").instantiate()
			node.plot_id = id
		elif id == "tree_1":
			node = load("res://resource_node.tscn").instantiate()
			node.resource_id = id
		else:
			node = load("res://cow_shed.tscn").instantiate()
		farm.add_child(node)
		await process_frame
		await process_frame
		check(not is_instance_valid(node), "duplicate node rejected " + id)
	var extra := Node2D.new()
	farm.add_child(extra)
	check(not manager.register_building("house", extra), "duplicate building registry")
	extra.queue_free()
