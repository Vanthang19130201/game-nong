extends SceneTree

const MIXED: Array[String] = ["chicken_feed","cow_feed","chicken_feed"]
var farm: Node
var inv: Node
var manager: Node
var mill: Node
var hud: Node
var watch_commit: bool = false
var expected_total: int = 0
var commits: int = 0
var cancel_target: Dictionary = {}
var expected_refund: Array = []

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

func items(entries: Array) -> Array:
	return entries.map(func(entry): return entry["item"])

func feedback() -> Array:
	return hud.floating_feedback.get_children().map(func(label): return label.text)

func observe_commit() -> void:
	if not expected_refund.is_empty():
		check(mill.collecting and [inv.wheat,inv.corn,inv.carrot] == expected_refund,"refund commits all ingredients together")
		for slot in hud.feed_queue.slots:
			check(slot["cancel"].disabled,"cancel buttons disabled during refund commit")
		check(not mill.cancel_job(cancel_target) and not mill.collect_all(),"reentrant cancellation and collection are blocked")
		var saved_refund := disk()
		check(saved_refund.get_value("feed_mill","queue") == mill.queue,"autosave removes cancelled job with refund")
		for item in ["wheat","corn","carrot"]:
			check(saved_refund.get_value("inventory",item) == inv.get(item),"autosave contains exact refund: "+item)
	if not watch_commit:
		return
	commits += 1
	check(hud.collect_button.disabled,"collect button stays disabled during commit")
	var saved := disk()
	var total: int = saved.get_value("inventory","chicken_feed") + saved.get_value("inventory","cow_feed") + saved.get_value("feed_mill","queue").size() + saved.get_value("feed_mill","outputs").size()
	check(total == expected_total,"autosave never contains both an awarded item and its old output")

func prepare() -> void:
	check(manager.reset_game(),"reset fixture")
	inv.player_level = 10
	inv.tools_unlock_notified = true
	inv.coins = 10000
	inv.silo_capacity = 100
	inv.wheat = 20
	inv.corn = 30
	inv.carrot = 20
	inv.inventory_changed.emit()
	check(inv.buy_building("feed_mill"),"existing Feed Mill purchase")
	farm.get_node("Player").position = mill.position+Vector2(0,32)
	await create_timer(0.1).timeout
	hud.open_station(mill)
	check(hud.active_station == mill and hud.feed_queue.visible,"same station interaction/panel")
	check(hud.feed_queue.slots.size() == 3 and hud.feed_queue.output_slots.size() == 3,"three visible queue slots and three output spaces")

func enqueue_three() -> void:
	var before: Dictionary = {"wheat":inv.wheat,"corn":inv.corn,"carrot":inv.carrot}
	for item in MIXED:
		check(mill.produce(item),"enqueue " + item)
	check(items(mill.queue) == MIXED and inv.wheat == before["wheat"]-2 and inv.corn == before["corn"]-4 and inv.carrot == before["carrot"]-1,"mixed FIFO queue charges exact existing recipe ingredients")
	var paid: Array = [inv.wheat,inv.corn,inv.carrot]
	check(not mill.produce() and mill.queue.size() == 3 and [inv.wheat,inv.corn,inv.carrot] == paid,"fourth job never charges ingredients")
	check(hud.produce_button.disabled,"full queue disables enqueue button")
	check(mill.queue[0]["state"] == "PRODUCING" and mill.queue[1]["state"] == "QUEUED" and mill.queue[2]["state"] == "QUEUED","one active job, two waiting jobs")

func finish_one() -> void:
	var now: float = Time.get_unix_time_from_system()
	var duration: float = inv.Progression.RECIPES[mill.queue[0]["item"]]["time"]
	mill.started_at = now-duration-1
	mill.ready_at = now-1
	mill._finish_production()

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

