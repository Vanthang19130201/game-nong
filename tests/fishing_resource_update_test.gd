extends SceneTree

const NEW_IDS: Array[String] = ["tree_6","tree_7","tree_8","rock_4"]
var inv: Node
var manager: Node
var farm: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value,message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK,"isolated save readable")
	return data

func check_layout() -> void:
	var counts: Dictionary = {"wood":0,"stone":0}
	check(manager.resources.size() == 12 and manager.plots.size() == 32,"12 unique resources; 32 plots unchanged")
	for resource in manager.resources.values():
		counts[resource.resource_type] += 1
		check(resource.global_position.x < 1800,"no resources in River or Fishing Area")
		check(resource.visible and farm.Placement.can_place(resource,resource.global_position,false),"resource avoids map objects: " + resource.resource_id)
	check(counts == {"wood":8,"stone":4},"8 Trees and 4 Rocks, 50 percent more")

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg","never use player save")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"resource_update_core":
			check(manager.reset_game(),"reset fixture")
			check_layout()
			var space_bound: bool = false
			for event in InputMap.action_get_events("fishing_reel"):
				if event is InputEventKey and event.physical_keycode == KEY_SPACE:
					space_bound = true
			check(space_bound,"SPACE bound to fishing_reel")
			inv.wood = 4
			check(not inv.build_dog_house() and inv.wood == 4 and not inv.has_dog_house,"insufficient Wood leaves funds intact")
			inv.wood = 5
			check(inv.stone == 0 and inv.build_dog_house(),"Dog House needs only 5 Wood, no Stone or Dog")
			check(inv.has_dog_house and inv.wood == 0 and inv.stone == 0 and inv.coins == 100,"Dog House exact new cost")
			check(not inv.build_dog_house() and inv.coins == 100,"duplicate Dog House blocked")
			inv.coins = 300
			check(inv.buy_dog() and inv.coins == 0,"Dog still costs 300 Coins")
			for id in ["tree_7","tree_8","rock_4"]:
				var resource = manager.resources[id]
				var deadline: float = Time.get_unix_time_from_system()-10
				resource.restore_save_data({"respawn_at":deadline,"rock_type":"large_rock"})
				resource._respawn()
				check(not resource.zone_active and not resource.harvest() and resource.respawn_timer.is_stopped() and resource.respawn_at == deadline,"locked resource cannot gather or respawn: " + id)
			check(manager.reset_game(),"core cleanup")
		"resource_update_write":
			check(manager.reset_game(),"write fixture")
			inv.player_level = 12
			inv.tools_unlock_notified = true
			inv.coins = 10000
			inv.wood = 100
			inv.stone = 100
			check(manager.purchase_land("land_01") and manager.purchase_land("land_02"),"unlock new resource zones")
			check(inv.buy_building("bakery"),"existing Bakery overlaps original Rock position")
			manager.resources["rock_2"].restore_save_data({"respawn_at":Time.get_unix_time_from_system()+240,"rock_type":"large_rock"})
			for id in ["tree_7","rock_4"]:
				var resource = manager.resources[id]
				resource.restore_save_data({"respawn_at":Time.get_unix_time_from_system()+240,"rock_type":"dark_rock"})
				check(resource.zone_active and resource.respawn_timer.time_left > 200,"unlocked resource uses saved deadline")
			manager.buildings["house"].position = Vector2(260,520)
			manager.building_positions["house"] = Vector2(260,520)
			inv.wood = 5
			inv.stone = 0
			check(inv.build_dog_house() and manager.save_game(),"save Dog House, land, old building position and new cooldowns")
		"resource_update_read":
			check_layout()
			check(inv.has_dog_house and inv.wood == 0 and inv.stone == 0,"Dog House persists without new save keys")
			check(manager.buildings["house"].position == Vector2(260,520) and manager.resources["tree_6"].position != Vector2(260,520),"existing saved building wins; new Tree relocated safely")
			for id in ["tree_7","rock_4"]:
				var resource = manager.resources[id]
				check(resource.zone_active and resource.state == "DEPLETED" and resource.respawn_timer.time_left > 150,"new resource offline cooldown restored: " + id)
				check(resource.respawn_at == disk().get_value("resources",id)["respawn_at"],"exact Unix deadline retained")
			check(manager.resources["rock_4"].rock_type == "dark_rock","new Rock type saved")
			check(inv.owns_bakery and manager.resources["rock_2"].rock_type == "large_rock" and manager.resources["rock_2"].respawn_timer.time_left > 150,"relocation preserves old Rock type and cooldown")
			check(not manager.resources["tree_8"].zone_active and manager.resources["tree_8"].respawn_timer.is_stopped(),"unowned region stays inactive after reload")
		"resource_update_legacy_write":
			check(manager.reset_game(),"legacy fixture")
			var data := disk()
			for id in NEW_IDS:
				data.erase_section_key("resources",id)
			data.set_value("inventory","coins",222)
			data.set_value("resources","tree_1",{"respawn_at":Time.get_unix_time_from_system()+240})
			check(data.save(manager.SAVE_PATH) == OK,"old resource save without new nodes")
		"resource_update_legacy_read":
			check_layout()
			check(inv.coins == 222 and not inv.has_dog_house,"old save balances and ownership preserved")
			check(manager.resources["tree_1"].respawn_timer.time_left > 150,"existing resource cooldown retained")
			for id in NEW_IDS:
				check(manager.resources[id].state == "AVAILABLE" and manager.resources[id].respawn_at == 0.0,"missing new resource uses safe defaults")
			check(manager.reset_game(),"legacy cleanup")
	print("PASS: " + stage)
	quit()
