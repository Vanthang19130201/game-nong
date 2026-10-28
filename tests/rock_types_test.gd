extends SceneTree

const IDS: Array[String] = ["rock_1","rock_2","rock_3"]
const TYPES: Array[String] = ["normal_rock","large_rock","dark_rock"]
var inv: Node
var manager: Node
var farm: Node
var player: Node2D

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

func prepare() -> void:
	check(manager.reset_game(),"reset isolated fixture")
	inv.player_level = 6
	inv.tools_unlock_notified = true
	inv.normalize_exp()
	inv.inventory_changed.emit()

func data(type: String, respawn_at: float = 0.0) -> Dictionary:
	return {"rock_type":type,"respawn_at":respawn_at}

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg","never use player save")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	player = farm.get_node("Player")
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"rock_core":
			prepare()
			var rock = manager.resources["rock_1"]
			var scale_before: Vector2 = rock.scale
			var shape = rock.get_node("CollisionShape2D").shape
			var shape_size: Vector2 = shape.size
			player.position = rock.global_position+Vector2(0,32)
			await create_timer(0.1).timeout
			check(rock.tool_id() == "hammer" and inv.can_use_tool("hammer"),"all types share existing Hammer")
			var dark_rewards: Dictionary = {}
			for type in TYPES:
				rock.rng.seed = 12345
				for sample in range(12 if type == "dark_rock" else 1):
					rock.restore_save_data(data(type))
					check(rock.rock_type == type and rock.state == "AVAILABLE","known saved type restored")
					var before: int = inv.stone
					check(rock.harvest(),"existing mining flow works " + type)
					rock.harvest_timer.stop()
					rock._finish_harvest()
					var earned: int = inv.stone-before
					check(earned == 2 if type == "normal_rock" else (earned == 3 if type == "large_rock" else earned in [2,3]),"exact type reward " + type)
					if type == "dark_rock":
						dark_rewards[earned] = true
					var deadline: float = rock.respawn_at
					rock._finish_harvest()
					rock._respawn()
					check(inv.stone == before+earned and rock.state == "DEPLETED" and rock.rock_type == type and rock.respawn_at == deadline,"spam cannot duplicate rewards or reroll during cooldown")
					check(disk().get_value("resources","rock_1")["rock_type"] == type,"reward and type autosaved together")
			check(dark_rewards.size() == 2,"dark rock can yield both 2 and 3 Stone")
			var seen: Dictionary = {}
			for sample in range(18):
				rock.restore_save_data(data("normal_rock",Time.get_unix_time_from_system()+90))
				rock.respawn_at = Time.get_unix_time_from_system()-1
				rock._respawn()
				check(rock.rock_type in TYPES and rock.state == "AVAILABLE" and rock.respawn_at == 0.0,"timestamp respawn picks a valid type")
				seen[rock.rock_type] = true
			check(seen.size() == 3,"respawn can select all three types")
			var chosen: String = rock.rock_type
			for sample in range(3):
				inv.inventory_changed.emit()
				rock._respawn()
			check(rock.rock_type == chosen,"available rock cannot reroll on inventory updates or repeated timeout")
			for type in TYPES:
				rock.restore_save_data(data(type))
				check(rock.visual.color == rock.RockData.TYPES[type]["color"],"distinct placeholder tint " + type)
				check(not farm.Placement.can_place(farm.get_node("House"),rock.global_position),"each type blocks building placement")
			var texture := GradientTexture2D.new()
			rock.get_node("Visuals").rock_textures["large_rock"] = texture
			rock.restore_save_data(data("large_rock"))
			check(rock.get_node("Visuals/ResourceSprite").texture == texture,"Inspector type artwork used when available")
			check(rock.scale == scale_before and rock.get_node("CollisionShape2D").shape == shape and shape.size == shape_size,"type artwork never scales root or collision")
			check((rock.get_node("Visuals/ResourceSprite").get_rect().size*rock.get_node("Visuals/ResourceSprite").scale).is_equal_approx(Vector2(80,80)),"artwork fits existing placement footprint")
			check(not manager.resources["tree_1"].get_save_data().has("rock_type") and manager.resources["tree_1"].tool_id() == "axe","Tree data and Axe unchanged")
			rock.global_position = Vector2(320,1664)
			player.position = rock.global_position+Vector2(0,32)
			rock.restore_save_data(data("large_rock",Time.get_unix_time_from_system()-1))
			await create_timer(0.1).timeout
			var before: int = inv.stone
			rock._respawn()
			check(not rock.zone_active and not rock.harvest() and rock.rock_type == "large_rock" and inv.stone == before and rock.respawn_timer.is_stopped(),"locked land blocks mining and respawn rerolls")
			inv.coins = 1000
			inv.wood = 20
			inv.stone = 20
			check(manager.purchase_land("land_01"),"unlock fixture land")
			await create_timer(0.1).timeout
			check(rock.zone_active and rock.state == "AVAILABLE" and rock.rock_type in TYPES and rock.harvest(),"unlocked land resumes existing Hammer mining")
			rock.cancel_harvest()
			check(manager.reset_game(),"cleanup")
		"rock_write":
			prepare()
			inv.stone = 77
			for index in range(3):
				manager.resources[IDS[index]].restore_save_data(data(TYPES[index],Time.get_unix_time_from_system()+120 if index == 1 else 0.0))
			check(manager.save_game(),"save all three types")
		"rock_read":
			for index in range(3):
				check(manager.resources[IDS[index]].rock_type == TYPES[index],"reload retains exact rock type " + IDS[index])
			check(inv.stone == 77 and manager.resources["rock_2"].state == "DEPLETED" and manager.resources["rock_2"].respawn_timer.time_left > 60,"reload grants no Stone and resumes cooldown")
		"rock_respawn_write":
			var saved := disk()
			var record: Dictionary = saved.get_value("resources","rock_2")
			record["respawn_at"] = Time.get_unix_time_from_system()-1
			saved.set_value("resources","rock_2",record)
			check(saved.save(manager.SAVE_PATH) == OK,"offline respawn fixture")
		"rock_respawn_read":
			var rock = manager.resources["rock_2"]
			check(rock.state == "AVAILABLE" and rock.respawn_at == 0.0 and rock.rock_type in TYPES and inv.stone == 77,"offline respawn completes without granting items")
			check(disk().get_value("resources","rock_2")["rock_type"] == rock.rock_type,"offline chosen type persisted")
			check(manager.reset_game(),"respawn cleanup")
		"rock_legacy_write":
			check(manager.reset_game(),"legacy fixture")
			var saved := disk()
			for id in IDS:
				var record: Dictionary = saved.get_value("resources",id)
				record.erase("rock_type")
				saved.set_value("resources",id,record)
			saved.set_value("inventory","stone",91)
			check(saved.save(manager.SAVE_PATH) == OK,"old save lacks rock_type")
		"rock_legacy_read":
			check(inv.stone == 91,"migration keeps existing resources")
			for id in IDS:
				check(manager.resources[id].rock_type in TYPES and disk().get_value("resources",id)["rock_type"] == manager.resources[id].rock_type,"legacy rock randomly assigned once and saved")
			check(manager.reset_game(),"legacy cleanup")
		"rock_reset_read":
			check(inv.stone == 0 and manager.resources.size() == 42,"reset preserves expanded resource count")
			for id in IDS:
				check(manager.resources[id].state == "AVAILABLE" and manager.resources[id].rock_type in TYPES and manager.resources[id].respawn_at == 0.0,"reset starts fresh rock")
	print("PASS: " + stage)
	quit()
