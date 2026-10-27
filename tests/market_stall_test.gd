extends SceneTree

var inv: Node
var manager: Node
var orders: Node
var farm: Node
var hud: Node
var player: Node2D
var stall: Node2D
var panel: PanelContainer
var watch_sale: bool = false
var commits: int = 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: "+message)
		quit(1)
		assert(value,message)

func disk() -> ConfigFile:
	var data := ConfigFile.new()
	check(data.load(manager.SAVE_PATH) == OK,"isolated save readable")
	return data

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func observe_sale() -> void:
	if not watch_sale:
		return
	commits += 1
	check(inv.selling_item and panel.selling and panel.sell.disabled and panel.sell_all.disabled,"transaction locks buttons and generic seller during notification")
	check(not inv.sell_item("wheat",1),"reentrant sale never rewards twice")
	panel._sell(1)
	var saved := disk()
	check(saved.get_value("inventory","coins") == inv.coins,"Coins autosaved after complete sale")
	for item in inv.sellable_items():
		check(saved.get_value("inventory",item) == inv.get(item),"saved item and Coins agree: "+item)

func prepare() -> void:
	check(manager.reset_game(),"reset fixture")
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.normalize_exp()
	inv.coins = 1000
	inv.silo_capacity = 100
	inv.barn_capacity = 100
	inv.wheat = 12
	inv.bread = 8
	inv.egg = 3
	inv.inventory_changed.emit()
	player.position = stall.position+Vector2(0,64)
	await create_timer(0.1).timeout
	check(stall.can_interact() and stall.is_in_group("farm_interactables"),"default Stall is reachable and uses central interaction")
	await key(KEY_E)
	check(panel.visible and panel.active_stall == stall and hud.blocks_world_input() and not hud.hotbar.visible,"E opens compact modal and hides hotbar")
	check(hud.floating_feedback.z_index > panel.z_index,"small player feedback stays visible above sale panel")

