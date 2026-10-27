extends SceneTree

var inv: Node
var manager: Node
var orders: Node
var farm: Node
var hud: Node
var watch_delivery: String = ""
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

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func experience_total() -> int:
	return 50*inv.player_level*(inv.player_level-1)+inv.player_exp

func observe_delivery() -> void:
	if watch_delivery.is_empty():
		return
	commits += 1
	check(orders.busy and not orders.complete_order(watch_delivery) and not orders.cancel_order(watch_delivery),"reentrant delivery/cancel cannot reward old order twice")
	var saved := disk()
	check(saved.get_value("inventory","coins") == inv.coins and saved.get_value("orders","active") == orders.orders,"one autosave commits consumed items, rewards and replacement together")
	for item in manager.INVENTORY_DEFAULTS:
		check(saved.get_value("inventory",item) == inv.get(item),"saved item matches committed Inventory")

func prepare() -> void:
	check(manager.reset_game(),"reset fixture")
	inv.player_level = 18
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.normalize_exp()
	for id in inv.Progression.BUILDINGS:
		inv.set("owns_"+id,true)
	inv.chicken_count = 1
	inv.cow_count = 1
	inv.inventory_changed.emit()
	orders.reset_orders()

func generator_checks() -> void:
	check(manager.reset_game(),"early game fixture")
	orders.rng.seed = 20261027
	for level in [1,3,6,8,10,15,18]:
		inv.player_level = level
		inv.normalize_exp()
		for sample in range(60):
			var order: Dictionary = orders._generate_order()
			check(orders._is_valid_order(order),"generated basket fits storage and unlocks")
			check(inv.player_level >= orders.Data.TIERS[order["difficulty"]]["level"],"tiers respect minimum level")
			for item in order["requirements"]:
				check(inv.CropData.CROPS.has(item.to_upper()) or inv.FishingData.FISH.has(item),"no animal/processed orders without owned production")
			if level == 1:
				check(order["difficulty"] == "EASY" and order["requirements"].keys() == ["wheat"] and order["requirements"]["wheat"] <= 5,"early baskets are small crop orders")
	prepare()
	for item in orders.item_info():
		check(orders.item_available(item),"all unlocked products have owned ingredient sources: "+item)
	inv.cow_count = 0
	for item in ["milk","milk_cake","pancake","cream","butter","cheese"]:
		check(not orders.item_available(item),"missing cows blocks entire milk production chain: "+item)
	inv.cow_count = 1
	inv.owns_bakery = false
	check(not orders.item_available("bread") and not orders.item_available("egg_cake"),"Bakery ownership gate")
	inv.owns_bakery = true
	inv.owns_dairy = false
	check(not orders.item_available("cheese"),"Dairy ownership gate")
	inv.owns_dairy = true
	var premium: Dictionary = orders._generate_order("PREMIUM")
	inv.player_level = 14
	check(not orders._is_valid_order(premium),"save cannot restore a Premium tier below its unlock level")
	inv.player_level = 18
	var counts: Dictionary = {"EASY":0,"NORMAL":0,"HARD":0,"PREMIUM":0}
	for index in range(5000):
		counts[orders._pick_difficulty()] += 1
	check(counts["EASY"] > counts["NORMAL"] and counts["NORMAL"] > counts["HARD"] and counts["HARD"] > counts["PREMIUM"] and counts["PREMIUM"] > 0,"weighted selection favors easy and keeps Premium rare")
	for tier in orders.Data.TIERS:
		for index in range(40):
			var order: Dictionary = orders._generate_order(tier)
			check(order["difficulty"] == tier and orders._is_valid_order(order),"all difficulty baskets remain producible and fit storage")
			check(order["requirements"].size() >= orders.Data.TIERS[tier]["types_min"] and order["requirements"].size() <= orders.Data.TIERS[tier]["types_max"],"higher tiers use intended item diversity")
			var direct_price: int = 0
			for item in order["requirements"]:
				direct_price += inv.sell_price(item)*order["requirements"][item]
			check(order["coin_reward"] > direct_price and order["exp_reward"] > 0,"all new orders pay more than Market and add EXP")
	# Even a small Barn cannot receive an impossible combined basket.
	inv.barn_capacity = 2
	inv.silo_capacity = 5
	for index in range(50):
		check(orders._is_valid_order(orders._generate_order("PREMIUM")),"combined storage budgets cap generated quantities")

