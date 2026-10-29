extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if value:
		return
	push_error("TEST FAILED: " + message)
	quit(1)


func _clear_runtime_queues(manager: Node) -> void:
	manager.bakery_queue.clear()
	manager.dairy_queue.clear()
	manager.spinning_machine_queue.clear()


func _run() -> void:
	var inventory: Node = root.get_node("Inventory")
	var manager: Node = root.get_node("SaveManager")
	inventory.player_level = 20
	inventory.silo_capacity = 999
	inventory.barn_capacity = 999
	_clear_runtime_queues(manager)

	var bakery: Node = load("res://bakery.tscn").instantiate()
	root.add_child(bakery)
	inventory.owns_bakery = true
	inventory.wheat = 6
	for ignored in range(3):
		_check(bakery.enqueue("bread"), "Bakery enqueues a job")
	var bakery_finish: float = float(manager.bakery_queue[0]["ready_at"])
	_check(bakery.cancel_job_at(1), "Bakery cancels a queued job")
	_check(inventory.wheat == 2 and manager.bakery_queue.size() == 2, "Bakery refunds exactly one recipe")
	_check(float(manager.bakery_queue[1]["started_at"]) >= bakery_finish, "Bakery reflows the remaining queue")

	var dairy: Node = load("res://dairy.tscn").instantiate()
	root.add_child(dairy)
	inventory.owns_dairy = true
	inventory.milk = 9
	for item in ["cream", "butter", "cheese"]:
		_check(dairy.enqueue(item), "Dairy enqueues a job")
	var dairy_finish: float = float(manager.dairy_queue[0]["ready_at"])
	_check(dairy.cancel_job_at(1), "Dairy cancels a queued job")
	_check(inventory.milk == 3 and manager.dairy_queue.size() == 2, "Dairy refunds exactly one recipe")
	_check(float(manager.dairy_queue[1]["started_at"]) >= dairy_finish, "Dairy reflows the remaining queue")

	var spinning: Node = load("res://spinning_machine.tscn").instantiate()
	root.add_child(spinning)
	inventory.owns_spinning_machine = true
	inventory.cotton = 9
	for ignored in range(3):
		_check(spinning.enqueue("cotton_thread"), "Spinning machine enqueues a job")
	var spinning_finish: float = float(manager.spinning_machine_queue[0]["ready_at"])
	_check(spinning.cancel_job_at(1), "Spinning machine cancels a queued job")
	_check(inventory.cotton == 3 and manager.spinning_machine_queue.size() == 2, "Spinning machine refunds exactly one recipe")
	_check(float(manager.spinning_machine_queue[1]["started_at"]) >= spinning_finish, "Spinning machine reflows the remaining queue")

	print("PASS: production_cancel")
	quit()
