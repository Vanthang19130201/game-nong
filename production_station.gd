extends Area2D

signal state_changed

const Progression = preload("res://progression_data.gd")
@export_enum("feed_mill", "chicken_coop", "cow_shed", "pig_pen", "sheep_barn") var station_id: String = "feed_mill"
@export var is_preview: bool = false

var state: String = "IDLE"
var production_type: String = ""
var started_at: float = 0.0
var ready_at: float = 0.0
var player_near: bool = false
var chicken_count: int:
	get: return Inventory.chicken_count
var cow_count: int:
	get: return Inventory.cow_count

@onready var status_label: Label = $StatusLabel
@onready var production_timer: Timer = $ProductionTimer


func _ready() -> void:
	if is_preview:
		return
	add_to_group("farm_interactables")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	production_timer.timeout.connect(_finish_production)
	Inventory.inventory_changed.connect(_update_ownership)
	if not SaveManager.register_station(self):
		remove_from_group("farm_interactables")
		hide()
		queue_free()
		return
	_update_ownership()


func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"state": state, "production_type": production_type,
		"started_at": started_at, "ready_at": ready_at
	}
	if station_id == "chicken_coop":
		data["chicken_count"] = chicken_count
	elif station_id == "cow_shed":
		data["cow_count"] = cow_count
	return data


func restore_save_data(data: Dictionary) -> void:
	production_timer.stop()
	state = data["state"]
	production_type = data["production_type"]
	started_at = data["started_at"]
	ready_at = data["ready_at"]
	if state == "PRODUCING":
		var remaining: float = ready_at - Time.get_unix_time_from_system()
		if remaining > 0.0:
			production_timer.start(remaining)
		else:
			state = "READY"
			SaveManager.save_game.call_deferred()
	_update_display()


func can_produce(recipe: String = "chicken_feed") -> bool:
	if not Inventory.owns_building(station_id):
		return false
	if station_id == "feed_mill":
		if state != "IDLE" or not Progression.RECIPES.has(recipe):
			return false
		var info: Dictionary = Progression.RECIPES[recipe]
		if Inventory.player_level < info["level"]:
			return false
		for item in info["requirements"]:
			if Inventory.get(item) < info["requirements"][item]:
				return false
		return true
	var product: Dictionary = Progression.PRODUCTS[station_id]
	return state == "HUNGRY" and Inventory.player_level >= product["level"] and Inventory.get(product["animal"] + "_count") > 0 and Inventory.get(product["feed"]) > 0


func produce(recipe: String = "chicken_feed") -> bool:
	if not can_produce(recipe):
		return Inventory.fail(tr("ERROR_STATION_PRODUCE"))
	var duration: float
	if station_id == "feed_mill":
		var info: Dictionary = Progression.RECIPES[recipe]
		duration = info["time"]
		production_type = recipe.to_upper()
		for item in info["requirements"]:
			Inventory.set(item, Inventory.get(item) - info["requirements"][item])
		AudioManager.play_sfx("production_start", global_position)
	else:
		var product: Dictionary = Progression.PRODUCTS[station_id]
		duration = product["time"]
		production_type = product["item"].to_upper()
		Inventory.set(product["feed"], Inventory.get(product["feed"]) - 1)
		AudioManager.play_sfx("animal_feed", global_position)
	started_at = Time.get_unix_time_from_system()
	ready_at = started_at + duration
	state = "PRODUCING"
	production_timer.start(duration)
	_update_display()
	# Save only once all inputs and production state are updated.
	Inventory.inventory_changed.emit()
	return true


func output_data() -> Dictionary:
	if station_id == "feed_mill":
		return {"item": production_type.to_lower(), "amount": 1, "exp": 0}
	var product: Dictionary = Progression.PRODUCTS[station_id]
	var count: int = Inventory.get(product["animal"] + "_count")
	return {"item": product["item"], "amount": count, "exp": product["exp"] * count}


func collect() -> bool:
	if state != "READY" or not Inventory.owns_building(station_id):
		return false
	var output: Dictionary = output_data()
	if not Inventory.can_add_item(output["item"], output["amount"]):
		return Inventory.fail(tr("ERROR_BARN_BATCH"))
	if not Inventory.can_add_exp(output["exp"]):
		return false
	production_timer.stop()
	state = "IDLE" if station_id == "feed_mill" else "HUNGRY"
	production_type = ""
	started_at = 0.0
	ready_at = 0.0
	Inventory.set(output["item"], Inventory.get(output["item"]) + output["amount"])
	Inventory.add_exp(output["exp"], false)
	var collect_sound := "product_collect"
	if station_id == "chicken_coop": collect_sound = "collect_egg"
	elif station_id == "cow_shed": collect_sound = "collect_milk"
	elif station_id == "sheep_barn": collect_sound = "collect_wool"
	elif station_id == "pig_pen": collect_sound = "item_collect"
	AudioManager.play_sfx(collect_sound, global_position)
	_update_display()
	Inventory.inventory_changed.emit()
	return true


func _finish_production() -> void:
	if state != "PRODUCING":
		return
	var remaining: float = ready_at - Time.get_unix_time_from_system()
	if remaining > 0.0:
		production_timer.start(remaining)
		return
	state = "READY"
	AudioManager.play_sfx("production_ready", global_position)
	_update_display()
	SaveManager.save_game()


func _update_ownership() -> void:
	var owned: bool = Inventory.owns_building(station_id)
	visible = owned
	set_deferred("monitoring", owned)
	$CollisionShape2D.set_deferred("disabled", not owned)
	if not owned:
		player_near = false
		var hud = get_tree().get_first_node_in_group("farm_hud")
		if hud != null and hud.active_station == self:
			hud.close_station()
	_update_display()


func _update_display() -> void:
	$Visuals.refresh()
	state_changed.emit()


func can_interact() -> bool:
	# Query current overlaps too: buying while already standing here needs no re-entry.
	player_near = false
	if not Inventory.owns_building(station_id) or not monitoring:
		return false
	for body in get_overlapping_bodies():
		if body.is_in_group("farm_player"):
			player_near = true
	return player_near and Inventory.owns_building(station_id)


func interact(_player: Node2D = null) -> void:
	if not can_interact():
		return
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud == null or hud.blocks_world_input():
		return
	if station_id == "feed_mill":
		hud.open_station(self)
		return
	var product: Dictionary = Progression.PRODUCTS[station_id]
	match state:
		"HUNGRY":
			if Inventory.get(product["animal"] + "_count") <= 0:
				hud.show_floating_feedback(tr("ERROR_STATION_PRODUCE"))
			elif Inventory.get(product["feed"]) <= 0:
				var message_key: String = "ANIMAL_NEED_CHICKEN_FEED" if station_id == "chicken_coop" else "ANIMAL_NEED_COW_FEED" if station_id == "cow_shed" else "ANIMAL_NEED_FEED_GENERIC"
				hud.show_floating_feedback(tr(message_key) % Localization.display_name(product["feed"]) if station_id in ["pig_pen", "sheep_barn"] else tr(message_key))
			else:
				produce()
		"READY":
			var output := output_data()
			if not Inventory.can_add_item(output["item"], output["amount"]):
				hud.show_floating_feedback(tr("FEED_STORAGE_FULL"))
			else:
				collect()
		"PRODUCING":
			hud.show_floating_feedback(tr("WORLD_PRODUCTION_TIMER") % ceili(maxf(0.0, ready_at - Time.get_unix_time_from_system())))

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and Inventory.owns_building(station_id):
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false
		var hud = get_tree().get_first_node_in_group("farm_hud")
		if hud != null and hud.active_station == self:
			hud.close_station()
