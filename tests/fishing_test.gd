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

func end_cooldown() -> void:
	spot.deadline = spot.now() - 1.0
	spot._advance_state()
	spot.deadline = spot.now() - 1.0
	spot._advance_state()
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
	await create_timer(0.1).timeout
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
		player.position = spot.position
		await create_timer(0.1).timeout
		check(not spot.can_interact(), "spot locked before level 10")
		inv.add_exp(900)
		check(inv.player_level == 10 and inv.has_fishing_rod and inv.fishing_rod_level == 1, "level 10 grants base rod")
		await create_timer(0.1).timeout
		if stage == "fishing_write":
			inv.coins = 2800
			check(inv.upgrade_fishing_rod() and inv.upgrade_fishing_rod(), "rod purchase persistence")
			check(inv.add_item("small_fish",2) and inv.add_item("river_fish",3) and inv.add_item("golden_fish",1), "fish persistence fixture")
			check(spot.start_session(player), "start session before closing")
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
		check(spot.start_session(player), "start randomized session")
		check(spot.bite_delay >= 1.0 and spot.bite_delay <= 5.0, "delay inside 1-5 seconds")
		sampled.append(snappedf(spot.bite_delay,0.01))
		spot.cancel_session()
	check(sampled[0] != sampled[1], "each session samples a new random delay")
	check(fish_count() == 0 and inv.reserved_barn_slots == 0, "cancel grants nothing/releases slot")
	check(inv.fishing_attempts_used == 5, "cancel consumes attempts")
	inv.fishing_cycle_started_at = Time.get_unix_time_from_system() - inv.FishingData.CYCLE_SECONDS
	inv.refresh_fishing_cycle()
	await key(KEY_E)
	check(spot.state == spot.State.WAITING_FOR_BITE, "E starts session")
	var original_deadline: float = spot.deadline
	await key(KEY_E, true)
	check(spot.deadline == original_deadline and spot.state == spot.State.WAITING_FOR_BITE, "held key echo ignored")
	await key(KEY_E)
	check(spot.state == spot.State.FAILED and spot.feedback.contains("Too early"), "early input fails")
	for index in range(5):
		await key(KEY_E)
	check(fish_count() == 0 and not spot.start_session(player), "spam cannot restart or win")
	hud.fishing_ui.close_session()
	check(not spot.can_interact(), "closing result does not skip cooldown")
	end_cooldown()
	# Real-time wait and one-second timeout, without manually completing either phase.
	check(spot.start_session(player), "start real miss test")
	await create_timer(spot.bite_delay + 0.08).timeout
	check(spot.state == spot.State.BITE_WINDOW and fish_count() == 0, "real random bite gives no automatic fish")
	await create_timer(1.05).timeout
	check(spot.state == spot.State.FAILED and spot.feedback == "The fish got away!", "one-second miss")
	end_cooldown()
	# Real keyboard success follows exactly the same state clock.
	await key(KEY_E)
	await create_timer(spot.bite_delay + 0.02).timeout
	check(spot.state == spot.State.BITE_WINDOW, "real success window")
	await key(KEY_E)
	check(spot.state == spot.State.SUCCESS and fish_count() == 1, "keyboard success grants one fish")
	await key(KEY_E)
	check(fish_count() == 1, "success cannot duplicate fish")
	end_cooldown()
	# Touch-ready buttons use the same start/reel logic, including early failures.
	hud.fishing_ui.fish_button.pressed.emit()
	hud.fishing_ui.reel_button.pressed.emit()
	check(spot.state == spot.State.FAILED and fish_count() == 1, "mobile early input also fails")
	end_cooldown()
	hud.fishing_ui.fish_button.pressed.emit()
	begin_bite()
	hud.fishing_ui.reel_button.pressed.emit()
	check(spot.state == spot.State.SUCCESS and fish_count() == 2, "mobile reel catches fish")
	end_cooldown()
	# No start when full; reserve the last slot against other Barn consumers.
	inv.egg = inv.barn_capacity - fish_count()
	check(not spot.start_session(player) and inv.reserved_barn_slots == 0, "full barn refuses start")
	inv.egg -= 1
	check(spot.start_session(player) and inv.reserved_barn_slots == 1, "last Barn slot reserved")
	check(not inv.add_item("milk",1), "other collect cannot consume reserved slot")
	begin_bite()
	hud.fishing_ui.reel_button.pressed.emit()
	check(fish_count() == 3 and inv.storage_used("barn") == inv.barn_capacity, "catch kept in last slot")
	end_cooldown()
	inv.egg = 0
	# Walk away cancels cleanly; movement is intentionally available while fishing.
	check(spot.start_session(player), "start departure test")
	check(not hud.blocks_world_input(), "fishing allows movement to cancel")
	Input.action_press("move_right")
	await create_timer(0.8).timeout
	Input.action_release("move_right")
	check(spot.state == spot.State.IDLE and hud.fishing_ui.active_spot == null and inv.reserved_barn_slots == 0 and fish_count() == 3, "walking away cancels without reward")
	player.position = spot.position
	await create_timer(0.1).timeout
	await key(KEY_E)
	await key(KEY_ESCAPE)
	check(spot.state == spot.State.IDLE and inv.reserved_barn_slots == 0 and not hud.fishing_ui.panel.visible, "ESC cleanup")
	check(spot.start_session(player), "start modal cancellation")
	hud.open_build()
	check(spot.state == spot.State.IDLE and inv.reserved_barn_slots == 0, "another main panel cancels fishing")
	hud.close_all_panels()
	# Upgrade costs and actual window are data-driven; no upgrade automates fishing.
	inv.coins = 799
	check(not inv.upgrade_fishing_rod() and inv.fishing_rod_level == 1 and inv.coins == 799, "insufficient rod funds unchanged")
	inv.coins = 800
	hud.rod_upgrade.pressed.emit()
	check(inv.fishing_rod_level == 2 and inv.coins == 0, "shop rod Lv2 purchase")
	check(spot.start_session(player) and is_equal_approx(spot.bite_window,0.6), "Lv2 reaction window")
	begin_bite()
	await create_timer(0.52).timeout
	hud.fishing_ui.reel_button.pressed.emit()
	check(spot.state == spot.State.SUCCESS, "Lv2 can catch after the base half-second window")
	end_cooldown()
	for level in [3,4]:
		inv.coins = inv.FishingData.ROD_LEVELS[level]["cost"]
		check(inv.upgrade_fishing_rod(), "rod upgrade")
		check(spot.start_session(player) and is_equal_approx(spot.bite_window,inv.FishingData.ROD_LEVELS[level]["bite_window"]), "upgraded window")
		spot.cancel_session()
	check(not inv.upgrade_fishing_rod() and inv.fishing_rod_level == 4, "rod max level")
	# Deterministic statistical check of reward weights; sampling does not grant items.
	spot.rng.seed = 9876
	var counts: Dictionary = {"small_fish":0,"river_fish":0,"golden_fish":0}
	for index in range(10000):
		counts[spot._roll_fish()] += 1
	check(absf(counts["small_fish"]/10000.0 - 0.6) < 0.025 and absf(counts["river_fish"]/10000.0 - 0.3) < 0.025 and absf(counts["golden_fish"]/10000.0 - 0.1) < 0.025, "60/30/10 reward table")
	check(spot.start_session(player), "reset mid-session")
	check(manager.reset_game(), "reset fishing data")
	check(spot.state == spot.State.IDLE and inv.reserved_barn_slots == 0 and fish_count() == 0 and not inv.has_fishing_rod and inv.fishing_rod_level == 0, "reset clears fish/rod/session")
	check(inv.fishing_attempts_used == 0 and inv.fishing_cycle_started_at == 0.0, "reset clears attempt cycle")


