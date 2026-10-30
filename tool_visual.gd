extends Node2D

signal swing_cycle_started
signal swing_stopped

const ROD_TEXTURE: Texture2D = preload("res://assets/characters/fishing_rod.png")
const AXE_TEXTURE: Texture2D = preload("res://assets/characters/farm_axe.png")
const HAMMER_TEXTURE: Texture2D = preload("res://assets/characters/farm_hammer.png")

var tool_id: String = ""
var facing: String = ""
var base_rotation: float = 0.0
var rest_position: Vector2 = Vector2.ZERO
var swinging: bool = false
var swing_tween: Tween
var fishing_pose: bool = false
var fishing_tween: Tween
var rod_sprite: Sprite2D
var axe_sprite: Sprite2D
var hammer_sprite: Sprite2D
var body_cycle_count: int = 0
var body_pose_active: bool = false


func _ready() -> void:
	rod_sprite = Sprite2D.new()
	rod_sprite.name = "RodSprite"
	rod_sprite.texture = ROD_TEXTURE
	rod_sprite.region_enabled = true
	rod_sprite.region_rect = Rect2(550, 0, 300, 1254)
	rod_sprite.position = Vector2(7, -22.3)
	rod_sprite.scale = Vector2.ONE * 0.037
	rod_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rod_sprite.visible = false
	add_child(rod_sprite)
	axe_sprite = _create_tool_sprite(
		"AxeSprite", AXE_TEXTURE, Rect2(80, 30, 800, 1470),
		Vector2(-3.3, -15.4), 0.022
	)
	hammer_sprite = _create_tool_sprite(
		"HammerSprite", HAMMER_TEXTURE, Rect2(120, 30, 780, 1470),
		Vector2(-0.2, -15.4), 0.022
	)
	add_child(axe_sprite)
	add_child(hammer_sprite)


func _create_tool_sprite(
	sprite_name: String,
	texture: Texture2D,
	region: Rect2,
	sprite_position: Vector2,
	sprite_scale: float
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.position = sprite_position
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = false
	return sprite


func set_equipped(item_id: String, direction: String) -> void:
	var next_tool := item_id if item_id in ["axe", "hammer", "fishing_rod"] else ""
	if next_tool != tool_id:
		stop_swing()
		end_fishing_action()
	tool_id = next_tool
	set_facing(direction)
	visible = not tool_id.is_empty()
	if is_instance_valid(rod_sprite):
		rod_sprite.visible = tool_id == "fishing_rod"
	if is_instance_valid(axe_sprite):
		axe_sprite.visible = tool_id == "axe"
	if is_instance_valid(hammer_sprite):
		hammer_sprite.visible = tool_id == "hammer"
	queue_redraw()


func set_facing(direction: String) -> void:
	if direction not in ["up", "down", "left", "right"]:
		return
	if facing == direction:
		return
	facing = direction
	match facing:
		"up":
			position = Vector2(-5, -28)
			base_rotation = 0.0
			z_index = -1
		"down":
			position = Vector2(6, -28)
			base_rotation = PI * 0.72
			z_index = 1
		"left":
			position = Vector2(-5, -27)
			base_rotation = -PI * 0.5
			z_index = 1
		"right":
			position = Vector2(5, -27)
			base_rotation = PI * 0.5
			z_index = 1
	if not swinging:
		rotation = base_rotation
	rest_position = position
	queue_redraw()


func play_swing(target_world_position: Vector2, body_cycle_duration: float = 0.0) -> void:
	if tool_id not in ["axe", "hammer"] or swinging:
		return
	end_fishing_action()
	swinging = true
	var direction := (target_world_position - global_position).normalized()
	var aim_rotation := direction.angle() + PI * 0.5
	var windup := base_rotation - signf(wrapf(aim_rotation - base_rotation, -PI, PI)) * 0.42
	swing_tween = create_tween().set_loops()
	body_cycle_count = 0
	body_pose_active = body_cycle_duration > 0.0
	if body_pose_active:
		swing_tween.tween_callback(_begin_body_cycle)
		swing_tween.tween_interval(body_cycle_duration)
		var visual := get_parent().get_node_or_null("AnimatedSprite2D")
		if visual != null and visual.has_method("_apply_tool_action_pose"):
			visual._apply_tool_action_pose()
		return
	# Other characters retain the original tool tween and timing.
	swing_tween.tween_property(self, "position", rest_position - direction * 2.5, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.parallel().tween_property(self, "rotation", windup, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.parallel().tween_property(self, "scale", Vector2(1.04, 0.96), 0.16)
	swing_tween.tween_property(self, "position", rest_position + direction * 5.0, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	swing_tween.parallel().tween_property(self, "rotation", aim_rotation, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	swing_tween.parallel().tween_property(self, "scale", Vector2(0.98, 1.04), 0.10)
	swing_tween.tween_property(self, "position", rest_position, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.parallel().tween_property(self, "rotation", base_rotation, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)


func sync_body_pose(grip_position: Vector2, angle: float) -> void:
	if body_pose_active and swinging:
		position = grip_position
		rotation = angle
		scale = Vector2.ONE


func _begin_body_cycle() -> void:
	body_cycle_count += 1
	if body_cycle_count > 1:
		swing_cycle_started.emit()


func stop_swing() -> void:
	if swing_tween != null and swing_tween.is_valid():
		swing_tween.kill()
	swing_tween = null
	swinging = false
	rotation = base_rotation
	position = rest_position
	scale = Vector2.ONE
	body_cycle_count = 0
	body_pose_active = false
	swing_stopped.emit()


func _finish_swing() -> void:
	swinging = false
	rotation = base_rotation
	position = rest_position
	scale = Vector2.ONE


func begin_fishing_action() -> void:
	if tool_id != "fishing_rod" or fishing_pose:
		return
	fishing_pose = true
	if fishing_tween != null and fishing_tween.is_valid():
		fishing_tween.kill()
	fishing_tween = create_tween().set_loops()
	fishing_tween.tween_property(self, "rotation", base_rotation - 0.075, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fishing_tween.parallel().tween_property(self, "position", rest_position + Vector2(0, -1.5), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fishing_tween.tween_property(self, "rotation", base_rotation + 0.035, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fishing_tween.parallel().tween_property(self, "position", rest_position + Vector2(0, 0.8), 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func end_fishing_action() -> void:
	if fishing_tween != null and fishing_tween.is_valid():
		fishing_tween.kill()
	fishing_tween = null
	fishing_pose = false
	if not swinging:
		rotation = base_rotation
		position = rest_position


func tip_world_position() -> Vector2:
	return to_global(Vector2(5, -42 if tool_id == "fishing_rod" else -25))


func _draw() -> void:
	pass
