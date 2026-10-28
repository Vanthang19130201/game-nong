extends SceneTree

const Data = preload("res://crop_visual_data.gd")
const CROPS: Array[String] = ["WHEAT", "CORN", "CARROT"]
var farm: Node
var inv: Node
var manager: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func check_stage(plot: Node, stage: int) -> void:
	var visuals = plot.get_node("Visuals")
	var sprite: Sprite2D = visuals.get_node("CropSprite")
	check(visuals.displayed_stage == stage and sprite.visible and sprite.texture == Data.texture_for(plot.crop_type,stage), "correct crop type and stage texture")
	check(sprite.z_index > visuals.get_node("SoilSprite").z_index and is_equal_approx(sprite.scale.x,sprite.scale.y), "crop above soil without stretching")
	var rect: Rect2 = sprite.transform * sprite.get_rect()
	check(rect.size.x <= 44.1 and rect.size.y <= 44.1 and is_equal_approx(rect.end.y,12), "crop fits the unchanged grid and is ground anchored")
	check(plot.get_node("PlantLabel").text.is_empty() and not plot.get_node("PlantLabel").visible, "no large text on crops")
	var timer: Label = visuals.get_node("GrowthTime")
	check(timer.visible == (stage != 3), "tiny countdown only while growing")
	if timer.visible:
		var pattern := RegEx.new()
		pattern.compile("^[0-9]+:[0-5][0-9]$")
		check(pattern.search(timer.text) != null and timer.get_theme_font_size("font_size") == 10 and timer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "small readable m:ss countdown never captures input")

func prepare() -> void:
	check(manager.reset_game(), "reset isolated fixture")
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.corn_seed = 3
	inv.carrot_seed = 3
	inv.inventory_changed.emit()
	check(manager.plots.size() == 32, "still exactly 32 plots")
	for plot in manager.plots.values():
		var visuals = plot.get_node("Visuals")
		check(plot.scene_file_path == "res://soil_plot.tscn" and plot.scale == Vector2.ONE, "all plots use the real shared scene with original root scale")
		check(visuals.get_node("SoilSprite").visible == plot.is_unlocked() and visuals.get_node("LockedMarker").visible != plot.is_unlocked(), "soil versus small lock marker")
		check(not visuals.get_node("CropSprite").visible and not visuals.get_node("FallbackCropVisual").visible and not visuals.get_node("GrowthTime").visible, "empty or locked plot has no crop or timer")
		check(plot.get_node("CollisionShape2D").shape.size == Vector2(68,52), "original interaction shape preserved")
	check(inv.buy_plot(9), "same existing plot purchase")
	var unlocked = manager.plots["soil_09"].get_node("Visuals")
	check(unlocked.get_node("SoilSprite").visible and not unlocked.get_node("LockedMarker").visible, "purchase immediately replaces the lock with soil")

func screenshot() -> void:
	# Three columns: wheat/corn/carrot. Rows: sprout, young, ripe.
	manager.plots["soil_04"].restore_save_data({"state":"EMPTY","crop_type":"","planted_at":0.0,"ready_at":0.0})
	inv.unlocked_plot_count = 19
	inv.inventory_changed.emit()
	for row in range(3):
		for col in range(3):
			var number: int = [1,5,17][row]+col
			var plot = manager.plots[inv.FarmData.plot_id(number)]
			var now: float = Time.get_unix_time_from_system()
			var duration: float = inv.CropData.grow_seconds(CROPS[col])
			var fraction: float = 0.1 if row == 0 else 0.65
			plot.restore_save_data({"state":"READY" if row == 2 else "GROWING", "crop_type":CROPS[col], "planted_at":now-duration*fraction, "ready_at":now+duration*(1.0-fraction), "position":plot.position})
	var camera = farm.get_node("Player/Camera2D")
	camera.target_zoom = 1.5
	camera.zoom = Vector2.ONE * 1.5
	camera.begin_pan()
	camera.pan_center = Vector2(1360,610)
	# Let harvest feedback from the checks disappear before reviewing artwork.
	await create_timer(1.8).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://crop_growth_stages.png") == OK, "capture crop growth stages")

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "crop_visual_read":
		check_stage(manager.plots["soil_01"],1)
		check_stage(manager.plots["soil_02"],2)
		check_stage(manager.plots["soil_03"],3)
		check(manager.plots["soil_02"].position == Vector2(576,1152), "moved growing plot restores position and sprite")
		check(manager.reset_game(), "cleanup")
	else:
		prepare()
		for index in range(3):
			var plot = manager.plots[inv.FarmData.plot_id(index+1)]
			check(inv.select_crop(CROPS[index]), "existing crop selection")
			plot.try_plant()
			check_stage(plot,1)
			var now: float = Time.get_unix_time_from_system()
			# Cross the halfway mark without changing state or restarting GrowTimer.
			plot.planted_at = now-59.9
			plot.ready_at = now+60.1
			var saved: Dictionary = plot.get_save_data().duplicate(true)
			var timer_id: int = plot.grow_timer.get_instance_id()
			await create_timer(0.4).timeout
			check_stage(plot,2)
			check(plot.get_save_data() == saved and plot.grow_timer.get_instance_id() == timer_id, "visual stage transition never changes crop, ID, timestamp or timer")
			plot.ready_at = Time.get_unix_time_from_system()-1
			plot._on_grow_timer_timeout()
			check_stage(plot,3)
			plot.harvest()
			var visuals = plot.get_node("Visuals")
			check(inv.get(CROPS[index].to_lower()) == 2 and not visuals.get_node("CropSprite").visible and not visuals.get_node("GrowthTime").visible and visuals.get_node("SoilSprite").visible, "harvest yields x2 and clears only crop visual/timer")
		# Existing crops without stage art keep an icon fallback, never big labels.
		var fallback = manager.plots["soil_04"]
		fallback.restore_save_data({"state":"READY","crop_type":"COTTON","planted_at":1.0,"ready_at":2.0})
		check(fallback.get_node("Visuals/FallbackCropVisual").visible and not fallback.get_node("PlantLabel").visible, "other crops remain visible and text free")
		if "--capture" in OS.get_cmdline_user_args():
			await screenshot()
		if stage == "crop_visual_write":
			var now: float = Time.get_unix_time_from_system()
			for index in range(3):
				var plot = manager.plots[inv.FarmData.plot_id(index+1)]
				plot.restore_save_data({"state":"GROWING","crop_type":CROPS[index],"planted_at":now-(5 if index == 0 else 80),"ready_at":now+60 if index < 2 else now-1})
			manager.plots["soil_02"].position = Vector2(576,1152)
			check(manager.save_game(), "same crop save schema")
		else:
			check(manager.reset_game(), "cleanup")
	print("PASS: " + stage)
	quit()