func check_limits() -> void:
	inv.egg = inv.barn_capacity
	check(not spot.start_session(player) and inv.fishing_attempts_used == 0, "Barn full costs no attempt")
	inv.egg = 0
	for index in range(15):
		check(spot.start_session(player), "cast within limit")
		spot.cancel_session()
		check(inv.fishing_attempts_used == index + 1, "cast charged once even on cancel")
	check(not spot.start_session(player) and inv.fishing_attempts_used == 15 and inv.reserved_barn_slots == 0, "sixteenth cast blocked")
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK and data.get_value("fishing","fishing_attempts_used") == 15, "attempts persisted immediately")
	var started: float = inv.fishing_cycle_started_at
	inv.add_exp(100)
	check(inv.fishing_cycle_started_at == started and inv.fishing_attempts_used == 15, "level/EXP cannot reset cycle")
	inv.fishing_cycle_started_at = Time.get_unix_time_from_system() - 43199.5
	check(inv.fishing_attempts_remaining() == 0, "before twelve hours remains exhausted")
	while Time.get_unix_time_from_system() < inv.fishing_cycle_started_at + inv.FishingData.CYCLE_SECONDS:
		await create_timer(0.05).timeout
	check(inv.fishing_attempts_remaining() == 15 and spot.start_session(player), "twelve hours replenishes attempts")
	spot.cancel_session()
	check(inv.fishing_attempts_used == 1 and inv.fishing_attempts_remaining() == 14, "new cycle starts at first cast")
