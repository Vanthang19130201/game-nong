extends SceneTree

var inv: Node
var manager: Node
var hud: Node
var popup: Control


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)


func ids(level: int) -> Array[String]:
	var result: Array[String] = []
	for item in inv.Progression.unlocks_for_level(level):
		result.append(item["id"])
	return result


func claim(level: int) -> void:
	check(popup.visible and int(popup.active_event["level"]) == level, "popup shows level %d" % level)
	popup.claim_button.pressed.emit()
	await process_frame
	check(inv.last_rewarded_level == level, "claim saved at level %d" % level)


func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "use isolated save")
	root.size = Vector2i(1152, 648)
	root.content_scale_size = root.size
	var farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	popup = hud.get_node("LevelUpPopup")
	await create_timer(0.1).timeout
	check(manager.reset_game(), "reset isolated fixture")
	await process_frame

	var coins_before: int = inv.coins
	check(inv.add_exp(100), "gain enough XP for level 2")
	await process_frame
	check(popup.visible and popup.active_event["unlocks"].any(func(item): return item["id"] == "corn"), "level 2 shows Corn")
	check(popup.active_event["reward"]["coins"] == 100 and inv.coins == coins_before, "level 2 reward waits for claim")
	check(popup.get_node("Card").get_global_rect().position.x >= 0 and popup.get_node("Card").get_global_rect().end.x <= 1152, "popup fits target viewport width")
	check(popup.get_node("Card").get_global_rect().position.y >= 0 and popup.get_node("Card").get_global_rect().end.y <= 648, "popup fits target viewport height")
	check(popup.get_node("Card").get_global_rect().encloses(popup.get_node("Card/Margin/Content/ClaimButton").get_global_rect()), "claim button fits inside popup")
	check(manager.save_game(), "save while a level reward is pending")
	popup.clear_events()
	manager._load_game()
	popup.sync_unclaimed_levels()
	await process_frame
	check(popup.pending_events.size() == 1 and int(popup.active_event["level"]) == 2 and inv.coins == coins_before, "pending popup restores once without paying twice")
	manager.resetting = true
	popup.claim_button.pressed.emit()
	check(inv.last_rewarded_level == 1 and inv.coins == coins_before and popup.visible and popup.get_node("Card/Margin/Content/Error").visible, "failed save keeps reward pending and can be retried")
	manager.resetting = false
	await claim(2)
	check(inv.coins == coins_before + 100, "level 2 coins granted once")
	check(not inv.claim_level_reward(2) and inv.coins == coins_before + 100, "duplicate level 2 claim rejected")

	coins_before = inv.coins
	check(inv.add_exp(200), "gain enough XP for level 3")
	var level_three_ids: Array[String] = ids(3)
	check("carrot" in level_three_ids and "bakery" in level_three_ids, "level 3 data includes Carrot and Bakery")
	check(popup.active_event["reward"]["coins"] == 125, "level 3 reward formula")
	await claim(3)
	check(inv.coins == coins_before + 125, "level 3 coins granted once")

	check(ids(4).has("feed_mill") and ids(4).has("chicken_feed"), "level 4 Feed Mill and Chicken Feed")
	check(ids(5).has("chicken_coop"), "level 5 Chicken Coop")
	for id in ["soybean", "chicken", "axe", "hammer"]:
		check(ids(6).has(id), "level 6 unlock: " + id)
	check(ids(7).has("egg_orders") and ids(7).has("egg_cake"), "level 7 Egg Orders and recipe")
	check(ids(8).has("sugarcane") and ids(8).has("cow_shed") and ids(8).has("cow_feed"), "level 8 crop, shed and recipe")
	check(ids(9).has("cow"), "level 9 Cow")
	for id in ["milk", "fishing_area", "fishing_rod", "milk_cake"]:
		check(ids(10).has(id), "level 10 unlock: " + id)
	check(ids(12).has("cotton"), "level 12 Cotton")
	check(ids(15).has("dairy") and ids(15).has("cream") and ids(15).has("butter") and ids(15).has("cheese"), "level 15 Dairy recipes")
	check(ids(17).has("spinning_machine") and ids(17).has("cotton_thread"), "level 17 Spinning Machine recipe")
	check(ids(18).has("flax"), "level 18 Flax")
	check(inv.Progression.reward_for_level(15)["coins"] == 525, "level 15 milestone bonus")

	# A 4 -> 6 jump queues and pays each intervening level in order.
	inv.player_level = 4
	inv.player_exp = 0
	inv.last_rewarded_level = 4
	inv.tools_unlock_notified = true
	coins_before = inv.coins
	check(inv.add_exp(900), "one XP award crosses levels 5 and 6")
	check(popup.pending_events.size() == 2 and int(popup.active_event["level"]) == 5, "multi-level event queue starts at 5")
	check(popup.pending_events[1]["unlocks"].any(func(item): return item["id"] == "soybean"), "queued level 6 retains unlock data")
	await claim(5)
	check(popup.visible and int(popup.active_event["level"]) == 6, "level 6 popup follows level 5")
	await claim(6)
	check(inv.coins == coins_before + 275 + 200, "multi-level rewards granted once each")

	# Level 9 -> 10 notifies all fishing unlocks and still grants the existing rod.
	inv.player_level = 9
	inv.player_exp = 0
	inv.last_rewarded_level = 9
	inv.fishing_unlocked = false
	inv.has_fishing_rod = false
	coins_before = inv.coins
	check(inv.add_exp(900), "gain level 10")
	check(inv.is_zone_unlocked("fishing") and inv.has_fishing_rod, "existing fishing unlock remains active")
	check(popup.active_event["unlocks"].size() <= 4, "level 10 unlock list stays compact")
	check(popup.active_event["reward"]["coins"] == 400, "level 10 reward")
	await claim(10)
	check(inv.coins == coins_before + 400, "level 10 reward once")

	# The largest current unlock group still fits without clipping at 1152x648.
	inv.player_level = 14
	inv.player_exp = 0
	inv.last_rewarded_level = 14
	coins_before = inv.coins
	check(inv.add_exp(1400), "gain level 15")
	await process_frame
	var popup_card: Rect2 = popup.get_node("Card").get_global_rect()
	var unlock_rect: Rect2 = popup.get_node("Card/Margin/Content/UnlockGrid").get_global_rect()
	var claim_rect: Rect2 = popup.get_node("Card/Margin/Content/ClaimButton").get_global_rect()
	check(popup.active_event["unlocks"].size() == 4 and popup_card.encloses(unlock_rect), "largest unlock group fits in card")
	check(popup_card.encloses(claim_rect) and Rect2(Vector2.ZERO,Vector2(1152,648)).encloses(claim_rect), "level 15 claim button is not clipped: card=%s button=%s" % [popup_card, claim_rect])
	await claim(15)
	check(inv.coins == coins_before + 525, "level 15 milestone reward")

	# A save/reload with a claimed level does not reopen or pay that level again.
	coins_before = inv.coins
	check(manager.save_game(), "save claimed reward")
	manager._load_game()
	popup.sync_unclaimed_levels()
	await process_frame
	check(inv.last_rewarded_level == inv.player_level and not popup.visible, "claimed rewards do not replay after reload")
	check(inv.coins == coins_before, "reload does not duplicate Coins")

	# Legacy save without the new field migrates directly to its current level.
	inv.player_level = 17
	inv.player_exp = 0
	inv.last_rewarded_level = 17
	check(manager.save_game(), "write legacy fixture")
	var old_save := ConfigFile.new()
	check(old_save.load(manager.SAVE_PATH) == OK, "read legacy fixture")
	old_save.erase_section_key("player", "last_rewarded_level")
	old_save.set_value("player", "player_level", 17)
	check(old_save.save(manager.SAVE_PATH) == OK, "remove new field from legacy fixture")
	manager._load_game()
	popup.sync_unclaimed_levels()
	await process_frame
	check(inv.last_rewarded_level == 17 and not popup.visible, "level 17 legacy save gets no retroactive popup")
	coins_before = inv.coins
	check(inv.add_exp(1700), "legacy player can level to 18")
	check(popup.visible and int(popup.active_event["level"]) == 18 and popup.active_event["unlocks"].any(func(item): return item["id"] == "flax"), "future level still notifies migrated save")
	await claim(18)
	check(inv.coins == coins_before + 500, "legacy level 18 reward is paid once")
	check(manager.reset_game(), "cleanup")
	print("PASS: level_up")
	quit()
