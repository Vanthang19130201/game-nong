extends SceneTree

var inv: Node
var manager: Node
var farm: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

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
	check(data.load(manager.SAVE_PATH) == OK, "save readable")
	return data

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	var warehouse = farm.get_node("Warehouse")
	var hud = farm.get_node("HUD")
	var player = farm.get_node("Player")
	var panel = hud.storage_panel
	check(warehouse.visible and player.farm_bounds.has_point(warehouse.position), "permanent Warehouse inside farm")
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"warehouse_core":
			check(manager.reset_game(), "reset fixture")
			check(farm.get_node("Ground").size == Vector2(2400,2400) and player.get_node("Camera2D").limit_bottom == 2400, "expanded ground and camera")
			var yard = farm.get_node("FarmYard")
			check(yard.size.y > 850 and farm.get_node("Ground").get_rect().encloses(yard.get_rect()), "expanded farm yard remains inside map")
			check(farm.get_node("Bridge").position == Vector2(1870,850) and farm.get_node("RiverRestDeck").position == Vector2(1980,1020), "bridge and river deck stay separate beside the eastern bank")
			player.position = Vector2(300,400)
			await create_timer(0.1).timeout
			check(not warehouse.can_interact() and warehouse.get_node("Visuals/Prompt").text.is_empty(), "no permanent prompt or distant access")
			hud.open_warehouse(warehouse)
			check(not panel.visible, "cannot open remotely")
			player.position = warehouse.position + Vector2(0,90)
			await create_timer(0.1).timeout
			check(warehouse.can_interact() and warehouse.get_node("Visuals/Prompt").text == "[E] Mở Kho", "nearby interaction range")
			await key(KEY_E)
			check(panel.visible and hud.blocks_world_input() and not hud.house_panel.visible and not hud.shop_build_panel.visible, "E opens one shared Storage modal")
			var seeds: int = inv.wheat_seed
			await key(KEY_E)
			check(panel.visible and inv.wheat_seed == seeds, "spam E blocked behind Warehouse panel")
			var position_before: Vector2 = player.position
			Input.action_press("move_down")
			await create_timer(0.1).timeout
			Input.action_release("move_down")
			check(player.position == position_before, "world movement locked")
			check(panel.tabs.get_tab_count() == 3, "three existing inventory tabs")
			check(inv.add_item("flax",1) and inv.add_item("bread",1), "existing crop/goods inventory")
			check(panel.item_cells["flax"].quantity == 1 and panel.item_cells["bread"].quantity == 1, "same inventory updates immediately")
			inv.wood = 100
			inv.stone = 100
			inv.coins = 10000
			inv.inventory_changed.emit()
			panel.upgrade_rows["silo"]["button"].pressed.emit()
			check(inv.silo_level == 2 and inv.silo_capacity == 50 and inv.wood == 90 and inv.stone == 95 and inv.coins == 9800, "Silo exact existing upgrade")
			check(panel.upgrade_rows["silo"]["label"].text.contains("50 → 80") and disk().get_value("upgrades","silo_level") == 2, "upgrade UI and autosave")
			panel.upgrade_rows["barn"]["button"].pressed.emit()
			check(inv.barn_level == 2 and inv.barn_capacity == 35 and inv.wood == 82 and inv.stone == 87 and inv.coins == 9550, "Barn exact existing upgrade")
			inv.wood = 0
			inv.stone = 0
			inv.coins = 0
			panel.upgrade_rows["barn"]["button"].pressed.emit()
			check(inv.barn_level == 2 and inv.coins == 0 and inv.wood == 0, "failed upgrade changes nothing")
			await key(KEY_ESCAPE)
			check(not panel.visible and not hud.blocks_world_input(), "ESC closes Warehouse")
			await key(KEY_TAB)
			check(panel.visible, "Tab opens same panel")
			await key(KEY_P)
			check(not panel.visible and hud.shop_build_panel.visible, "P replaces Warehouse modal")
			await key(KEY_ESCAPE)
			player.position = Vector2(800,1900)
			Input.action_press("move_down")
			await create_timer(0.2).timeout
			Input.action_release("move_down")
			check(player.position.y > 1920, "south expansion accessible")
			player.position = Vector2(1755,2150)
			Input.action_press("move_right")
			await create_timer(0.5).timeout
			Input.action_release("move_right")
			check(player.position.x < 1800 and not inv.fishing_unlocked, "extended river blocks level-1 bypass")
			root.size = Vector2i(360,640)
			await create_timer(0.1).timeout
			panel._fit_viewport()
			var available: Vector2 = panel.get_viewport_rect().size - Vector2(24,32)
			check(panel.size.x <= available.x and panel.size.y <= available.y, "upgrade panel fits mobile viewport")
			check(manager.reset_game() and warehouse.visible and inv.silo_level == 1 and inv.barn_level == 1, "reset keeps Warehouse and resets upgrades")
		"warehouse_write":
			check(manager.reset_game(), "save fixture")
			inv.coins = 4321
			inv.flax_seed = 3
			farm.get_node("House").position = Vector2(650,400)
			inv.inventory_changed.emit()
			check(not disk().has_section("warehouse"), "no duplicate Warehouse inventory/save section")
		"warehouse_read":
			check(inv.coins == 4321 and inv.flax_seed == 3 and farm.get_node("House").position == Vector2(650,400), "existing values and building positions preserved")
			check(warehouse.visible, "Warehouse always present after load")
			check(manager.reset_game() and warehouse.visible and inv.coins == 100, "clean reset keeps default Warehouse")
	print("PASS: " + stage)
	quit()
