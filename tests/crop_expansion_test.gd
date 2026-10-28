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
		test_harvest_quantity_rules()
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
				plot.planted_at = 100000 + i * 10
				plot.ready_at = plot.planted_at + 1
				while not inv.CropData.roll_rare_variant(crop, "%s|%s|%d|%d" % [plot.plot_id, crop, int(plot.planted_at), int(plot.ready_at)]).is_empty():
					plot.planted_at += 1
					plot.ready_at = plot.planted_at + 1
				plot._on_grow_timer_timeout()
				var texture := GradientTexture2D.new()
				plot.get_node("Visuals").crop_textures[crop+"_READY"] = texture
				plot._update_label()
				check(plot.get_node("Visuals/CropSprite").texture == texture, "visual uses stable crop ID")
				var rare: String = inv.CropData.roll_rare_variant(crop, "%s|%s|%d|%d" % [plot.plot_id, crop, int(plot.planted_at), int(plot.ready_at)])
				plot.harvest()
				plot.harvest()
				var harvest_item: String = rare if not rare.is_empty() else item
				check(inv.get(harvest_item) == 2, "harvest yields two items once")
				check(hud.storage_panel.item_cells[harvest_item].quantity == 2, "new crop/rare storage grid")
				coins = inv.coins
				check(inv.sell_item(harvest_item, 2) and inv.coins == coins+sells[i]*2 and inv.get(harvest_item) == 0, "new crop/rare sell")
			inv.CropData.crop_time_scale = 1.0
			check(manager.reset_game(), "new crops reset")
			for crop in NEW_CROPS:
				check(inv.get(crop.to_lower()) == 0 and inv.get(crop.to_lower()+"_seed") == 0, "new crop defaults")
		"crop_rare_write":
			check(manager.reset_game(), "rare save fixture reset")
			var rare_planted := find_rare_key("WHEAT")
			check(rare_planted > 0, "rare stable key available for save")
			var plot = manager.plots["soil_01"]
			plot.restore_save_data({"state":"READY", "crop_type":"WHEAT", "planted_at":float(rare_planted), "ready_at":float(rare_planted + 1)})
			plot.harvest()
			check(inv.golden_wheat == 2 and manager.save_game(), "rare harvest x2 saved once")
		"crop_rare_read", "crop_rare_again":
			check(inv.golden_wheat == 2 and manager.plots["soil_01"].state == 0, "rare crop amount restores without reroll")
			manager.plots["soil_01"].harvest()
			check(inv.golden_wheat == 2, "repeated load/harvest does not reroll rare reward")
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
			check(inv.soybean == 2, "offline harvest grants exactly two soybeans once")
			inv.CropData.crop_time_scale = 0.1
			for id in ["soil_02", "soil_03", "soil_04"]:
				var plot = manager.plots[id]
				var ready: float = disk().get_value(id, "ready_at")
				plot.restore_save_data(manager.saved_plots[id])
				check(plot.state == 1 and plot.grow_timer.time_left > 100 and is_equal_approx(plot.ready_at,ready), "restore keeps absolute deadline despite multiplier")
			inv.CropData.crop_time_scale = 1.0
	print("PASS: " + stage)
	quit()


func test_harvest_quantity_rules() -> void:
	var plot = manager.plots["soil_01"]
	var before_seed: int = inv.wheat_seed
	var before_exp: int = inv.player_exp
	check(inv.select_crop("WHEAT"), "select normal crop")
	plot.try_plant()
	check(inv.wheat_seed == before_seed - 1, "plant consumes exactly one seed")
	var normal_planted := 0
	for candidate in range(20000, 30000):
		var normal_key := "%s|WHEAT|%d|%d" % [plot.plot_id, candidate, candidate + 1]
		if inv.CropData.roll_rare_variant("WHEAT", normal_key).is_empty():
			normal_planted = candidate
			break
	check(normal_planted > 0, "deterministic normal key found")
	plot.restore_save_data({"state":"READY", "crop_type":"WHEAT", "planted_at":float(normal_planted), "ready_at":float(normal_planted + 1)})
	plot.harvest()
	check(inv.wheat == 2 and inv.wheat_seed == before_seed - 1, "normal crop gives two and never refunds seed")
	check(inv.player_exp == before_exp + inv.CropData.CROPS["WHEAT"]["harvest_exp"], "crop EXP counted once per plot")

	var rare_planted := 0
	for candidate in range(1, 10000):
		var candidate_key := "%s|WHEAT|%d|%d" % [plot.plot_id, candidate, candidate + 1]
		if inv.CropData.roll_rare_variant("WHEAT", candidate_key) == "golden_wheat":
			rare_planted = candidate
			break
	check(rare_planted > 0, "deterministic rare key found")
	plot.restore_save_data({"state":"READY", "crop_type":"WHEAT", "planted_at":float(rare_planted), "ready_at":float(rare_planted + 1)})
	plot.harvest()
	check(inv.golden_wheat == 2 and inv.wheat == 2, "rare crop gives two rare items without base crop")

	for item in inv.SILO_ITEMS:
		inv.set(item, 0)
	plot.restore_save_data({"state":"EMPTY", "crop_type":"", "planted_at":0.0, "ready_at":0.0})
	inv.mystery_seed = 1
	check(inv.select_crop("MYSTERY"), "select Mystery Seed")
	plot.try_plant()
	check(inv.mystery_seed == 0 and not plot.crop_type.is_empty(), "Mystery Seed consumed and resolved")
	var mystery_crop: String = plot.crop_type
	var mystery_planted := 0
	for candidate in range(10001, 20000):
		var candidate_key := "%s|%s|%d|%d" % [plot.plot_id, mystery_crop, candidate, candidate + 1]
		if inv.CropData.roll_rare_variant(mystery_crop, candidate_key).is_empty():
			mystery_planted = candidate
			break
	check(mystery_planted > 0, "deterministic Mystery Seed fixture found")
	plot.restore_save_data({"state":"READY", "crop_type":mystery_crop, "planted_at":float(mystery_planted), "ready_at":float(mystery_planted + 1)})
	plot.harvest()
	check(inv.get(mystery_crop.to_lower()) == 2 and inv.mystery_seed == 0, "Mystery Seed crop yields two without seed refund")

	for item in inv.SILO_ITEMS:
		inv.set(item, 0)
	inv.wheat = inv.silo_capacity - 1
	plot.restore_save_data({"state":"READY", "crop_type":"WHEAT", "planted_at":30000.0, "ready_at":30001.0})
	var exp_before_full: int = inv.player_exp
	plot.harvest()
	check(plot.state == plot.PlotState.READY and inv.wheat == inv.silo_capacity - 1 and inv.player_exp == exp_before_full, "one free Silo slot rejects x2 and preserves READY crop")
	for item in inv.SILO_ITEMS:
		inv.set(item, 0)
	plot.restore_save_data({"state":"EMPTY", "crop_type":"", "planted_at":0.0, "ready_at":0.0})


func find_rare_key(crop: String) -> int:
	for candidate in range(1, 10000):
		var key := "%s|%s|%d|%d" % ["soil_01", crop, candidate, candidate + 1]
		if inv.CropData.roll_rare_variant(crop, key) != "":
			return candidate
	return 0
