extends SceneTree

var farm: Node
var inv: Node
var manager: Node
var player: Node2D

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: "+message)
		quit(1)
		assert(value,message)

func check_building(id: String, bounds: Rect2, shape_size: Vector2, floor_y: float, animal_id: String) -> void:
	var building = manager.buildings[id]
	var sprite: Sprite2D = building.get_node("Visuals/BuildingSprite")
	check(sprite.texture.resource_path == "res://assets/buildings/%s/%s.png" % [id,id],"correct building artwork "+id)
	check(sprite.region_enabled and is_equal_approx(sprite.scale.x,sprite.scale.y),"uniform building scale "+id)
	check(is_equal_approx(sprite.position.y+sprite.get_rect().end.y*sprite.scale.y,floor_y),"building feet match original ground "+id)
	check(farm.Placement.bounds(building) == building.global_transform*bounds,"original placement footprint "+id)
	check(building.get_node("CollisionShape2D").shape.size == shape_size and building.scale == Vector2.ONE,"original collision and root scale "+id)
	check(not building.get_node("Visual").visible,"placeholder hidden "+id)
	var group = farm.animal_groups[animal_id]
	check(group.animals().size() == inv.get(animal_id+"_count"),"animal instances match inventory "+animal_id)
	var animal: AnimatedSprite2D = group.animals()[0].get_node("AnimatedSprite2D")
	check(animal.is_visible_in_tree() and is_equal_approx(animal.scale.x,animal.scale.y),"owned animal shown without stretching "+animal_id)
	var frame: AtlasTexture = animal.sprite_frames.get_frame_texture("idle_down",0)
	check(frame.atlas.resource_path == "res://assets/animals/%s/%s.png" % [animal_id,animal_id],"correct animal texture "+animal_id)
	check(is_zero_approx((animal.offset.y+frame.get_height()/2.0)*animal.scale.y),"animal feet anchored at its own ground position "+animal_id)
	var before: Dictionary = building.get_save_data().duplicate(true)
	var preview = farm.Placement.create_preview(building)
	farm.add_child(preview)
	var previews: Array = preview.find_children("*","Sprite2D",true,false)
	check(previews.size() == 1 and previews[0].texture == sprite.texture and previews[0].region_rect == sprite.region_rect,"edit preview uses cropped artwork "+id)
	preview.free()
	for n in range(3):
		building.get_node("Visuals").refresh()
	check(building.get_save_data() == before,"visual refresh never changes production "+id)

