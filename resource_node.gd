extends Area2D

const Progression = preload("res://progression_data.gd")
const RockData = preload("res://rock_data.gd")
@export var resource_id: String = ""
@export var zone_id: String = "main"
var zone_active: bool = false
@export_enum("wood", "stone") var resource_type: String = "wood"
@export_enum("normal_rock", "large_rock", "dark_rock") var rock_type: String = "normal_rock"

var state: String = "AVAILABLE"
var respawn_at: float = 0.0
var player_near: bool = false
var gather_duration: float = 0.0
var player: Node2D
var rng := RandomNumberGenerator.new()

@onready var visual: ColorRect = $Visual
@onready var label: Label = $Label
@onready var progress: ProgressBar = $ProgressBar
@onready var harvest_timer: Timer = $HarvestTimer
@onready var respawn_timer: Timer = $RespawnTimer


func _ready() -> void:
	add_to_group("farm_interactables")
	rng.randomize()
	player = get_tree().get_first_node_in_group("farm_player")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	harvest_timer.timeout.connect(_finish_harvest)
	respawn_timer.timeout.connect(_respawn)
	Inventory.inventory_changed.connect(_update_zone)
	if not SaveManager.register_resource(self):
		remove_from_group("farm_interactables")
		hide()
		queue_free()


func get_save_data() -> Dictionary:
	# Partial gathering is cancelled on load; no reward has been granted yet.
	var data: Dictionary = {"state": "AVAILABLE" if state == "GATHERING" else state, "respawn_at": respawn_at, "zone_id": zone_id}
	if resource_type == "stone":
		data["rock_type"] = rock_type
	return data


func restore_save_data(data: Dictionary) -> void:
	cancel_harvest()
	respawn_timer.stop()
	respawn_at = data.get("respawn_at", 0.0)
	state = "DEPLETED" if respawn_at > 0.0 else "AVAILABLE"
	if resource_type == "stone":
		var saved_type = data.get("rock_type","")
		if RockData.TYPES.has(saved_type):
			rock_type = saved_type
		else:
			_randomize_rock_type()
			if not SaveManager.resetting:
				SaveManager.save_game.call_deferred()
	# Scene zone_id is authoritative; legacy saves defaulted all nodes to main.
	_update_zone(true)


func _update_zone(force: bool = false) -> void:
	var unlocked: bool = Inventory.is_zone_unlocked(zone_id) and SaveManager.LandData.resource_access(global_position, SaveManager.unlocked_land_zones)
	var was_active: bool = zone_active
	zone_active = unlocked
	visible = Inventory.is_zone_unlocked(zone_id)
	set_process(unlocked)
	set_deferred("monitoring", unlocked)
	$CollisionShape2D.set_deferred("disabled", not unlocked)
	if not unlocked:
		player_near = false
		cancel_harvest()
		respawn_timer.stop()
		return
	if force or not was_active:
		# Only initialize respawn after entering an unlocked zone.
		var remaining: float = respawn_at - Time.get_unix_time_from_system()
		if remaining > 0.0:
			state = "DEPLETED"
			respawn_timer.start(remaining)
		else:
			if resource_type == "stone" and respawn_at > 0.0:
				_randomize_rock_type()
				if not SaveManager.resetting:
					SaveManager.save_game.call_deferred()
			respawn_at = 0.0
			state = "AVAILABLE"
			respawn_timer.stop()
		_update_display()
		if not force:
			SaveManager.save_game.call_deferred()

func can_interact() -> bool:
	return zone_active and player_near and state == "AVAILABLE"


func interact(_player: Node2D = null) -> void:
	harvest()


func tool_id() -> String:
	return "axe" if resource_type == "wood" else "hammer"


func harvest() -> bool:
	if not zone_active or not player_near or not is_instance_valid(player):
		return false
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if hud != null and hud.blocks_world_input():
		return false
	if not Inventory.can_use_tool(tool_id()):
		return Inventory.fail(tr("ERROR_NEED_TOOLS"))
	if state != "AVAILABLE" or is_instance_valid(player.active_resource):
		return false
	state = "GATHERING"
	player.active_resource = self
	gather_duration = Inventory.tool_duration(tool_id())
	harvest_timer.start(gather_duration)
	progress.max_value = gather_duration
	progress.value = 0.0
	_update_display()
	return true


func _process(_delta: float) -> void:
	if not zone_active or state != "GATHERING":
		return
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if not player_near or (hud != null and hud.blocks_world_input()):
		cancel_harvest()
		return
	progress.value = gather_duration - harvest_timer.time_left


func cancel_harvest() -> void:
	harvest_timer.stop()
	if is_instance_valid(player) and player.active_resource == self:
		player.active_resource = null
	if state == "GATHERING":
		state = "AVAILABLE"
	_update_display()


func _finish_harvest() -> void:
	if not zone_active or state != "GATHERING":
		return
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if not player_near or not Inventory.can_use_tool(tool_id()) or (hud != null and hud.blocks_world_input()):
		cancel_harvest()
		return
	var amount: int = rng.randi_range(2, 3) if resource_type == "wood" else 2
	if resource_type == "stone":
		var rock: Dictionary = RockData.TYPES[rock_type]
		amount = rng.randi_range(rock["min_stone"],rock["max_stone"])
	# Snapshot cooldown + reward together. Repeated E cannot duplicate the reward.
	respawn_at = Time.get_unix_time_from_system() + Progression.RESOURCE_RESPAWN[resource_type]
	state = "DEPLETED"
	player.active_resource = null
	respawn_timer.start(Progression.RESOURCE_RESPAWN[resource_type])
	Inventory.set(resource_type, Inventory.get(resource_type) + amount)
	_update_display()
	Inventory.inventory_changed.emit()


func _respawn() -> void:
	if not zone_active:
		respawn_timer.stop()
		return
	var remaining: float = respawn_at - Time.get_unix_time_from_system()
	if remaining > 0.0:
		respawn_timer.start(remaining)
		return
	if resource_type == "stone" and respawn_at > 0.0:
		_randomize_rock_type()
	respawn_at = 0.0
	state = "AVAILABLE"
	_update_display()
	SaveManager.save_game()


func _randomize_rock_type() -> void:
	rock_type = RockData.TYPES.keys()[rng.randi_range(0,RockData.TYPES.size()-1)]


func _update_display() -> void:
	$Visuals.refresh()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and zone_active:
		player = body
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false
		cancel_harvest()
