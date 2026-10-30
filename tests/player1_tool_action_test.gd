extends SceneTree

const Data = preload("res://character_data.gd")
const Frames = preload("res://player1_animation_frames.gd")
const DIRECTIONS: Dictionary = {"down":Vector2.DOWN,"up":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}
var manager: Node
var inv: Node
var farm: Node2D
var player: CharacterBody2D
var visual: AnimatedSprite2D
var count: int = 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(ok,message)


func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame


func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	var camera = player.get_node("Camera2D")
	camera.target_zoom = 1.8
	camera.zoom = Vector2.ONE * 1.8
	camera.begin_pan()
	camera.pan_center = player.global_position
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://player1-tool-" + name + ".png") == OK,"render " + name)


func asset_checks() -> void:
	var frames: SpriteFrames = Data.frames_for("farmer_01")
	check(frames.get_animation_names().size() == 16,"only eight base + eight tool animations")
	for direction in DIRECTIONS:
		check(not frames.has_animation("plant_" + direction) and not frames.has_animation("harvest_" + direction),"plant/harvest artwork never loaded " + direction)
	for name in Frames.TOOL_ACTION_FIT:
		check(frames.get_frame_count(name) == 6 and not frames.get_animation_loop(name) and frames.get_animation_speed(name) == 8.0,"six-frame one-shot at 8 FPS " + name)
		for index in range(6):
			var texture: AtlasTexture = frames.get_frame_texture(name,index)
			check(texture.region == Rect2(index * 512,0,512,512),"fixed full 512px grid " + name + str(index))
			check(texture.atlas.resource_path == Frames.TOOL_ACTION_ROOT + name + ".png","correct original source " + name)
	for id in ["farmer_02","farmer_03","farmer_04"]:
		check(Data.complete(Data.frames_for(id)) and not Data.frames_for(id).has_animation("axe_swing_down"),"other characters keep original artwork " + id)


func action_checks() -> void:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var original_shape: Shape2D = shape.shape
	var original_transform := shape.transform
	var original_position := player.position
	var original_speed: float = player.speed
	var original_scale := visual.scale
	for tool in ["axe","hammer"]:
		for direction in DIRECTIONS:
			var name: String = tool + "_swing_" + str(direction)
			check(visual.play_tool_action(tool,direction),"start " + name)
			check(not visual.play_tool_action(tool,direction),"repeated request does not reset action " + name)
			for index in range(6):
				visual.frame = index
				visual._process(0.0)
				check(visual.animation == name and visual.frame == index,"locomotion cannot interrupt tool pose " + name)
				var fit: Array = Frames.TOOL_ACTION_FIT[name]
				var anchor: Vector2 = fit[1][index]
				var foot: Vector2 = visual.position + (visual.offset + anchor - Vector2(256,256)) * visual.scale
				check(foot.is_equal_approx(Vector2(0,shape.position.y)),"ground anchor stable " + name + str(index))
				check(is_equal_approx(visual.scale.x,visual.scale.y) and is_equal_approx(float(fit[0]) * visual.scale.y,visual.target_character_height),"matching reference height without stretching " + name)
			visual.frame = 0
			await create_timer(0.85).timeout
			check(not visual.action_locked and visual.animation == "idle_" + direction and visual.scale == original_scale,"action finishes into original idle/scale " + name)
			check(player.position == original_position and player.scale == Vector2.ONE and shape.shape == original_shape and shape.transform == original_transform and player.speed == original_speed,"physics unchanged " + name)
	for direction in DIRECTIONS:
		player.velocity = DIRECTIONS[direction] * player.speed
		visual._process(0.0)
		check(visual.animation == "walk_" + direction,"original walk still selected " + direction)
		visual.frame = 2
		visual._process(0.0)
		check(visual.frame == 2,"walk never restarted each frame")
		player.velocity = Vector2.ZERO
		visual._process(0.0)
		check(visual.animation == "idle_" + direction,"idle retains last direction " + direction)


