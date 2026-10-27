extends Node2D

const ROD_TEXTURE: Texture2D = preload("res://assets/characters/fishing_rod.png")
const AXE_TEXTURE: Texture2D = preload("res://assets/characters/farm_axe.png")
const HAMMER_TEXTURE: Texture2D = preload("res://assets/characters/farm_hammer.png")

var tool_id: String = ""
var facing: String = ""
var base_rotation: float = 0.0
var swinging: bool = false
var swing_tween: Tween
var rod_sprite: Sprite2D
var axe_sprite: Sprite2D
var hammer_sprite: Sprite2D


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
	tool_id = item_id if item_id in ["axe", "hammer", "fishing_rod"] else ""
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
	queue_redraw()


func play_swing(target_world_position: Vector2) -> void:
	if tool_id not in ["axe", "hammer"] or swinging:
		return
	swinging = true
	var direction := (target_world_position - global_position).normalized()
	var aim_rotation := direction.angle() + PI * 0.5
	var windup := base_rotation - signf(wrapf(aim_rotation - base_rotation, -PI, PI)) * 0.42
	swing_tween = create_tween().set_loops()
	swing_tween.tween_property(self, "rotation", windup, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing_tween.tween_property(self, "rotation", aim_rotation, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	swing_tween.tween_property(self, "rotation", base_rotation, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func stop_swing() -> void:
	if swing_tween != null and swing_tween.is_valid():
		swing_tween.kill()
	swing_tween = null
	swinging = false
	rotation = base_rotation


func _finish_swing() -> void:
	swinging = false
	rotation = base_rotation


func tip_world_position() -> Vector2:
	return to_global(Vector2(5, -42 if tool_id == "fishing_rod" else -25))


func _draw() -> void:
	pass
