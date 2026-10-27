extends SceneTree

var inv: Node
var manager: Node
var farm: Node
const NEW_CROPS: Array = ["SOYBEAN", "SUGARCANE", "COTTON", "FLAX"]

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func disk() -> ConfigFile:
	var result := ConfigFile.new()
	check(result.load(manager.SAVE_PATH) == OK, "save readable")
	return result

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"crop_core":
			check(manager.reset_game(), "reset fixture")
			var times: Array = [60,120,240,360,600,900,2700]
			var categories: Array = ["food_crop", "food_crop", "food_crop", "animal_feed_crop", "food_crop", "industrial_crop", "industrial_crop"]
			for i in range(7):
				check(inv.CropData.grow_seconds(inv.CropData.CROPS.keys()[i]) == times[i], "production crop times")
				check(inv.CropData.CROPS.values()[i]["category"] == categories[i], "crop categories")
			check(farm.get_node("HUD").crop_selector.item_count == 7 and inv.SILO_ITEMS.size() == 17, "seven crop UI and storage include rare variants")
			check("golden_wheat" in inv.SILO_ITEMS and "golden_corn" in inv.SILO_ITEMS and "giant_carrot" in inv.SILO_ITEMS, "rare crops use Silo storage")
			check(inv.CropData.CROPS["FLAX"]["id"] == "flax" and tr("ITEM_FLAX") == "Cây lanh", "Flax ID and Vietnamese name")
			check(inv.flax_seed == 0 and inv.flax == 0, "default Flax inventory")
			inv.coins = 10000
			inv.tools_unlock_notified = true
			var levels: Array = [6,8,12,18]
			var buys: Array = [20,25,35,50]
			var sells: Array = [48,65,90,140]
			inv.CropData.crop_time_scale = 0.1
			for i in range(4):
				var crop: String = NEW_CROPS[i]
				var item: String = crop.to_lower()
				inv.player_level = levels[i]-1
				inv.inventory_changed.emit()
				var hud = farm.get_node("HUD")
				check(hud.crop_selector.get_item_text(i+3).contains("Khóa - Cấp " + str(levels[i])), "locked label")
				check(not inv.buy_seed(crop) and not inv.select_crop(crop) and inv.get(item+"_seed") == 0, "pre-unlock denied")
				inv.player_level = levels[i]
				var coins: int = inv.coins
				check(inv.buy_seed(crop) and inv.coins == coins-buys[i] and inv.select_crop(crop), "unlocked buy and selection")
				var plot = manager.plots["soil_01"]
				plot.try_plant()
				check(plot.crop_type == crop and inv.get(item+"_seed") == 0, "plant new crop")
				check(is_equal_approx(plot.ready_at-plot.planted_at, times[i+3]*0.1), "development multiplier")
				check(disk().get_value("soil_01", "crop_type") == crop, "atomic plant autosave")
				plot.ready_at = Time.get_unix_time_from_system()-1
				plot._on_grow_timer_timeout()
				var texture := GradientTexture2D.new()
				plot.get_node("Visuals").crop_textures[crop+"_READY"] = texture
				plot._update_label()
				check(plot.get_node("Visuals/CropSprite").texture == texture, "visual uses stable crop ID")
				plot.harvest()
				plot.harvest()
				check(inv.get(item) == 1, "harvest once")
				check(hud.storage_panel.item_cells[crop.to_lower()].quantity == 1, "new crop storage grid")
				coins = inv.coins
				check(inv.sell_crop(crop) and inv.coins == coins+sells[i] and inv.get(item) == 0, "new crop sell")
			inv.CropData.crop_time_scale = 1.0
			check(manager.reset_game(), "new crops reset")
			for crop in NEW_CROPS:
				check(inv.get(crop.to_lower()) == 0 and inv.get(crop.to_lower()+"_seed") == 0, "new crop defaults")
		"crop_write":
			check(manager.reset_game(), "offline fixture")
			inv.player_level = 18
			inv.tools_unlock_notified = true
			inv.coins = 10000
			for i in range(4):
				var crop: String = NEW_CROPS[i]
				check(inv.buy_seed(crop) and inv.select_crop(crop), "offline seeds")
				var plot = manager.plots["soil_0"+str(i+1)]
				plot.try_plant()
				if i == 0:
					plot.ready_at = Time.get_unix_time_from_system()-1
				plot.planted_at = plot.ready_at-360
			inv.cotton_seed = 2
			inv.flax_seed = 2
			check(manager.save_game(), "persist new crops")
		"crop_read", "crop_again":
			check(inv.selected_crop == "FLAX" and inv.cotton_seed == 2 and inv.flax_seed == 2, "selection and inventory restored")
			var first = manager.plots["soil_01"]
			if stage == "crop_read":
				check(first.state == 2 and first.crop_type == "SOYBEAN", "offline ready")
				first.harvest()
			else:
				check(first.state == 0, "collected crop stays empty")
			first.harvest()
			check(inv.soybean == 1, "no duplicate reload reward")
			inv.CropData.crop_time_scale = 0.1
			for id in ["soil_02", "soil_03", "soil_04"]:
				var plot = manager.plots[id]
				var ready: float = disk().get_value(id, "ready_at")
				plot.restore_save_data(manager.saved_plots[id])
				check(plot.state == 1 and plot.grow_timer.time_left > 100 and is_equal_approx(plot.ready_at,ready), "restore keeps absolute deadline despite multiplier")
			inv.CropData.crop_time_scale = 1.0
	print("PASS: " + stage)
	quit()