func cancellation_checks() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await prepare()
	enqueue_three()
	await create_timer(0.1).timeout
	var deadline: float = mill.ready_at
	cancel_target = mill.queue[1]
	expected_refund = [inv.wheat,inv.corn+2,inv.carrot+1]
	var cancel: Button = hud.feed_queue.slots[1]["cancel"]
	check(cancel.is_visible_in_tree() and not cancel.disabled,"small cancel button shown for waiting job")
	await click(cancel.get_global_rect().get_center())
	check(items(mill.queue) == ["chicken_feed","chicken_feed"] and mill.ready_at == deadline,"click cancels correct waiting recipe without resetting current timer")
	expected_refund.clear()
	var paid: Array = [inv.wheat,inv.corn,inv.carrot]
	for index in range(5):
		check(not mill.cancel_job(cancel_target),"same cancelled job cannot be refunded again")
	check([inv.wheat,inv.corn,inv.carrot] == paid,"spam never duplicates refunds")
	check(mill.produce("chicken_feed"),"enqueue identical waiting recipe")
	var first_waiting: Dictionary = mill.queue[1]
	var last_waiting: Dictionary = mill.queue[2]
	check(mill.cancel_job(last_waiting) and is_same(mill.queue[1],first_waiting),"identical recipes cancel by job identity, not dictionary equality")
	cancel_target = mill.queue[0]
	expected_refund = [inv.wheat+1,inv.corn+1,inv.carrot]
	check(mill.cancel_job(cancel_target),"active production can be cancelled with full refund")
	expected_refund.clear()
	check(mill.queue.size() == 1 and is_same(mill.queue[0],first_waiting) and mill.state == "PRODUCING" and mill.started_at >= Time.get_unix_time_from_system()-1,"next job starts from now after active cancellation")
	# One free space cannot accept the two-ingredient refund.
	inv.silo_capacity = inv.storage_used("silo")+1
	inv.inventory_changed.emit()
	hud.floating_feedback.clear()
	var before: Dictionary = mill.get_save_data().duplicate(true)
	paid = [inv.wheat,inv.corn,inv.carrot]
	check(not mill.cancel_job(first_waiting) and mill.get_save_data() == before and [inv.wheat,inv.corn,inv.carrot] == paid,"insufficient total storage rejects refund atomically and preserves job")
	check(tr("FEED_REFUND_FULL") in feedback(),"refund capacity failure uses small floating feedback")
	inv.silo_capacity += 1
	check(mill.cancel_job(first_waiting) and mill.queue.is_empty() and mill.state == "IDLE","exact storage space accepts whole refund")
	check(not hud.feed_queue.slots[0]["cancel"].visible,"empty slot hides cancel button")
	inv.silo_capacity = 100
	check(mill.produce(),"ready boundary fixture")
	var finished: Dictionary = mill.queue[0]
	mill.started_at = Time.get_unix_time_from_system()-20
	mill.ready_at = Time.get_unix_time_from_system()-1
	paid = [inv.wheat,inv.corn,inv.carrot]
	check(not mill.cancel_job(finished) and mill.outputs.size() == 1 and [inv.wheat,inv.corn,inv.carrot] == paid,"completed job cannot both refund ingredients and produce output")
	check(hud.feed_queue.output_slots[0]["cancel"] == null and mill.collect_all(),"finished outputs only collect, never cancel")
	check(manager.reset_game(),"cancellation fixture cleanup")