func core_checks() -> void:
	generator_checks()
	prepare()
	hud.open_orders()
	await create_timer(0.1).timeout
	check(hud.order_cards.get_child_count() == 3 and hud.blocks_world_input() and not hud.hotbar.visible,"same three-slot Order modal")
	var first: Dictionary = orders.orders[0].duplicate(true)
	var others: Array = orders.orders.slice(1).duplicate(true)
	var coins: int = inv.coins
	var card: Node = hud.order_cards.get_child(0)
	await click(card.cancel)
	check(orders.is_waiting(orders.orders[0]) and orders.orders.slice(1) == others,"cancel only empties selected slot")
	var deadline: float = orders.orders[0]["cooldown_until"]
	check(deadline >= Time.get_unix_time_from_system()+178 and inv.coins == coins and not orders.complete_order(first["order_id"]),"cancel has full three-minute delay and no reward")
	for index in range(6):
		check(not orders.cancel_order(first["order_id"]),"cannot reroll a waiting slot")
	check(orders.orders[0]["cooldown_until"] == deadline and card.waiting_label.visible and card.countdown.text.contains(":"),"spam never restarts cooldown")
	check(disk().get_value("orders","active")[0]["cooldown_until"] == deadline,"cancel immediately saves timestamp")
	var card_id: int = card.get_instance_id()
	var row_ids: Array = hud.order_cards.get_child(1).items.get_children().map(func(row): return row.get_instance_id())
	var saved_text: String = FileAccess.get_file_as_string(manager.SAVE_PATH)
	await create_timer(1.1).timeout
	check(card.get_instance_id() == card_id and hud.order_cards.get_child(1).items.get_children().map(func(row): return row.get_instance_id()) == row_ids,"countdown reuses card and item nodes")
	check(FileAccess.get_file_as_string(manager.SAVE_PATH) == saved_text,"countdown ticks do not save each second")
	orders.orders[0]["cooldown_until"] = Time.get_unix_time_from_system()-1
	orders._check_cooldowns()
	check(not orders.is_waiting(orders.orders[0]) and orders.orders[0]["order_id"] != first["order_id"] and orders.orders.slice(1) == others,"expiry generates exactly one replacement")
	check(orders.cooldown_timer.is_stopped(),"no cooldown timer work when all slots are active")
	var active: Dictionary = orders.orders[0].duplicate(true)
	check(not orders.can_complete_order(active["order_id"]) and card.complete.disabled,"incomplete basket disables delivery")
	for item in active["requirements"]:
		inv.set(item,active["requirements"][item])
	inv.inventory_changed.emit()
	hud.floating_feedback.clear()
	coins = inv.coins
	var exp: int = experience_total()
	watch_delivery = active["order_id"]
	commits = 0
	await click(card.complete)
	watch_delivery = ""
	check(commits == 1 and inv.coins == coins+active["coin_reward"] and experience_total() == exp+active["exp_reward"],"real delivery click commits exact Coins and EXP once")
	for item in active["requirements"]:
		check(inv.get(item) == 0,"each required item deducted once")
	check(not orders.complete_order(active["order_id"]),"old order cannot reward after replacement")
	var texts: Array = hud.floating_feedback.get_children().map(func(label): return label.text)
	check(tr("ORDER_EXP_FEEDBACK") % active["exp_reward"] in texts and tr("TRADE_ITEM") % [active["coin_reward"],tr("UI_COINS")] in texts and hud.order_message.text.is_empty(),"only shared small coin and EXP feedback on delivery")
	check(hud.floating_feedback.z_index > hud.order_panel.z_index,"floating reward remains visible above board")
	check(manager.reset_game() and orders.orders.size() == 3 and orders.cooldown_timer.is_stopped(),"reset removes every cooldown and produces three starting orders")

func run_checks() -> void:
	await process_frame
	inv = root.get_node("Inventory")
	manager = root.get_node("SaveManager")
	orders = root.get_node("OrderManager")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	hud = farm.get_node("HUD")
	inv.inventory_changed.connect(observe_delivery)
	await create_timer(0.1).timeout
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"orders_core":
			await core_checks()
		"orders_write":
			prepare()
			check(orders.cancel_order(orders.orders[1]["order_id"]),"save one waiting slot alongside two active tiers")
			check(manager.save_game(),"save mixed order state")
		"orders_read":
			var saved: Array = disk().get_value("orders","active")
			check(orders.orders == saved and orders.is_waiting(orders.orders[1]) and orders.cooldown_timer.time_left > 0,"reload preserves exact requirements, rewards, tiers and cooldown")
			check(not orders.cancel_order(orders.orders[1]["order_id"]),"reload cannot skip cancellation delay")
			orders.orders[1]["cooldown_until"] = Time.get_unix_time_from_system()-1
			check(manager.save_game(),"expired offline fixture")
		"orders_expired_read":
			check(not orders.orders.any(orders.is_waiting) and orders._is_valid_order(orders.orders[1]),"offline-expired slot gets a new valid order")
			check(manager.reset_game(),"offline cleanup")
		"orders_legacy_write":
			prepare()
			var old := {"order_id":"order_990001","requirements":{"bread":1},"coin_reward":40,"exp_reward":0}
			orders.restore_orders([old])
			check(manager.save_game(),"legacy base")
			var saved := disk()
			var active: Array = saved.get_value("orders","active")
			active[0].erase("difficulty")
			saved.set_value("orders","active",active)
			check(saved.save(manager.SAVE_PATH) == OK,"legacy missing-difficulty fixture")
		"orders_legacy_read":
			var old: Dictionary = orders.orders[0]
			check(old["order_id"] == "order_990001" and old["requirements"] == {"bread":1} and old["coin_reward"] == 40 and old["exp_reward"] == 0 and old["difficulty"] == "EASY","old order migrates without reroll or reward changes")
			check(manager.reset_game(),"legacy cleanup")
	if "--capture" in OS.get_cmdline_user_args():
		prepare()
		orders.orders = [orders._generate_order("EASY"),orders._generate_order("HARD"),orders._generate_order("PREMIUM")]
		orders.cancel_order(orders.orders[0]["order_id"])
		hud.open_orders()
		hud.floating_feedback.clear()
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://order_board.png") == OK,"capture tiers, item icons and waiting slot")
		check(manager.reset_game(),"capture cleanup")
	print("PASS: "+stage)
	quit()
