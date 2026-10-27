extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var hud: Node
var player: Node2D
var spot: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, description: String) -> void:
	if not value:
		push_error("TEST FAILED: " + description)
		quit(1)
		assert(value, description)

func key(code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await create_timer(0.04).timeout
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await create_timer(0.04).timeout

func fish_count() -> int:
	return inv.small_fish + inv.river_fish + inv.golden_fish

func start_session() -> bool:
	var target: Dictionary = player._find_fishing_target()
	if target.is_empty():
		return false
	return spot.start_free_session(
		player,
		target["point"],
		target["water_id"]
	)

func end_cooldown() -> void:
	spot.cancel_session()
	check(spot.state == spot.State.IDLE, "cooldown returns idle")

func begin_bite() -> void:
	spot.deadline = spot.now() - 0.01
	spot._advance_state()
	check(spot.state == spot.State.BITE_WINDOW, "bite window begins")

func run_checks() -> void:
	await process_frame
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	spot = farm.get_node("FishingSpot")
	var pond = farm.get_node("FishingPond")
	await create_timer(0.1).timeout
	check(pond.shape_mode == "polygon", "main fishing pond uses an irregular polygon")
	check(pond.contains_world_point(Vector2(2240, 1190)), "pond center is fishable water")
	check(pond.position.x > 2200 and pond.position.x + 151 * 1.05 <= 2400, "pond and sandy bank stay at the eastern map edge")
	var river_to_pond_gap: float = pond.position.x - 151 * 1.05 - 1940
	check(river_to_pond_gap >= 140.0 and river_to_pond_gap <= 180.0, "land strip between river and outer pond bank is 140-180 pixels")
	check(farm.get_node("RiverRestDeck").position == Vector2(1980, 1020), "river deck is beside the eastern river bank")
	check(farm.get_node("PondRestDeck").position == Vector2(2048, 1450), "pond deck is beside the pond's left bank")
	check(farm.get_node("RiverRestDeck").get_child_count() == 0 and farm.get_node("PondRestDeck").get_child_count() == 0, "rest decks are decoration only")
	check(farm.get_node("RiverRestDeck").position.distance_to(farm.get_node("Bridge").position) > 180.0, "river deck stays clear of the bridge")
	var bridge_visual_bounds := Rect2(Vector2(1758, 780), Vector2(224, 140))
	var river_deck_visual_bounds := Rect2(Vector2(1943, 963), Vector2(74, 114))
	check(not bridge_visual_bounds.intersects(river_deck_visual_bounds), "river deck artwork does not overlap the bridge")
	check(get_nodes_in_group("fishing_session_manager").size() == 1, "both rest decks reuse the single fishing manager")
	check(not pond.contains_world_point(Vector2(1940, 1190)), "river bank remains outside the pond")
	check(farm.get_node("FishMarket").position.y > pond.position.y + 700, "Fish Market is below the pond")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "fishing_read":
		check(inv.has_fishing_rod and inv.fishing_rod_level == 3, "rod save restore")
		check(inv.fishing_attempts_used == 1 and inv.fishing_attempts_remaining() == 14 and inv.fishing_cycle_started_at > 0.0, "attempt charge survives restart")
		check(inv.small_fish == 2 and inv.river_fish == 3 and inv.golden_fish == 1, "fish save restore")
		check(spot.state == spot.State.IDLE and inv.reserved_barn_slots == 0 and hud.fishing_ui.active_spot == null, "session not restored/no free reward")
	else:
		check(manager.reset_game(), "reset isolated fixture")
		inv.tools_unlock_notified = true
		inv.player_level = 9
		player.position = Vector2(1980, 1190)
		player.facing_vector = Vector2.RIGHT
		await create_timer(0.1).timeout
		check(not spot.can_interact(), "spot locked before level 10")
		inv.add_exp(900)
		check(inv.player_level == 10 and inv.has_fishing_rod and inv.fishing_rod_level == 1, "level 10 grants base rod")
		hud.hotbar.select_slot(7)
		player.facing_vector = Vector2.LEFT
		var river_target: Dictionary = player._find_fishing_target()
		check(river_target.get("water_id", "") == "river", "east bank can cast into the old river")
		player.facing_vector = Vector2.DOWN
		check(player._find_fishing_target().is_empty(), "only water in front enables fishing")
		player.facing_vector = Vector2.RIGHT
		check(not player._find_fishing_target().is_empty(), "facing pond bank finds free cast point")
		await create_timer(0.1).timeout
		if stage == "fishing_write":
			inv.coins = 2800
			check(inv.upgrade_fishing_rod() and inv.upgrade_fishing_rod(), "rod purchase persistence")
			check(inv.add_item("small_fish",2) and inv.add_item("river_fish",3) and inv.add_item("golden_fish",1), "fish persistence fixture")
			check(start_session(), "start session before closing")
			check(manager.save_game(), "save mid-session")
			var data := ConfigFile.new()
			check(data.load(manager.SAVE_PATH) == OK and not data.has_section("fishing_session"), "no transient state saved")
		elif stage == "fishing_limits":
			await check_limits()
		else:
			await check_fishing()
	print("PASS: ", stage)
	quit()

func check_fishing() -> void:
	check(hud.fishing_ui.fish_button.visible, "mobile Fish available near spot")
	spot.rng.seed = 12345
	var sampled: Array = []
	for index in range(5):
		check(start_session(), "start randomized session")
		check(spot.bite_delay >= 1.0 and spot.bite_delay <= 5.0, "delay inside 1-5 seconds")
		sampled.append(snappedf(spot.bite_delay,0.01))
		spot.cancel_session()
	check(sampled[0] != sampled[1], "each session samples a new random delay")
	check(fish_count() == 0 and inv.reserved_barn_slots == 0, "cancel grants nothing/releases slot")
	check(inv.fishing_attempts_used == 5, "cancel consumes attempts")
	inv.fishing_cycle_started_at = Time.get_unix_time_from_system() - inv.FishingData.CYCLE_SECONDS
	inv.refresh_fishing_cycle()
	await process_frame
	check(player.fishing_prompt.visible, "valid bank position shows fishing prompt")
	await key(KEY_E)
	check(spot.state == spot.State.WAITING_FOR_BITE and hud.fishing_ui.active_spot == spot, "E starts session from the same target as the prompt")
	var original_deadline: float = spot.deadline
	await key(KEY_E, true)
	check(spot.deadline == original_deadline and spot.state == spot.State.WAITING_FOR_BITE, "held key echo ignored")
	await key(KEY_E)
	check(spot.deadline == original_deadline and spot.state == spot.State.WAITING_FOR_BITE, "E does not reel while waiting")
	await key(KEY_SPACE)
	check(spot.state == spot.State.FAILED and spot.feedback.contains(tr("FISHING_TOO_EARLY")), "early input fails")
	for index in range(5):
		await key(KEY_E)
	check(fish_count() == 0 and not start_session(), "spam cannot restart or win")
	hud.fishing_ui.close_session()
	await process_frame
	check(spot.can_interact(), "dock click availability follows water in front, not dock distance")
	end_cooldown()
	# Real-time wait and one-second timeout, without manually completing either phase.
	check(start_session(), "start real miss test")
	await create_timer(spot.bite_delay + 0.08).timeout
	check(spot.state == spot.State.BITE_WINDOW and fish_count() == 0, "real random bite gives no automatic fish")
	await create_timer(1.05).timeout
	check(spot.state == spot.State.FAILED and spot.feedback.contains(tr("FISHING_MISSED")), "one-second miss")
	end_cooldown()
	# Real keyboard success follows exactly the same state clock.
	await key(KEY_E)
	await create_timer(maxf(0.001,spot.deadline-spot.now()+0.02)).timeout
	check(spot.state == spot.State.BITE_WINDOW, "real success window")
	await key(KEY_E)
	check(spot.state == spot.State.BITE_WINDOW and fish_count() == 0, "E does not reel in bite window")
	await key(KEY_SPACE)
	check(spot.state == spot.State.SUCCESS and fish_count() == 1, "keyboard success grants one fish")
	await key(KEY_SPACE)
	check(fish_count() == 1, "success cannot duplicate fish")
	end_cooldown()
	# Touch-ready buttons use the same start/reel logic, including early failures.
	hud.fishing_ui.fish_button.pressed.emit()
	hud.fishing_ui.reel_button.pressed.emit()
	check(spot.state == spot.State.FAILED and fish_count() == 1, "mobile early input also fails")
	end_cooldown()
	await create_timer(0.16).timeout
	hud.fishing_ui.fish_button.pressed.emit()
	begin_bite()
	hud.fishing_ui.reel_button.pressed.emit()
	check(spot.state == spot.State.SUCCESS and fish_count() == 2, "mobile reel catches fish")
	end_cooldown()
	# No start when full; reserve the last slot against other Barn consumers.
	inv.egg = inv.barn_capacity - fish_count()
	check(not start_session() and inv.reserved_barn_slots == 0, "full barn refuses start")
	inv.egg -= 1
	check(start_session() and inv.reserved_barn_slots == 1, "last Barn slot reserved")
	check(not inv.add_item("milk",1), "other collect cannot consume reserved slot")
	begin_bite()
	hud.fishing_ui.reel_button.pressed.emit()
	check(fish_count() == 3 and inv.storage_used("barn") == inv.barn_capacity, "catch kept in last slot")
	end_cooldown()
	inv.egg = 0
	# Movement stays locked during the session; ESC cancels and restores control.
	check(start_session(), "start movement lock test")
	var fishing_origin: Vector2 = player.global_position
	Input.action_press("move_down")
	await create_timer(0.8).timeout
	Input.action_release("move_down")
	check(player.global_position.distance_to(fishing_origin) < 1.0 and spot.state == spot.State.WAITING_FOR_BITE, "Player movement locked while fishing")
	hud.fishing_ui.close_session()
	check(spot.state == spot.State.IDLE and hud.fishing_ui.active_spot == null and inv.reserved_barn_slots == 0 and fish_count() == 3, "closing session releases reservation without reward")
	await create_timer(0.1).timeout
	await key(KEY_E)
	await key(KEY_ESCAPE)
	check(spot.state == spot.State.IDLE and inv.reserved_barn_slots == 0 and not hud.fishing_ui.panel.visible, "ESC cleanup")
	check(start_session(), "start modal cancellation")
	hud.open_build()
	check(spot.state == spot.State.IDLE and inv.reserved_barn_slots == 0, "another main panel cancels fishing")
	hud.close_all_panels()
	# Upgrade costs and actual window are data-driven; no upgrade automates fishing.
	inv.coins = 799
	check(not inv.upgrade_fishing_rod() and inv.fishing_rod_level == 1 and inv.coins == 799, "insufficient rod funds unchanged")
	inv.coins = 800
	hud.rod_upgrade.pressed.emit()
	check(inv.fishing_rod_level == 2 and inv.coins == 0, "shop rod Lv2 purchase")
	check(start_session() and is_equal_approx(spot.bite_window,0.6), "Lv2 reaction window")
	begin_bite()
	await create_timer(0.52).timeout
	hud.fishing_ui.reel_button.pressed.emit()
	check(spot.state == spot.State.SUCCESS, "Lv2 can catch after the base half-second window")
	end_cooldown()
	for level in [3,4]:
		inv.coins = inv.FishingData.ROD_LEVELS[level]["cost"]
		check(inv.upgrade_fishing_rod(), "rod upgrade")
		check(start_session() and is_equal_approx(spot.bite_window,inv.FishingData.ROD_LEVELS[level]["bite_window"]), "upgraded window")
		spot.cancel_session()
	check(not inv.upgrade_fishing_rod() and inv.fishing_rod_level == 4, "rod max level")
	# Deterministic statistical check of reward weights; sampling does not grant items.
	spot.rng.seed = 9876
	var counts: Dictionary = {"small_fish":0,"river_fish":0,"golden_fish":0}
	for index in range(10000):
		counts[spot._roll_fish()] += 1
	check(absf(counts["small_fish"]/10000.0 - 0.6) < 0.025 and absf(counts["river_fish"]/10000.0 - 0.3) < 0.025 and absf(counts["golden_fish"]/10000.0 - 0.1) < 0.025, "60/30/10 reward table")
	check(start_session(), "reset mid-session")
	check(manager.reset_game(), "reset fishing data")
	check(spot.state == spot.State.IDLE and inv.reserved_barn_slots == 0 and fish_count() == 0 and not inv.has_fishing_rod and inv.fishing_rod_level == 0, "reset clears fish/rod/session")
	check(inv.fishing_attempts_used == 0 and inv.fishing_cycle_started_at == 0.0, "reset clears attempt cycle")


func check_limits() -> void:
	inv.egg = inv.barn_capacity
	check(not start_session() and inv.fishing_attempts_used == 0, "Barn full costs no attempt")
	inv.egg = 0
	for index in range(15):
		check(start_session(), "cast within limit")
		spot.cancel_session()
		check(inv.fishing_attempts_used == index + 1, "cast charged once even on cancel")
	check(not start_session() and inv.fishing_attempts_used == 15 and inv.reserved_barn_slots == 0, "sixteenth cast blocked")
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK and data.get_value("fishing","fishing_attempts_used") == 15, "attempts persisted immediately")
	var started: float = inv.fishing_cycle_started_at
	inv.add_exp(100)
	check(inv.fishing_cycle_started_at == started and inv.fishing_attempts_used == 15, "level/EXP cannot reset cycle")
	inv.fishing_cycle_started_at = Time.get_unix_time_from_system() - 43199.5
	check(inv.fishing_attempts_remaining() == 0, "before twelve hours remains exhausted")
	while Time.get_unix_time_from_system() < inv.fishing_cycle_started_at + inv.FishingData.CYCLE_SECONDS:
		await create_timer(0.05).timeout
	check(inv.fishing_attempts_remaining() == 15 and start_session(), "twelve hours replenishes attempts")
	spot.cancel_session()
	check(inv.fishing_attempts_used == 1 and inv.fishing_attempts_remaining() == 14, "new cycle starts at first cast")