func core_checks() -> void:
	await prepare()
	enqueue_three()
	finish_one()
	check(items(mill.outputs) == ["chicken_feed"] and items(mill.queue) == ["cow_feed","chicken_feed"] and mill.state == "PRODUCING","first output stays ready while next mixed job automatically starts")
	check(not hud.collect_button.disabled and hud.feed_queue.output_slots[0]["status"].text == tr("FEED_FINISHED"),"ready output can be collected while next job runs")
	finish_one()
	finish_one()
	check(items(mill.outputs) == MIXED and mill.queue.is_empty() and inv.chicken_feed == 0 and inv.cow_feed == 0,"completion keeps all three outputs without automatic rewards")
	# More work can wait behind a full output buffer, but cannot run until room.
	for index in range(3):
		check(mill.produce("chicken_feed"),"queue work behind full buffer")
	check(mill.production_timer.is_stopped() and mill.queue[0]["started_at"] == 0 and mill.outputs.size() == 3,"full buffer pauses waiting work")
	for item in inv.BARN_ITEMS:
		inv.set(item,0)
	inv.milk = inv.barn_capacity
	inv.inventory_changed.emit()
	hud.floating_feedback.clear()
	var data: Dictionary = mill.get_save_data().duplicate(true)
	check(not mill.collect_all() and mill.get_save_data() == data and inv.chicken_feed == 0 and inv.cow_feed == 0,"full Barn preserves every output and queue timestamp")
	check(tr("FEED_STORAGE_FULL") in feedback() and not hud.transaction_feedback.visible,"full Barn uses only a small floating message")
	inv.milk -= 1
	inv.inventory_changed.emit()
	hud.floating_feedback.clear()
	expected_total = 6
	watch_commit = true
	commits = 0
	check(mill.collect_all(),"one free Barn slot receives one output")
	check(commits == 1 and inv.chicken_feed == 1 and inv.cow_feed == 0 and items(mill.outputs) == ["cow_feed","chicken_feed"],"partial collection keeps two exact remaining products and saves once")
	check(mill.queue[0]["state"] == "PRODUCING" and mill.ready_at > Time.get_unix_time_from_system(),"free output space resumes waiting production from now")
	var remaining: Array = mill.outputs.duplicate(true)
	var deadline: float = mill.ready_at
	for index in range(6):
		check(not mill.collect_all(),"spam while full is rejected")
	check(inv.chicken_feed == 1 and inv.cow_feed == 0 and mill.outputs == remaining and mill.ready_at == deadline,"spam cannot duplicate feed or reset active timer")
	watch_commit = false
	inv.milk = 0
	inv.inventory_changed.emit()
	watch_commit = true
	check(mill.collect_all() and inv.chicken_feed == 2 and inv.cow_feed == 1 and mill.outputs.is_empty(),"collect all takes the two remaining products exactly once")
	check(not mill.collect_all(),"empty output never rewards again")
	watch_commit = false
	check(not hud.collect_button.disabled == (not mill.outputs.is_empty()),"collect button reflects ready output")
	check(manager.reset_game() and mill.queue.is_empty() and mill.outputs.is_empty(),"reset clears queue and outputs")

func capture() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await prepare()
	enqueue_three()
	finish_one()
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://feed_mill_queue.png") == OK,"capture compact queue panel")

