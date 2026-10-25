extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func inspect_text(node: Node) -> void:
	var text: String = ""
	if node is Label or node is Button:
		text = node.tr(node.text)
	var untranslated := RegEx.new()
	untranslated.compile(r"(?i)\b(Wheat|Corn|Carrot|Coins|Level|Milk|Eggs?|Owned|Locked|Buy|Sell|Close|Upgrade|House|READY|HUNGRY|PRODUCING|IDLE|Golden|Small|River|Forest|Farm|Reset|Requires|Order|Reward|Seeds?|Barn|Silo)\b")
	check(untranslated.search(text) == null, "untranslated player text: " + str(node.get_path()) + " = " + text)
	var unresolved := RegEx.new()
	unresolved.compile(r"\b(UI|ITEM|BUILDING|WORLD|FISHING|STATE|TITLE|ERROR|DEFAULT|HUD|TOOLS|RESET|ORDER)_[A-Z_]+\b")
	check(unresolved.search(text) == null, "missing translation key: " + text)
	for child in node.get_children():
		inspect_text(child)

func run_checks() -> void:
	await process_frame
	await process_frame
	var localization = root.get_node("Localization")
	var inv = root.get_node("Inventory")
	var manager = root.get_node("SaveManager")
	check(manager.SAVE_PATH == "res://test-save.cfg", "isolated save required")
	check(TranslationServer.get_locale() == "vi", "Vietnamese startup locale")
	check(tr("UI_COINS") == "Xu" and localization.display_name("cow_feed") == "Thức ăn cho bò", "native translation and item ID mapping")
	check(localization.display_name("CARROT") == "Cà rốt" and localization.state("PRODUCING") == "Đang sản xuất", "names and state labels")
	check(inv.CropData.CROPS["WHEAT"]["name"] == "Wheat", "internal data names untouched")
	check(tr("HUD_MAIN") % [100,1,0,100] == "Xu: 100 | Cấp độ: 1 | Kinh nghiệm: 0 / 100", "numeric placeholders")
	TranslationServer.set_locale("en")
	check(tr("UI_COINS") == "Xu", "English catalog can fall back to Vietnamese")
	TranslationServer.set_locale("vi")
	var farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	check(manager.reset_game(), "reset test fixture")
	var hud = farm.get_node("HUD")
	check(not hud.inventory_label.text.contains("Lúa mì") and hud.inventory_label.text.contains("Xu: 100"), "compact Vietnamese HUD")
	check(hud.storage_panel.get_node("Margin/Content/Tabs/Produce/Items").text.contains("Lúa mì"), "Vietnamese inventory in storage panel")
	check(hud.reset_confirmation.tr(hud.reset_confirmation.dialog_text) == "Xóa toàn bộ tiến trình và chơi lại?", "reset dialog")
	check(hud.tools_unlock_popup.tr(hud.tools_unlock_popup.dialog_text).contains("Búa"), "tools notification")
	inv.tools_unlock_notified = true
	inv.player_level = 10
	inv.coins = 10000
	inv.normalize_exp()
	inv.inventory_changed.emit()
	check(inv.buy_seed("CORN") and inv.corn_seed == 1 and inv.coins == 9990, "translated Shop keeps IDs/prices")
	for id in manager.STATION_IDS:
		check(inv.buy_building(id), "building purchase")
	check(inv.buy_animal("chicken") and inv.buy_animal("cow"), "animal IDs remain valid")
	hud.open_build()
	inspect_text(hud)
	hud.close_all_panels()
	var player = farm.get_node("Player")
	for name in ["FeedMill","ChickenCoop","CowShed"]:
		player.position = farm.get_node(name).position
		await create_timer(0.1).timeout
		hud.open_station(farm.get_node(name))
		inspect_text(hud)
		hud.close_all_panels()
	hud.open_orders()
	inspect_text(hud)
	hud.close_all_panels()
	check(inv.add_item("small_fish",1), "fish item ID")
	player.position = farm.get_node("FishMarket").position
	await create_timer(0.1).timeout
	hud.open_fish_market(farm.get_node("FishMarket"))
	check(hud.fish_market_panel.rows["small_fish"]["label"].text.contains("Cá nhỏ"), "Vietnamese fish market")
	inspect_text(farm)
	check(manager.save_game(), "localized game still saves")
	var saved := ConfigFile.new()
	check(saved.load(manager.SAVE_PATH) == OK and saved.has_section_key("inventory","coins") and saved.has_section_key("fishing","has_fishing_rod"), "English save keys unchanged")
	print("PASS: localization")
	quit()
