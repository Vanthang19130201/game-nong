extends SceneTree

var inv: Node
var manager: Node
var farm: Node
var hud: Node
var player: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value,message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK,"save readable")
	return data

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = player.get_canvas_transform()*point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	await create_timer(0.03).timeout
	event = InputEventMouseButton.new()
	event.position = player.get_canvas_transform()*point
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event,true)
	await create_timer(0.03).timeout

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.03).timeout
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await create_timer(0.03).timeout

func fund() -> void:
	inv.coins = 100000
	inv.wood = 500
	inv.stone = 500
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.normalize_exp()
	inv.inventory_changed.emit()

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"land_core":
			check(manager.reset_game(),"fixture reset")
			check(manager.unlocked_land_zones == ["farm_core"] and get_nodes_in_group("land_zones").size() == 7,"seven zones, core only default")
			check(not manager.purchase_land("land_01") and inv.coins == 100,"insufficient resources atomic")
			fund()
			var funds: Array = [inv.coins,inv.wood,inv.stone]
			check(not manager.purchase_land("land_06") and [inv.coins,inv.wood,inv.stone] == funds,"disconnected land cannot be bought")
			check(inv.buy_building("feed_mill"),"placement source")
			var mill = manager.buildings["feed_mill"]
			check(not hud.edit_farm.Placement.can_place(mill,Vector2(320,1664)),"placement rejects locked land")
			check(not hud.edit_farm.Placement.can_place(mill,Vector2(320,1472)),"footprint cannot cross into locked land")
			var resource = manager.resources["tree_1"]
			resource.global_position = Vector2(320,1664)
			resource.respawn_at = Time.get_unix_time_from_system()+120
			resource._update_zone(true)
			check(resource.visible and not resource.zone_active and resource.respawn_timer.is_stopped(),"locked resources visible but inactive")
			player.position = Vector2(300,1710)
			player.get_node("Camera2D").reset_smoothing()
			await create_timer(0.1).timeout
			await click(Vector2(300,1710))
			check(hud.land_panel.visible and hud.blocks_world_input() and not resource.harvest(),"click locked zone opens modal and blocks gathering")
			await key(KEY_ESCAPE)
			check(not hud.land_panel.visible,"ESC closes land panel")
			await click(Vector2(300,1710))
			funds = [inv.coins,inv.wood,inv.stone]
			hud.land_panel.buy_button.pressed.emit()
			hud.land_panel.buy_button.pressed.emit()
			check([inv.coins,inv.wood,inv.stone] == [funds[0]-500,funds[1]-10,funds[2]-5],"land_01 exact one-time cost")
			check(not manager.purchase_land("land_01") and not hud.land_panel.visible,"spam cannot deduct twice")
			check("land_01" in disk().get_value("land","unlocked_land_zones") and not farm.get_node("land_01").sign.visible,"ownership autosave and overlay removed")
			check(resource.zone_active and resource.respawn_timer.time_left > 100,"resource timer resumes on unlock")
			resource.global_position = Vector2(450,220)
			check(hud.edit_farm.Placement.can_place(mill,Vector2(320,1472)),"owned footprint may span core boundary")
			check(not hud.edit_farm.Placement.can_place(mill,Vector2(576,1664)),"partial overlap with next locked zone denied")
			check(manager.purchase_land("land_02") and hud.edit_farm.Placement.can_place(mill,Vector2(576,1664)),"two owned neighbors allow spanning footprint")
			check(manager.purchase_land("land_04") and manager.purchase_land("land_05"),"adjacent nonlinear expansion")
			hud.edit_farm.enter_mode()
			hud.edit_farm.select_building(mill)
			hud.edit_farm.begin_move()
			await click(Vector2(1500,2150))
			check(not hud.land_panel.visible and mill.position == inv.FarmData.BUILDINGS["feed_mill"]["position"],"placement click cannot buy land or move onto locked zone")
			check(manager.reset_game() and manager.unlocked_land_zones == ["farm_core"] and not hud.edit_farm.active,"reset relocks land and cancels move")
			check(farm.get_node("land_01").sign.visible,"reset restores locked visual")
		"land_write":
			check(manager.reset_game(),"write fixture")
			fund()
			check(manager.purchase_land("land_01") and manager.purchase_land("land_04"),"unlock connected land")
			check(inv.buy_building("feed_mill"),"move fixture")
			hud.edit_farm.enter_mode()
			hud.edit_farm.select_building(manager.buildings["feed_mill"])
			hud.edit_farm.begin_move()
			hud.edit_farm.update_preview(Vector2(320,2112))
			check(hud.edit_farm.place_move(),"placement in purchased land")
			hud.edit_farm.exit_mode()
		"land_read":
			check(manager.unlocked_land_zones == ["farm_core","land_01","land_04"],"ownership reload")
			check(manager.buildings["feed_mill"].position == Vector2(320,2112),"owned-land building remains after reload")
			check(manager.reset_game() and manager.buildings["feed_mill"].position == inv.FarmData.BUILDINGS["feed_mill"]["position"],"reset moves buildings back to defaults")
		"land_reset_read":
			check(manager.unlocked_land_zones == ["farm_core"] and not inv.owns_feed_mill,"reset ownership persists")
			check(farm.get_node("land_04").sign.visible,"locked visual after reset reload")
		"land_legacy_write":
			check(manager.reset_game(),"legacy fixture")
			fund()
			for id in ["feed_mill","bakery","chicken_coop"]:
				check(inv.buy_building(id),"legacy owned building")
			inv.wheat = 3
			inv.corn = 1
			check(manager.stations["feed_mill"].produce() and farm.get_node("Bakery").enqueue("bread"),"legacy production")
			var data: ConfigFile = disk()
			data.erase_section("land")
			data.set_value("building_positions","feed_mill",Vector2(512,1664))
			data.set_value("building_positions","bakery",Vector2(512,1984))
			data.set_value("building_positions","chicken_coop",Vector2(1500,1472))
			check(data.save(manager.SAVE_PATH) == OK,"write pre-land save")
		"land_legacy_read":
			check(manager.unlocked_land_zones == ["farm_core"],"legacy save core only")
			for id in ["feed_mill","bakery","chicken_coop"]:
				check(inv.owns_building(id) and manager.LandData.owns_rect(hud.edit_farm.Placement.bounds(manager.buildings[id]),manager.unlocked_land_zones),"legacy building safely migrated " + id)
			check(manager.stations["feed_mill"].ready_at == disk().get_value("feed_mill","ready_at") and manager.bakery_queue.size() == 1,"migration preserves production queue and timestamp")
			check(manager.reset_game(),"cleanup")
	print("PASS: " + stage)
	quit()
