extends SceneTree

# Isolated regression coverage for the title -> character creation -> new farm
# boundary.  It deliberately tests data, not gameplay balancing.
var manager: Node
var inventory: Node
var clock: Node


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(ok, message)


func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK, "test save is readable")
	return data


func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inventory = root.get_node("Inventory")
	clock = root.get_node("GameClock")
	check(manager.SAVE_PATH == "res://test-save.cfg", "test never uses player save")

	check(manager.reset_game(), "create old-game fixture")
	inventory.coins = 9876
	inventory.wood = 44
	inventory.player_level = 10
	inventory.player_exp = 555
	manager.bakery_queue = [{"recipe": "bread", "started_at": 1.0}]
	clock.restore({"day": 8, "minutes": 1300.0, "season": "spring", "absolute_day": 8})
	check(manager.save_game(), "persist old-game fixture")
	var old_save := disk().encode_to_text()

	# Merely opening or cancelling character creation cannot touch disk/runtime.
	check(manager.reset_for_character_selection(), "open character creation safely")
	check(manager.character_selection_pending, "selection pending only in runtime")
	check(inventory.coins == 9876 and inventory.player_level == 10, "opening selection preserves old runtime")
	check(disk().encode_to_text() == old_save, "opening selection preserves old save")
	manager.cancel_character_selection()
	check(not manager.character_selection_pending, "cancel clears transient selection flag")
	check(disk().encode_to_text() == old_save, "cancel preserves old save")

	# Confirmation creates a fully fresh default state and then overwrites once.
	check(manager.reset_for_character_selection(), "reopen character creation safely")
	check(manager.start_new_game("farmer_03", "Fresh Farmer"), "confirm fresh new game")
	check(manager.has_existing_game and not manager.character_selection_pending, "confirmed game becomes continue-able")
	check(manager.player_name == "Fresh Farmer" and manager.selected_character_id == "farmer_03", "fresh character saved")
	check(inventory.coins == manager.INVENTORY_DEFAULTS["coins"], "old coins do not leak")
	check(inventory.wood == manager.INVENTORY_DEFAULTS["wood"], "old materials do not leak")
	check(inventory.player_level == 1 and inventory.player_exp == 0, "old progression does not leak")
	check(manager.bakery_queue.is_empty(), "old production queue does not leak")
	check(clock.day == 1 and is_equal_approx(clock.minutes, 360.0), "new game calendar uses project default")
	check(disk().get_value("player", "player_name") == "Fresh Farmer", "fresh save was written")

	# Continue clears transient singleton state before deserializing the save.
	inventory.coins = 777
	clock.restore({"day": 3, "minutes": 600.0, "season": "spring", "absolute_day": 3})
	check(manager.save_game(), "write continue fixture")
	inventory.coins = 1
	clock.restore({"day": 1, "minutes": 360.0, "season": "spring", "absolute_day": 1})
	check(manager.prepare_continue_game(), "continue reloads save")
	check(inventory.coins == 777 and clock.day == 3, "continue replaces transient runtime state")
	print("PASS: new_game_flow")
	quit()
