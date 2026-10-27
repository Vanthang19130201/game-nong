extends SceneTree

var farm: Node
var inv: Node
var manager: Node
var clock: Node
var hud: Node

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value,message)

func disk() -> ConfigFile:
	var result := ConfigFile.new()
	check(result.load(manager.SAVE_PATH) == OK,"isolated save readable")
	return result

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for item in manager.INVENTORY_DEFAULTS:
		result[item] = inv.get(item)
	return result

func screenshot(name: String) -> void:
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://completed_"+name+".png") == OK,"capture " + name)

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	clock = root.get_node("GameClock")
	clock.set_process(false) # Test deterministic gameplay delta, never wall time.
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	hud = farm.get_node("HUD")
	var stage: String = OS.get_cmdline_user_args()[0]
	if stage == "calendar_read":
		check(clock.day == 9 and is_equal_approx(clock.minutes,834.75) and clock.season == "autumn","reload preserves exact calendar without offline advance")
		check(inv.wood == 17 and inv.coins == 2190,"calendar migration preserves existing inventory")
		check(hud.get_node("Calendar/Content/Time/Hour").text == "13:54","HUD restores saved game time")
		check(manager.reset_game(),"reset calendar")
		check(clock.day == 1 and clock.minutes == 360 and clock.season == "spring","reset restores new game clock")
	elif stage in ["calendar_legacy_read","calendar_invalid_read"]:
		check(clock.day == 1 and clock.minutes == 360 and clock.season == "spring","legacy/invalid calendar safely defaults")
		check(inv.wood == 17 and inv.coins == 2190,"calendar defaults never reset inventory")
		check(manager.reset_game(),"cleanup")
	else:
		check(manager.reset_game(),"fixture reset")
		inv.player_level = 18
		inv.tools_unlock_notified = true
		inv.wood = 17
		inv.stone = 7
		inv.coins = 2190
		inv.wheat = 4
		inv.corn = 2
		inv.inventory_changed.emit()
		if stage.begins_with("calendar_"):
			clock.restore({"day":9,"minutes":834.75,"season":"autumn"})
			check(manager.save_game(),"save calendar with existing state")
			var saved := disk()
			check(saved.get_value("calendar","day") == 9 and saved.get_value("calendar","minutes") == 834.75 and saved.get_value("calendar","season") == "autumn","same save stores all calendar fields")
			if stage == "calendar_legacy_write":
				saved.erase_section("calendar")
				check(saved.save(manager.SAVE_PATH) == OK,"legacy save fixture")
			elif stage == "calendar_invalid_write":
				saved.set_value("calendar","day",-1)
				saved.set_value("calendar","minutes","bad")
				saved.set_value("calendar","season",32)
				check(saved.save(manager.SAVE_PATH) == OK,"invalid calendar fixture")
		else:
			var before: Dictionary = snapshot()
			check(clock.is_gameplay_active(),"world gameplay enables clock")
			clock._process(2.5)
			check(is_equal_approx(clock.minutes,362.5),"clock uses gameplay delta only")
			for open_panel in [hud._toggle_storage,hud._toggle_shop,hud.open_orders,hud._toggle_settings]:
				open_panel.call()
				var minutes: float = clock.minutes
				clock._process(120)
				check(clock.minutes == minutes and not clock.is_gameplay_active(),"large menu pauses clock")
				hud.close_all_panels()
			paused = true
			clock._process(60)
			check(clock.minutes == 362.5,"paused game never advances clock")
			paused = false
			clock.restore({"day":28,"minutes":1439.0,"season":"spring"})
			clock._process(2)
			check(clock.day == 1 and clock.minutes == 1 and clock.season == "summer","midnight and season rollover")
			clock.restore({"day":9,"minutes":834.75,"season":"autumn"})
			await key(KEY_2)
			check(hud.hotbar.caption.modulate.a == 1 and hud.hotbar.caption.text.contains(root.get_node("Localization").display_name("corn_seed")),"changing slot shows selected item")
			var caption_tween: Tween = hud.hotbar.caption_tween
			inv.inventory_changed.emit()
			check(hud.hotbar.caption_tween == caption_tween,"inventory refresh does not restart caption fade")
			await create_timer(1.6).timeout
			check(hud.hotbar.caption.modulate.a < 0.01,"hotbar caption fades around 1.5 seconds")
			await key(KEY_3)
			check(hud.hotbar.caption.modulate.a == 1,"next slot restarts caption display")
			hud._toggle_storage()
			await process_frame
			var panel = hud.storage_panel
			check(panel.tabs.get_tab_count() == 3,"same three inventory tabs")
			for index in range(3):
				check(panel.tabs.get_tab_icon(index) != null,"small icon for each tab")
			panel.get_node("Margin/Content/Header/SortButton").pressed.emit()
			for grid in panel.grids:
				var empty_seen: bool = false
				for cell in grid.get_children():
					if cell.quantity == 0:
						empty_seen = true
					else:
						check(not empty_seen,"sort puts owned items first")
			var wheat: Button = panel.item_cells["wheat"]
			check(wheat.tooltip_text.contains("4") and wheat.tooltip_text.contains(tr("ITEM_SELL_TOOLTIP") % inv.CropData.CROPS["WHEAT"]["sell_price"]),"tooltip shows quantity and existing sell price")
			check(panel.item_cells["carrot"].item_visual.modulate.a < wheat.item_visual.modulate.a,"zero items are dimmed")
			for storage in panel.upgrade_rows:
				var cost: Dictionary = inv.next_upgrade(storage)
				for item in ["wood","stone","coins"]:
					var label: Label = panel.upgrade_rows[storage]["amounts"][item]
					check(label.text == "%d/%d" % [inv.get(item),cost[item]] and label.autowrap_mode == TextServer.AUTOWRAP_OFF,"upgrade requirements stay horizontal and live")
			check(snapshot() == before,"UI controls never change inventory or economy")
			for view in [Vector2i(1280,720),Vector2i(800,450),Vector2i(360,640)]:
				root.size = view
				root.content_scale_size = view
				await create_timer(0.1).timeout
				var screen := Rect2(Vector2.ZERO,Vector2(view))
				check(screen.encloses(hud.get_node("Calendar").get_rect()),"calendar fits resized screen")
				check(not hud.get_node("Calendar").get_rect().intersects(hud.get_node("StatsBackdrop").get_rect()),"calendar does not cover existing HUD")
				check(screen.encloses(panel.get_rect()),"storage keeps its existing panel on screen")
				if "--capture" in OS.get_cmdline_user_args():
					await screenshot("storage_"+str(view.x))
			root.size = Vector2i(1280,720)
			root.content_scale_size = root.size
			hud.close_all_panels()
			for view in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
				root.size = view
				root.content_scale_size = view
				await create_timer(0.1).timeout
				var screen := Rect2(Vector2.ZERO,Vector2(view))
				var profile_rect: Rect2 = hud.get_node("StatsBackdrop").get_rect()
				var calendar_rect: Rect2 = hud.get_node("Calendar").get_rect()
				var menu_rect: Rect2 = hud.get_node("ResetControls/SettingsButton").get_global_rect()
				check(screen.encloses(profile_rect),"profile card fits viewport %s" % view)
				check(screen.encloses(calendar_rect),"calendar card fits viewport %s" % view)
				check(screen.encloses(menu_rect),"menu button fits viewport %s" % view)
				check(not profile_rect.intersects(calendar_rect),"profile and calendar do not overlap at %s" % view)
				check(not calendar_rect.intersects(menu_rect),"calendar and menu button do not overlap at %s" % view)
				check(screen.encloses(hud.hotbar.get_global_rect()),"hotbar fits viewport %s" % view)
				check(hud.hotbar.slots.size() == 8 and hud.hotbar.slots[0].size.x >= 52 and hud.hotbar.slots[0].size.x <= 60,"hotbar slot size fits target viewport %s" % view)
			check(hud.transaction_feedback.get_child_count() == 0 and not hud.transaction_feedback.visible,"no large transaction notification panels")
			inv.add_coins(100)
			check(hud.floating_feedback.get_child_count() > 0,"successful income still uses small floating text")
			hud.show_transaction_feedback("+100 Xu")
			check(hud.transaction_feedback.get_child_count() == 0 and not hud.transaction_feedback.visible,"legacy callers cannot create large popups")
			if "--capture" in OS.get_cmdline_user_args():
				await create_timer(1.1).timeout
				hud.hotbar.select_slot(0)
				await screenshot("hud")
			check(manager.reset_game(),"cleanup")
	print("PASS: " + stage)
	quit()