func run_checks() -> void:
	await process_frame
	manager = root.get_node("SaveManager")
	inv = root.get_node("Inventory")
	check(manager.SAVE_PATH == "res://test-save.cfg","isolated save only")
	farm = load("res://main.tscn").instantiate()
	root.add_child(farm)
	current_scene = farm
	await create_timer(0.1).timeout
	mill = manager.stations["feed_mill"]
	hud = farm.get_node("HUD")
	inv.inventory_changed.connect(observe_commit)
	mill.state_changed.connect(func():
		if watch_commit and mill.collecting:
			check(not mill.collect_all(),"reentrant collect is locked"))
	var stage: String = OS.get_cmdline_user_args()[0]
	match stage:
		"feed_cancel":
			await cancellation_checks()
		"feed_cancel_write":
			await prepare()
			enqueue_three()
			check(mill.cancel_job(mill.queue[1]),"cancel waiting cow feed before reload")
			check(mill.cancel_job(mill.queue[0]),"cancel active chicken feed before reload")
			mill.ready_at = Time.get_unix_time_from_system()+60
			check(manager.save_game(),"save one remaining job and refunded ingredients")
		"feed_cancel_read":
			check(items(mill.queue) == ["chicken_feed"] and mill.outputs.is_empty(),"reload never recreates cancelled jobs")
			check(inv.wheat == 19 and inv.corn == 29 and inv.carrot == 20,"refund persists exactly once after reload")
			var pending: Dictionary = mill.queue[0]
			check(mill.cancel_job(pending) and not mill.cancel_job(pending) and inv.wheat == 20 and inv.corn == 30 and inv.carrot == 20,"restored job refunds once")
		"feed_cancel_again":
			check(mill.queue.is_empty() and mill.outputs.is_empty() and inv.wheat == 20 and inv.corn == 30 and inv.carrot == 20,"second reload keeps fully cancelled queue empty without repeated refund")
			check(manager.reset_game(),"cleanup")
		"feed_core":
			await core_checks()
			if "--capture" in OS.get_cmdline_user_args():
				await capture()
				check(manager.reset_game(),"capture cleanup")
		"feed_write", "feed_offline_write":
			await prepare()
			enqueue_three()
			if stage == "feed_write":
				finish_one()
				mill.started_at = Time.get_unix_time_from_system()-3
				mill.ready_at = Time.get_unix_time_from_system()+60
			else:
				mill.started_at = Time.get_unix_time_from_system()-100
				mill.ready_at = Time.get_unix_time_from_system()-90
			check(manager.save_game(),"save current job, waiting slots and output together")
		"feed_read":
			check(items(mill.queue) == ["cow_feed","chicken_feed"] and items(mill.outputs) == ["chicken_feed"],"queue and ready output restored in order")
			check(mill.ready_at == disk().get_value("feed_mill","ready_at") and mill.started_at == disk().get_value("feed_mill","started_at"),"active progress keeps exact Unix timestamps")
			check(mill.collect_all() and inv.chicken_feed == 1 and mill.outputs.is_empty(),"collect restored product once")
		"feed_again":
			check(inv.chicken_feed == 1 and mill.outputs.is_empty() and mill.queue.size() == 2 and not mill.collect_all(),"reload cannot regenerate already collected output")
			check(manager.reset_game(),"cleanup")
		"feed_offline_read":
			check(items(mill.outputs) == MIXED and mill.queue.is_empty() and mill.state == "READY","offline catchup processes three jobs sequentially into bounded output")
			check(inv.chicken_feed == 0 and inv.cow_feed == 0,"offline completion never auto-collects")
			check(mill.collect_all() and inv.chicken_feed == 2 and inv.cow_feed == 1 and not mill.collect_all(),"offline output rewards exactly once")
			check(manager.reset_game(),"cleanup")
		"feed_legacy_write":
			await prepare()
			check(manager.save_game(),"legacy base")
			var data := disk()
			data.erase_section_key("feed_mill","queue")
			data.erase_section_key("feed_mill","outputs")
			data.set_value("feed_mill","state","READY")
			data.set_value("feed_mill","production_type","COW_FEED")
			data.set_value("feed_mill","started_at",Time.get_unix_time_from_system()-20)
			data.set_value("feed_mill","ready_at",Time.get_unix_time_from_system()-5)
			check(data.save(manager.SAVE_PATH) == OK,"legacy single output fixture")
		"feed_legacy_read":
			check(mill.queue.is_empty() and items(mill.outputs) == ["cow_feed"] and inv.cow_feed == 0,"legacy ready batch migrates without losing or granting feed")
			check(mill.collect_all() and inv.cow_feed == 1 and not mill.collect_all(),"legacy batch collects once")
			check(manager.reset_game(),"cleanup")
		"feed_reset_read":
			check(not inv.owns_feed_mill and inv.chicken_feed == 0 and inv.cow_feed == 0 and mill.queue.is_empty() and mill.outputs.is_empty(),"reset remains clean after reload")
	print("PASS: " + stage)
	quit()
