extends Area2D

var player_near: bool = false


func _ready() -> void:
	add_to_group("farm_interactables")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func can_interact() -> bool:
	return player_near


func interact(_player: Node2D = null) -> void:
	var hud = get_tree().get_first_node_in_group("farm_hud")
	if can_interact() and hud != null:
		hud.open_orders()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false