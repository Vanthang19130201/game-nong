extends Node2D

var player_near: bool = false
@onready var blocker: CollisionShape2D = $Blocker/CollisionShape2D
@onready var sign: Label = $Sign


func _ready() -> void:
	add_to_group("farm_interactables")
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)
	Inventory.inventory_changed.connect(_update_unlock)
	_update_unlock()


func _update_unlock() -> void:
	var unlocked: bool = Inventory.is_zone_unlocked("fishing")
	blocker.set_deferred("disabled", unlocked)
	sign.text = "Fishing Area - Unlocked" if unlocked else "Fishing Area\nUnlocks at Level 10\n[E]"
	$Gate.visible = not unlocked
	if not unlocked:
		var player = get_tree().get_first_node_in_group("farm_player")
		if player != null and player.global_position.x >= Inventory.FarmData.RIVER_LEFT:
			# Resetting inside Fishing Area must not trap the player behind the gate.
			player.global_position = Inventory.FarmData.SAFE_MAIN_SIDE
			player.velocity = Vector2.ZERO
			player.get_node("Camera2D").reset_smoothing()


func can_interact() -> bool:
	return player_near


func get_interaction_position() -> Vector2:
	return $InteractionArea.global_position


func interact(_player: Node2D = null) -> void:
	Inventory.fail("Fishing Area - Unlocked" if Inventory.is_zone_unlocked("fishing") else "Fishing unlocks at Level 10.")


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false