func core_checks() -> void:
	await prepare()
	check(stall.position == Vector2(920,650) and manager.LandData.zone_at(stall.position) == "farm_core","Stall on initial owned farm, separate from fishing and fields")
	var names: Array = ["wheat","corn","carrot","soybean","sugarcane","cotton","flax","egg","milk","small_fish","river_fish","golden_fish","bread","corn_bread","carrot_pie","egg_cake","milk_cake","pancake","cream","butter","cheese"]
	for item in names:
		check(item in inv.sellable_items() and panel.rows.has(item),"catalog includes priced item: "+item)
	for item in ["wheat_seed","axe","hammer","fishing_rod","chicken_feed","cow_feed","wood","stone","coins","quest_token","cotton_thread"]:
		check(item not in inv.sellable_items() and not inv.sell_item(item,1),"unsafe or unpriced item excluded: "+item)
	var order_snapshot: Array = orders.orders.duplicate(true)
	var initial_coins: int = inv.coins
	inv.coins = 9223372036854775802
	check(not inv.sell_item("wheat",1) and inv.wheat == 12 and inv.coins == 9223372036854775802,"overflow cannot make Coins negative or consume item")
	inv.coins = initial_coins
	panel._select_item("bread")
	check(panel.rows.values().filter(func(row): return row["button"].button_pressed).size() == 1,"only the selected product is highlighted")
	await create_timer(0.1).timeout
	await click(panel.plus.get_global_rect().get_center())
	await click(panel.plus.get_global_rect().get_center())
	check(panel.quantity == 3,"plus button adjusts selected quantity")
	hud.floating_feedback.clear()
	watch_sale = true
	await click(panel.sell.get_global_rect().get_center())
	watch_sale = false
	check(commits == 1 and inv.bread == 5 and inv.coins == 1096,"one click sells 3 Bread for data price with one Inventory signal")
	var texts: Array = hud.floating_feedback.get_children().map(func(label): return label.text)
	check(texts.size() == 2 and tr("TRADE_ITEM") % [-3,root.get_node("Localization").display_name("bread")] in texts and tr("TRADE_ITEM") % [96,tr("UI_COINS")] in texts,"only existing floating feedback shows item loss and coin gain")
	watch_sale = true
	await click(panel.sell_five.get_global_rect().get_center())
	watch_sale = false
	check(commits == 2 and inv.bread == 0 and inv.coins == 1256 and panel.sell.disabled,"Sell 5 uses one exact transaction")
	for index in range(8):
		panel.sell_five.pressed.emit()
		panel.sell_all.pressed.emit()
	check(inv.bread == 0 and inv.coins == 1256,"spamming empty item never duplicates Coins or subtracts negative quantity")
	panel._select_item("wheat")
	for amount in [-2,0,13]:
		check(not inv.sell_item("wheat",amount),"invalid amount rejected")
	var used: int = inv.storage_used("silo")
	watch_sale = true
	await click(panel.sell_all.get_global_rect().get_center())
	watch_sale = false
	check(commits == 3 and inv.wheat == 0 and inv.coins == 1376 and inv.storage_used("silo") == used-12,"Sell All frees Silo and commits once")
	panel._select_item("egg")
	watch_sale = true
	await click(panel.sell_one.get_global_rect().get_center())
	watch_sale = false
	check(commits == 4 and inv.egg == 2 and inv.coins == 1394,"Sell 1 uses current Egg price")
	check(orders.orders == order_snapshot,"direct sales never complete or replace existing Orders")
	for item in names:
		inv.set(item,2)
		inv.inventory_changed.emit()
		panel._select_item(item)
		var before_coins: int = inv.coins
		used = inv.storage_used("silo" if item in inv.SILO_ITEMS else "barn")
		watch_sale = true
		panel._sell(2)
		watch_sale = false
		check(inv.get(item) == 0 and inv.coins == before_coins+2*inv.sell_price(item),"generic sale respects central price: "+item)
		check(inv.storage_used("silo" if item in inv.SILO_ITEMS else "barn") == used-2,"sale frees existing storage: "+item)
		check(panel.rows[item]["owned"].text == "0","open panel updates immediately: "+item)
	var row_id: int = panel.rows["wheat"]["button"].get_instance_id()
	var connection_count: int = inv.inventory_changed.get_connections().size()
	for index in range(5):
		panel.close()
		hud.open_market_stall(stall)
	check(panel.rows["wheat"]["button"].get_instance_id() == row_id and inv.inventory_changed.get_connections().size() == connection_count,"reopening reuses rows and never duplicates signals")
	inv.player_level = 1
	inv.inventory_changed.emit()
	check(not panel.rows["flax"]["button"].visible and not panel.rows["small_fish"]["button"].visible and not inv.sell_item("corn",1) and not inv.sell_item("small_fish",1),"locked crops and fishing stay unavailable")
	check(not farm.Placement.can_place(farm.get_node("FeedMill"),stall.position),"Stall footprint blocks placement")
	await key(KEY_E)
	check(panel.visible and not hud.order_panel.visible,"E cannot open world interactions behind market")
	hud._toggle_storage()
	check(hud.storage_panel.visible and not panel.visible,"Tab/Storage replaces market without stacking")
	hud.close_all_panels()
	await key(KEY_E)
	await key(KEY_ESCAPE)
	check(not panel.visible and not hud.blocks_world_input() and hud.hotbar.visible,"ESC closes only current modal and restores hotbar")
	player.position = Vector2(800,600)
	await create_timer(0.1).timeout
	hud.open_market_stall(stall)
	check(not panel.visible,"cannot open Stall from outside interaction range")
	player.position = stall.position+Vector2(0,64)
	await create_timer(0.1).timeout
	player.interact_at_screen_position(stall.get_global_transform_with_canvas().origin)
	check(panel.visible,"normal mouse click uses same central interaction as E")
	panel._select_item("wheat")
	for viewport_size in [Vector2i(1280,720),Vector2i(800,600),Vector2i(480,640)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await create_timer(0.1).timeout
		check(Rect2(Vector2.ZERO,Vector2(viewport_size)).encloses(panel.get_global_rect()),"compact market fits resized viewport")
		check(panel.get_global_rect().encloses(panel.sell.get_global_rect()),"quantity controls stay inside panel")
	for index in range(50):
		var order: Dictionary = orders._generate_order()
		var total: int = 0
		for item in order["requirements"]:
			total += inv.sell_price(item)*order["requirements"][item]
		check(order["coin_reward"] >= ceili(total*1.25),"existing Orders reward more than direct sale")
	hud.close_all_panels()
	check(manager.reset_game() and is_instance_valid(stall),"reset retains default Stall without new ownership save")
	check(not disk().has_section("market_stall"),"instant-sale Stall needs no save state")

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	orders = root.get_node("OrderManager")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	player = farm.get_node("Player")
	stall = farm.get_node("MarketStall")
	panel = hud.market_stall_panel
	inv.inventory_changed.connect(observe_sale)
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"stall_core":
			await core_checks()
		"stall_write":
			await prepare()
			panel._select_item("bread")
			panel._sell(3)
			check(inv.bread == 5 and inv.coins == 1096,"save fixture sale")
		"stall_read":
			check(inv.bread == 5 and inv.coins == 1096 and inv.wheat == 12 and inv.egg == 3,"Coins and items persist after sale")
			check(farm.get_children().filter(func(child): return child.name == "MarketStall").size() == 1,"load has one default Stall without duplicate spawn")
			check(manager.reset_game(),"reset after reload")
		"stall_reset_read":
			check(inv.coins == 100 and inv.bread == 0 and inv.wheat_seed == 10 and is_instance_valid(stall),"reset reload keeps default Stall and clean progress")
	if "--capture" in OS.get_cmdline_user_args():
		await prepare()
		panel._select_item("bread")
		hud.floating_feedback.clear()
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://market_stall.png") == OK,"capture compact sale panel")
		check(manager.reset_game(),"capture cleanup")
	print("PASS: "+stage)
	quit()