func gathering_checks() -> void:
	for tool in ["axe","hammer"]:
		var resource: Node2D = manager.resources["tree_1" if tool == "axe" else "rock_1"]
		farm.get_node("HUD/Hotbar").select_slot(5 if tool == "axe" else 6)
		for direction in DIRECTIONS:
			resource.cancel_harvest()
			resource.respawn_at = Time.get_unix_time_from_system() - 1.0
			resource._respawn()
			# Scene tree_1 has scale 0.6: 40px is inside its unchanged Area2D.
			player.global_position = resource.global_position - DIRECTIONS[direction] * 40.0
			player.facing_vector = DIRECTIONS[direction]
			player.set_equipped_tool(tool)
			await settle()
			await create_timer(0.08).timeout
			check(resource.player_near and resource.can_interact(),"original interaction range " + tool + direction)
			var before: int = inv.get(resource.resource_type)
			check(resource.harvest(),"real gathering starts " + tool + direction)
			check(visual.animation == tool + "_swing_" + direction and player.tool_visual.swinging,"body + real tool animate together " + tool + direction)
			check(player.action_motion_tween == null and is_equal_approx(resource.gather_duration,inv.tool_duration(tool)),"body frames replace tween, resource timer unchanged")
			var sprites: Array = player.tool_visual.find_children("*","Sprite2D",false,false)
			check(sprites.size() == 3 and sprites.filter(func(s): return s.visible).size() == 1,"one equipped tool, no duplicate")
			await create_timer(0.39).timeout
			check(visual.frame in [3,4],"body reaches impact near frame 3")
			var grip: Vector2 = Frames.TOOL_GRIPS[str(visual.current_action)][visual.frame]
			var expected: Vector2 = visual.position + (visual.offset + grip - Vector2(256,256)) * visual.scale
			check(player.tool_visual.position.is_equal_approx(expected),"real tool follows pose hand")
			await capture(tool + "-" + direction)
			await create_timer(0.5).timeout
			check(visual.action_locked and player.tool_visual.body_cycle_count >= 2,"next body action starts only at tool cycle boundary")
			resource.harvest_timer.stop()
			resource._finish_harvest()
			check(resource.state == "DEPLETED" and inv.get(resource.resource_type) > before,"resource reward unchanged")
			check(not visual.action_locked and not player.tool_visual.swinging,"gather completion clears body/tool")
		resource.respawn_at = Time.get_unix_time_from_system() - 1.0
		resource._respawn()
		await settle()
		var before_cancel: int = inv.get(resource.resource_type)
		check(resource.harvest(),"start cancel fixture " + tool)
		resource.cancel_harvest()
		check(not visual.action_locked and inv.get(resource.resource_type) == before_cancel,"cancel restores idle without reward")
	for id in ["farmer_02","farmer_03","farmer_04"]:
		check(manager.set_selected_character(id,false),"select " + id)
		player.set_equipped_tool("axe")
		player.play_tool_swing("axe",player.global_position + Vector2.RIGHT * 64)
		player.start_action_motion("gather",player.global_position + Vector2.RIGHT * 64)
		check(not visual.action_locked and player.tool_visual.swinging and player.action_motion_tween != null,"legacy body/tool fallback " + id)
		player.stop_tool_swing()
		player.stop_action_motion()
	manager.set_selected_character("farmer_01",false)
	player.set_equipped_tool("fishing_rod")
	player.facing_vector = Vector2.DOWN
	player.begin_fishing_pose()
	check(not visual.action_locked and visual.forced_facing == "down" and player.tool_visual.fishing_pose,"existing fishing pose still works")
	check(not visual.play_tool_action("axe","right"),"fishing cannot be interrupted by body action")
	player.end_fishing_pose()
	check(visual.forced_facing.is_empty() and not player.tool_visual.fishing_pose,"fishing pose cleans up")


func run_checks() -> void:
	Engine.max_fps = 120
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	asset_checks()
	check(manager.reset_game(),"reset isolated fixture")
	inv.player_level = 20
	inv.last_rewarded_level = 20
	inv.tools_unlock_notified = true
	inv.normalize_exp(false)
	manager.unlocked_land_zones.assign(manager.LandData.ZONES.keys())
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	player = farm.get_node("Player")
	visual = player.get_node("AnimatedSprite2D")
	await settle()
	player.set_physics_process(false)
	await action_checks()
	await gathering_checks()
	check(manager.save_game(),"save remains compatible")
	visual.cancel_tool_action()
	current_scene = null
	farm.queue_free()
	await process_frame
	await process_frame
	print("PASS: player1_tool_actions (",count," checks; plant/harvest not integrated)")
	quit(0)
