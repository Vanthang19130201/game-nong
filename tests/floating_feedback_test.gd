extends SceneTree

var farm: Node
var inv: Node
var manager: Node
var hud: Node
var feedback: Control
var player: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func texts() -> Array:
	return feedback.get_children().map(func(label): return label.text)

func change_text(item: String, amount: int) -> String:
	return tr("TRADE_ITEM") % [amount,root.get_node("Localization").display_name(item)]

func check_materials() -> void:
	for item in ["wood", "stone"]:
		var label: Label = hud.get_node("Layout/Materials/" + item.capitalize() + "Count")
		check(label.text == "%s: %d" % [root.get_node("Localization").display_name(item),inv.get(item)], "HUD reads live material inventory")
		check(hud.get_node("Layout/Materials/"+item.capitalize()+"Icon").item_id == item, "HUD reuses the matching item icon")

func sync_fixture() -> void:
	inv.inventory_changed.emit()
	feedback.clear()

func gather(id: String) -> void:
	var resource = manager.resources[id]
	player.global_position = resource.global_position
	await create_timer(0.1).timeout
	var before: int = inv.get(resource.resource_type)
	feedback.clear()
	check(resource.harvest(), "existing gathering starts " + id)
	check(texts().is_empty(), "no reward popup when only starting to gather")
	await create_timer(resource.harvest_timer.time_left+0.1).timeout
	var earned: int = inv.get(resource.resource_type) - before
	var limits: Dictionary = resource.RockData.TYPES[resource.rock_type] if resource.resource_type == "stone" else {"min_stone":2,"max_stone":3}
	check(earned >= limits["min_stone"] and earned <= limits["max_stone"], "gather grants exactly the existing reward range")
	check(texts() == [change_text(resource.resource_type,earned)], "one popup with the actual successful gathering reward")
	check_materials()
	resource._finish_harvest()
	check(not resource.harvest() and inv.get(resource.resource_type) == before+earned and texts().size() == 1, "spam cannot duplicate reward or popup")
	var saved := ConfigFile.new()
	check(saved.load(manager.SAVE_PATH) == OK and saved.get_value("inventory",resource.resource_type) == before+earned, "reward still autosaves")
	check(saved.get_value("resources",id)["respawn_at"] == resource.respawn_at and resource.state == "DEPLETED", "same respawn timestamp saved with reward")

func collect_animals() -> void:
	inv.coins = 10000
	for kind in ["chicken", "cow"]:
		check(inv.buy_building(inv.Progression.ANIMALS[kind]["building"]), "building fixture")
		for index in range(3):
			check(inv.buy_animal(kind), "animal fixture")
	inv.chicken_feed = 1
	inv.cow_feed = 1
	sync_fixture()
	for id in ["chicken_coop", "cow_shed"]:
		var station = manager.stations[id]
		check(station.produce(), "normal feed production starts")
		station.ready_at = Time.get_unix_time_from_system()-1
		station._finish_production()
	feedback.clear()
	inv.bread = inv.barn_capacity
	sync_fixture()
	check(not manager.stations["chicken_coop"].collect() and texts().is_empty(), "failed full-Barn collect never shows a gain")
	inv.bread = 0
	sync_fixture()
	for id in ["chicken_coop", "cow_shed"]:
		var item: String = inv.Progression.PRODUCTS[id]["item"]
		check(manager.stations[id].collect() and change_text(item,3) in texts(), "exact egg/milk quantity floats on collect")
		var count: int = texts().size()
		check(not manager.stations[id].collect() and texts().size() == count, "repeated collect has no popup or reward")
	check(inv.egg == 3 and inv.milk == 3, "UI never adds extra products")

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	hud = farm.get_node("HUD")
	feedback = hud.floating_feedback
	player = farm.get_node("Player")
	check(texts().is_empty(), "loading inventory never creates fake rewards")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "floating_read":
		check(inv.wood == 17 and inv.stone == 9 and inv.coins == 256, "same inventory save schema restores")
		check_materials()
		inv.inventory_changed.emit()
		check(texts().is_empty(), "unchanged loaded inventory has no popup")
		check(manager.reset_game() and texts().is_empty(), "reset suppresses false inventory gains/losses")
		check_materials()
	else:
		check(manager.reset_game(), "reset fixture")
		inv.player_level = 10
		inv.tools_unlock_notified = true
		inv.normalize_exp()
		inv.axe_level = 4
		inv.hammer_level = 4
		sync_fixture()
		if stage == "floating_write":
			inv.wood = 17
			inv.stone = 9
			inv.coins = 256
			inv.inventory_changed.emit()
			check_materials()
			check(manager.save_game(), "save only normal inventory keys")
		else:
			await gather("tree_1")
			await gather("rock_1")
			await collect_animals()
			feedback.clear()
			var coins: int = inv.coins
			inv.add_coins(100)
			check(inv.remove_coins(50) and inv.coins == coins+50, "original currency operations")
			check(texts() == [change_text("coins",100),change_text("coins",-50)], "shared gain and loss coin feedback")
			var count: int = texts().size()
			check(not inv.remove_coins(inv.coins+1) and not inv.sell_crop("CORN") and texts().size() == count, "failed buy/sell/spending produces no floating feedback")
			inv.wood = 40
			inv.stone = 20
			inv.coins = 10000
			sync_fixture()
			var cost: Dictionary = inv.next_upgrade("silo")
			check(inv.upgrade_structure("silo"), "existing upgrade pays resources once")
			for item in ["wood","stone","coins"]:
				check(change_text(item,-cost[item]) in texts(), "actual upgrade cost floats for " + item)
			check_materials()
			inv.inventory_changed.emit()
			check(texts().size() == 3, "repeated inventory signal never duplicates feedback")
			feedback.clear()
			var unchanged: int = inv.coins
			for index in range(8):
				hud.show_inventory_change("coins",index+1)
			check(texts().size() == feedback.MAX_VISIBLE and inv.coins == unchanged, "bounded reusable display API never changes inventory")
			var positions: Array = []
			for label in feedback.get_children():
				check(label.position not in positions and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "stacked offsets never completely overlap or block input")
				positions.append(label.position)
			var label: Label = feedback.get_child(0)
			var start_y: float = label.position.y
			await create_timer(0.65).timeout
			check(label.position.y < start_y and label.modulate.a < 1.0, "popup rises and fades")
			await create_timer(0.5).timeout
			check(texts().is_empty() and not feedback.is_processing(), "popup cleans up around one second and stops processing")
			if "--capture" in OS.get_cmdline_user_args():
				player.position = Vector2(1000,900)
				player.get_node("Camera2D").focus_player()
				player.get_node("Camera2D").reset_smoothing()
				inv.wood += 3
				inv.stone += 2
				inv.coins += 100
				inv.inventory_changed.emit()
				await create_timer(0.2).timeout
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://floating_materials.png") == OK, "capture HUD and player feedback")
			check(manager.reset_game() and texts().is_empty(), "reset clears floating feedback without false changes")
			check_materials()
	print("PASS: " + stage)
	quit()