func capture(name: String, center: Vector2) -> void:
	var camera = player.get_node("Camera2D")
	camera.target_zoom = 1.0
	camera.zoom = Vector2.ONE
	camera.begin_pan()
	camera.pan_center = center
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://"+name+".png") == OK,"capture "+name)

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	check(manager.reset_game(),"reset fixture")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	player = farm.get_node("Player")
	var house_sprite: Sprite2D = farm.get_node("House/Visuals/HouseSprite")
	check(house_sprite.texture != null and house_sprite.texture.resource_path == "res://assets/buildings/house/house_cozy_v2.png", "main House uses the cozy replacement artwork")
	check(farm.get_node("WorldAmbient") is Node2D and farm.get_node("WorldDepth") is Node, "ambient and Y-depth presentation layers exist")
	await create_timer(0.1).timeout
	for id in ["chicken_coop","cow_shed"]:
		check(not manager.buildings[id].is_visible_in_tree(),"unowned buildings remain hidden")
	inv.player_level = 10
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.normalize_exp()
	check(inv.buy_building("chicken_coop") and inv.buy_building("cow_shed"),"existing purchase flow")
	await create_timer(0.1).timeout
	for id in ["chicken_coop","cow_shed"]:
		check(farm.animal_groups["chicken" if id == "chicken_coop" else "cow"].animals().is_empty(),"no animal image at zero animals")
	check(inv.buy_animal("chicken") and inv.buy_animal("cow"),"existing animal logic")
	for kind in ["chicken", "cow"]:
		var roster: Array = manager.animal_rosters[kind]
		roster[0]["born_at"] = inv.AnimalData.adult_born_at(kind)
		manager.animal_rosters[kind] = roster
		farm.animal_groups[kind].sync_count()
	inv.chicken_feed = 1
	inv.cow_feed = 1
	check(manager.stations["chicken_coop"].produce() and manager.stations["cow_shed"].produce(),"existing production still starts")
	await create_timer(0.1).timeout
	check_building("chicken_coop",Rect2(-64,-36,128,72),Vector2(144,100),36,"chicken")
	check_building("cow_shed",Rect2(-98,-86,196,138),Vector2(196,132),52,"cow")
	check(not manager.buildings["cow_shed"].get_node("Roof").visible,"old cow roof hidden behind new art")
	var trees: int = 0
	for resource in manager.resources.values():
		if resource.resource_type != "wood":
			var rock_sprite: Sprite2D = resource.get_node("Visuals/ResourceSprite")
			check(rock_sprite.texture != null and rock_sprite.texture == resource.RockData.texture_for(resource.rock_type),"Rocks use their own type-specific artwork instead of Tree texture")
			continue
		trees += 1
		var sprite: Sprite2D = resource.get_node("Visuals/ResourceSprite")
		check(resource.tree_species in ["oak", "autumn", "pine", "blossom"] and sprite.visible,"each harvestable Tree uses a supported species visual")
		check(sprite.texture.resource_path.begins_with("res://assets/environment/tree/") and sprite.texture.resource_path.get_extension() in ["png", "svg"],"Tree species uses a project tree asset")
		check(not resource.get_node("Visual").visible and resource.get_node_or_null("Sprite2D") == null,"no duplicate legacy Tree sprite")
		check(is_equal_approx(sprite.scale.x,sprite.scale.y) and is_equal_approx(sprite.position.y+sprite.get_rect().end.y*sprite.scale.y,40),"uniform Tree scale and ground offset")
		check(farm.Placement.bounds(resource) == resource.global_transform*Rect2(-40,-40,80,80),"Tree placement footprint unchanged")
		check(resource.get_node("CollisionShape2D").shape.size == Vector2(110,110),"Tree interaction shape unchanged")
	check(trees == 32,"all harvestable Trees use species visuals")
	var tree = manager.resources["tree_1"]
	# Gathering now correctly requires the matching equipped tool. Keep this
	# visual regression test on the normal player-facing Axe path.
	farm.get_node("HUD/Hotbar").select_slot(5)
	player.position = tree.global_position+Vector2(0,32)
	await create_timer(0.1).timeout
	check(tree.harvest(),"original Axe gathering starts")
	tree.harvest_timer.stop()
	var wood_before: int = inv.wood
	tree._finish_harvest()
	check(inv.wood-wood_before in [2,3] and tree.state == "DEPLETED" and tree.respawn_at > Time.get_unix_time_from_system(),"original Tree reward and respawn timestamp")
	check(tree.get_node("Visuals/ResourceSprite").texture == null,"chopped Tree artwork disappears")
	var earned: int = inv.wood
	tree._finish_harvest()
	check(inv.wood == earned,"no duplicate gathering reward")
	tree.respawn_at = Time.get_unix_time_from_system()-1
	tree._respawn()
	check(tree.state == "AVAILABLE" and tree.get_node("Visuals/ResourceSprite").texture != null,"respawn restores Tree artwork")
	if "--capture" in OS.get_cmdline_user_args():
		await capture("new_tree_assets",Vector2(900,360))
		await capture("new_animal_building_assets",Vector2(1200,1020))
	check(manager.save_game(),"same save data with new assets")
	check(manager.reset_game(),"reset fixture")
	for id in ["chicken_coop","cow_shed"]:
		check(not manager.buildings[id].visible,"reset clears ownership without removing shared artwork")
	print("PASS: art_core")
	quit()
