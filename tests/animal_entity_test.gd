extends SceneTree

var farm: Node
var inv: Node
var manager: Node
var player: Node2D
var hud: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func key_e() -> void:
	await press_key(KEY_E)

func press_key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func counts(expected: int) -> void:
	check(get_nodes_in_group("farm_animals").size() == expected * 2, "exact world entity total")
	for kind in ["chicken", "cow"]:
		var group = farm.animal_groups[kind]
		check(group.get_parent() == farm and group.animals().size() == expected, "farm manages the world group " + kind)
		check(inv.get(kind + "_count") == expected, "world entities match saved inventory count " + kind)
		for animal in group.animals():
			check(animal.is_in_group("farm_interactables") and animal.animal_type == kind, "each animal is an interactable entity")
			check(group.is_position_valid(animal.position, animal.body_radius), "spawn near the correct home on valid ground")
			animal.rest()
			animal.idle_timer.stop()

func prepare() -> void:
	check(manager.reset_game(), "isolated new game")
	inv.player_level = 10
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.inventory_changed.emit()
	for kind in ["chicken", "cow"]:
		check(inv.buy_building(inv.Progression.ANIMALS[kind]["building"]), "buy building fixture")
		for n in range(3):
			check(inv.buy_animal(kind), "buy animal fixture")
		var roster: Array = manager.animal_rosters[kind]
		for record in roster:
			record["born_at"] = inv.AnimalData.adult_born_at(kind)
		manager.animal_rosters[kind] = roster
		farm.animal_groups[kind].sync_count()
	counts(3)
	for kind in ["chicken", "cow"]:
		check(not hud.animal_buttons[kind].has("sell"), "Build has only animal purchase")
	for name in ["AnimalBuy", "AnimalSell"]:
		check(not hud.station_panel.get_node("Margin/Content/ContentScroll/Body").has_node(name), "StationPanel has no animal trading controls")
	for id in ["chicken_coop", "cow_shed"]:
		var visuals: Node = manager.buildings[id].get_node("Visuals")
		check(not visuals.has_node("Animals") and not visuals.has_node("AnimatedSprite2D"), "no fake or duplicate animals in station scene")

func sell_by_e() -> void:
	for kind in ["chicken", "cow"]:
		var group = farm.animal_groups[kind]
		var before: Array = group.animals()
		# Select the first instance, not the last one that count sync would remove.
		var chosen: Node2D = before[0]
		player.global_position = chosen.get_interaction_position()
		await physics_frame
		check(player._nearest_interactable() == chosen, "existing nearest-target dispatcher picks the animal")
		check(player.mouse_interaction.target_at(chosen.get_interaction_position()) == chosen, "existing mouse dispatcher can also identify the animal")
		var coins: int = inv.coins
		await key_e()
		check(hud.animal_sale_confirmation.visible and hud.pending_sale_animal == chosen, "E opens confirmation for the chosen animal")
		check(inv.coins == coins and group.animals().size() == 3 and not chosen.sale_pending, "opening confirmation never sells immediately")
		check(hud.blocks_world_input() and not hud.hotbar.visible, "sale confirmation blocks world and hides hotbar")
		check(hud.animal_sale_confirmation.dialog_text.contains(str(inv.Progression.ANIMALS[kind]["sell"])), "confirmation shows the correct sale price")
		await key_e()
		await press_key(KEY_P)
		await press_key(KEY_TAB)
		check(inv.coins == coins and group.animals().size() == 3 and not hud.shop_build_panel.visible and not hud.storage_panel.visible, "repeated E and panel hotkeys cannot sell or open another popup")
		hud.animal_sale_confirmation.get_cancel_button().pressed.emit()
		await process_frame
		check(not hud.animal_sale_confirmation.visible and hud.pending_sale_animal == null and inv.coins == coins and chosen.is_inside_tree(), "Cancel keeps the animal and coins")
		await key_e()
		await press_key(KEY_ESCAPE)
		check(not hud.animal_sale_confirmation.visible and hud.pending_sale_animal == null and inv.coins == coins, "ESC cancels without selling")
		await key_e()
		hud.animal_sale_confirmation.confirmed.emit()
		await process_frame
		check(group.animals().size() == 2 and inv.get(kind + "_count") == 2, "confirmation sells exactly one animal")
		check(inv.coins == coins + inv.Progression.ANIMALS[kind]["sell"], "sale uses the unchanged data price")
		for survivor in before.slice(1):
			check(is_instance_valid(survivor) and survivor in group.animals(), "only the chosen animal was removed")
		check(not is_instance_valid(chosen), "chosen entity is freed")
		check(not hud.station_panel.visible, "E does not also open the station")
		var saved := ConfigFile.new()
		check(saved.load(manager.SAVE_PATH) == OK, "transaction autosaved")
		check(saved.get_value("animals", kind + "_count") == 2 and saved.get_value("inventory", "coins") == inv.coins, "count and coin reward saved together")
	counts(2)

