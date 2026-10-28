extends SceneTree

var farm: Node
var inv: Node
var manager: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func badge(id: String) -> Control:
	return manager.stations[id].get_node("Visuals/ProductionStatus")

func check_state(id: String, state: String) -> void:
	var station = manager.stations[id]
	var view = badge(id)
	var product: Dictionary = inv.Progression.PRODUCTS[id]
	check(station.state == state and view.is_visible_in_tree(), "visible station state " + id + state)
	check(view.icon.item_id == (product["item"] if state == "READY" else product["feed"]), "state uses the shared correct item icon")
	check(view.progress.visible == (state == "PRODUCING") and view.is_processing() == (state == "PRODUCING"), "progress only updates during production")
	check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "world badge never intercepts input")
	if state == "HUNGRY":
		check(view.label.text == tr("WORLD_ANIMALS_NEED_FEED"), "hungry requests feed")
	elif state == "READY":
		check(view.label.text == tr("WORLD_PRODUCT_READY") % root.get_node("Localization").display_name(product["item"]), "ready identifies egg or milk")

func prepare() -> void:
	check(manager.reset_game(), "isolated fixture reset")
	inv.player_level = 10
	inv.tools_unlock_notified = true
	inv.coins = 10000
	for id in ["chicken_coop", "cow_shed"]:
		check(not badge(id).is_visible_in_tree(), "unowned station badge hidden")
		check(inv.buy_building(id), "purchase fixture building")
		var animal: String = inv.Progression.PRODUCTS[id]["animal"]
		for index in range(3):
			check(inv.buy_animal(animal), "three animals fixture")
		var roster: Array = manager.animal_rosters[animal]
		for record in roster:
			record["born_at"] = inv.AnimalData.adult_born_at(animal)
		manager.animal_rosters[animal] = roster
		farm.animal_groups[animal].sync_count()
		check_state(id, "HUNGRY")
	inv.chicken_feed = 1
	inv.cow_feed = 1

func capture(name: String) -> void:
	var camera = farm.get_node("Player/Camera2D")
	camera.target_zoom = 1.0
	camera.zoom = Vector2.ONE
	camera.begin_pan()
	camera.pan_center = Vector2(1200,1030)
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://station_" + name + ".png") == OK, "capture " + name)

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "station_status_read":
		check_state("chicken_coop", "PRODUCING")
		check_state("cow_shed", "READY")
		check(badge("chicken_coop").progress.value >= 0 and inv.egg == 0 and inv.milk == 0, "restored UI never grants products")
		check(manager.reset_game(), "cleanup")
	else:
		prepare()
		if "--capture" in OS.get_cmdline_user_args():
			await capture("hungry")
		for id in ["chicken_coop", "cow_shed"]:
			var station = manager.stations[id]
			check(station.produce(), "existing feed production")
			var duration: float = inv.Progression.PRODUCTS[id]["time"]
			station.restore_save_data({"state":"PRODUCING", "production_type":inv.Progression.PRODUCTS[id]["item"].to_upper(), "started_at":Time.get_unix_time_from_system()-duration/2, "ready_at":Time.get_unix_time_from_system()+duration/2})
			check_state(id, "PRODUCING")
			var data: Dictionary = station.get_save_data().duplicate(true)
			var progress: float = badge(id).progress.value
			check(absf(progress-0.5) < 0.02, "progress derives from existing Unix timestamps")
			await create_timer(0.35).timeout
			check(badge(id).progress.value > progress and station.get_save_data() == data, "visual timer advances without changing production state")
			var sprite: Sprite2D = station.get_node("Visuals/BuildingSprite")
			check(badge(id).get_rect().end.y <= (sprite.transform*sprite.get_rect()).position.y-8, "badge sits above the real artwork")
		if "--capture" in OS.get_cmdline_user_args():
			await capture("producing")
		if stage == "station_status_write":
			# Simulate closing before the station notices the elapsed timestamp.
			manager.stations["cow_shed"].ready_at = Time.get_unix_time_from_system()-1
			check(manager.save_game(), "same production snapshot saved")
		else:
			for id in ["chicken_coop", "cow_shed"]:
				manager.stations[id].ready_at = Time.get_unix_time_from_system()-1
				manager.stations[id]._finish_production()
				check_state(id, "READY")
			if "--capture" in OS.get_cmdline_user_args():
				await capture("ready")
			inv.bread = inv.barn_capacity
			for id in ["chicken_coop", "cow_shed"]:
				check(not manager.stations[id].collect(), "full barn preserves ready batch")
				check_state(id, "READY")
			inv.bread = 0
			for id in ["chicken_coop", "cow_shed"]:
				check(manager.stations[id].collect(), "existing collect succeeds")
				check_state(id, "HUNGRY")
			check(inv.egg == 3 and inv.milk == 3 and inv.chicken_count == 3 and inv.cow_count == 3, "UI preserves product rewards and animals")
			check(manager.reset_game(), "cleanup")
			for id in ["chicken_coop", "cow_shed"]:
				check(not badge(id).is_visible_in_tree() and not badge(id).is_processing(), "reset hides badge and stops UI updates")
	print("PASS: " + stage)
	quit()