func check_busy() -> void:
	for kind in ["chicken", "cow"]:
		var id: String = inv.Progression.ANIMALS[kind]["building"]
		var station: Node = manager.stations[id]
		for state in ["PRODUCING", "READY"]:
			if state == "READY":
				station.ready_at = Time.get_unix_time_from_system() - 1
				station._finish_production()
			var chosen: Node2D = farm.animal_groups[kind].animals()[0]
			player.global_position = chosen.get_interaction_position()
			var coins: int = inv.coins
			var data: Dictionary = station.get_save_data().duplicate(true)
			await key_e()
			check(is_instance_valid(chosen) and not chosen.sale_pending and chosen.is_inside_tree(), "busy station keeps the chosen entity")
			check(inv.coins == coins and inv.get(kind + "_count") == 2, "busy sale never changes count or coins")
			check(station.get_save_data() == data and not hud.station_panel.visible, "busy sale keeps production and never opens another object")

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	player = farm.get_node("Player")
	hud = farm.get_node("HUD")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "animal_entity_read":
		counts(2)
		for n in range(4):
			inv.inventory_changed.emit()
		counts(2)
		var saved := ConfigFile.new()
		check(saved.load(manager.SAVE_PATH) == OK, "load existing count-only schema")
		for id in ["chicken_coop", "cow_shed"]:
			check(manager.stations[id].ready_at == saved.get_value(id, "ready_at"), "production timestamps survive restart")
		check(not saved.has_section("animal_positions"), "no per-entity save schema")
		check(manager.reset_game(), "reset cleans all animal entities")
		counts(0)
	else:
		prepare()
		await sell_by_e()
		# A popup blocks the same dispatcher; a distant animal is never sold.
		var chosen: Node2D = farm.animal_groups["chicken"].animals()[0]
		player.global_position = chosen.get_interaction_position()
		hud._toggle_storage()
		await key_e()
		counts(2)
		hud._close_game_panels()
		player.global_position = Vector2(100,100)
		player.try_interact(chosen)
		counts(2)
		if stage == "animal_entity_core":
			player.global_position = chosen.get_interaction_position()
			await key_e()
			check(hud.animal_sale_confirmation.visible, "confirmation opens while station is idle")
		inv.chicken_feed = 1
		inv.cow_feed = 1
		for id in ["chicken_coop", "cow_shed"]:
			check(manager.stations[id].produce(), "unchanged production still starts after sale")
		if stage == "animal_entity_core":
			var coins_before: int = inv.coins
			hud.animal_sale_confirmation.confirmed.emit()
			check(inv.chicken_count == 2 and inv.coins == coins_before and not hud.animal_sale_confirmation.visible, "busy state is checked again when confirming")
			await check_busy()
			for id in ["chicken_coop", "cow_shed"]:
				check(manager.stations[id].collect(), "collect after rejected sale")
			check(inv.egg == 2 and inv.milk == 2, "production rewards reflect the remaining animals")
			# Two dispatcher calls open one confirmation, and repeated confirmation
			# signals cannot sell two animals.
			var animals: Array = farm.animal_groups["chicken"].animals()
			player.global_position = animals[0].get_interaction_position()
			await process_frame
			var coins: int = inv.coins
			player.try_interact(animals[0])
			player.try_interact(animals[1])
			check(inv.chicken_count == 2 and inv.coins == coins and hud.pending_sale_animal == animals[0], "same-frame spam only opens one confirmation")
			hud.animal_sale_confirmation.confirmed.emit()
			hud.animal_sale_confirmation.confirmed.emit()
			check(inv.chicken_count == 1 and inv.coins == coins + 100, "same-frame spam only rewards one sale")
			var cow: Node2D = farm.animal_groups["cow"].animals()[0]
			player.global_position = cow.get_interaction_position()
			await process_frame
			await key_e()
			check(hud.animal_sale_confirmation.visible, "open confirmation before resetting target")
			check(manager.reset_game(), "cleanup")
			check(not hud.animal_sale_confirmation.visible and hud.pending_sale_animal == null, "removing the target clears its pending confirmation")
			hud.animal_sale_confirmation.confirmed.emit()
			check(inv.coins == 100, "stale confirmation never awards coins after reset")
			counts(0)
		else:
			check(manager.save_game(), "save remaining animal entities and active timers")
	print("PASS: " + stage)
	quit()
