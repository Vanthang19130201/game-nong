extends Node2D

# Presentation only. The merchant continues to be spawned at the same event
# position by farm.gd; its shop, interaction radius and save data are untouched.
# This supplied sheet is exactly three columns by two rows (six greeting poses).
const MERCHANT_SHEET: Texture2D = preload("res://assets/characters/merchant/merchant_greet.png")
const FRAME_COLUMNS: int = 3
const FRAME_ROWS: int = 2
const FRAME_WIDTH: float = 1448.0 / FRAME_COLUMNS
const FRAME_HEIGHT: float = 1086.0 / FRAME_ROWS
const GREET_ANIMATION: StringName = &"merchant_greet"

var prompt: Label
var merchant_sprite: AnimatedSprite2D
var merchant_was_active := false


func _ready() -> void:
	add_to_group("farm_interactables")
	add_to_group("placement_obstacles")
	FarmEventManager.merchant_changed.connect(_refresh)
	_create_merchant_sprite()
	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.text = tr("MERCHANT_INTERACT")
	prompt.theme = preload("res://assets/ui/ui_theme.tres")
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-72, -76)
	prompt.custom_minimum_size = Vector2(144, 20)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.z_index = 2
	add_child(prompt)
	_refresh()


func _create_merchant_sprite() -> void:
	merchant_sprite = AnimatedSprite2D.new()
	merchant_sprite.name = "MerchantSprite"
	merchant_sprite.sprite_frames = _create_sprite_frames()
	merchant_sprite.animation = GREET_ANIMATION
	merchant_sprite.frame = 0
	merchant_sprite.pause()
	merchant_sprite.animation_finished.connect(_on_greet_finished)
	merchant_sprite.position = Vector2(0, -31)
	merchant_sprite.scale = Vector2.ONE * 0.17
	merchant_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	merchant_sprite.z_index = 1
	add_child(merchant_sprite)


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	frames.add_animation(GREET_ANIMATION)
	frames.set_animation_loop(GREET_ANIMATION, false)
	frames.set_animation_speed(GREET_ANIMATION, 6.0)
	for row in FRAME_ROWS:
		for column in FRAME_COLUMNS:
			frames.add_frame(GREET_ANIMATION, _frame_texture(column, row))
	return frames


func _frame_texture(column: int, row: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = MERCHANT_SHEET
	texture.region = Rect2(float(column) * FRAME_WIDTH, float(row) * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)
	return texture


func _process(_delta: float) -> void:
	var should_be_visible: bool = FarmEventManager.merchant_active and FarmEventManager.merchant_position != Vector2.ZERO
	visible = should_be_visible
	if not visible:
		prompt.hide()
		merchant_was_active = false
		return
	global_position = FarmEventManager.merchant_position
	if not merchant_was_active:
		_play_greeting()
	merchant_was_active = true
	prompt.visible = can_interact()


func can_interact() -> bool:
	if not is_visible_in_tree() or not FarmEventManager.merchant_active:
		return false
	var player := get_tree().get_first_node_in_group("farm_player") as Node2D
	if not is_instance_valid(player) or player.global_position.distance_to(global_position) > 86.0:
		return false
	var hud := get_tree().get_first_node_in_group("farm_hud")
	return hud == null or not hud.blocks_world_input()


func get_interaction_position() -> Vector2:
	return global_position


func interact(_player: Node2D = null) -> void:
	if not can_interact():
		return
	var hud := get_tree().get_first_node_in_group("farm_hud")
	if is_instance_valid(hud):
		hud.open_wandering_merchant(self)


func _refresh() -> void:
	if is_instance_valid(prompt):
		prompt.visible = false
	var should_be_visible: bool = FarmEventManager.merchant_active and FarmEventManager.merchant_position != Vector2.ZERO
	visible = should_be_visible
	if should_be_visible:
		global_position = FarmEventManager.merchant_position
		if not merchant_was_active:
			_play_greeting()
	else:
		merchant_was_active = false


func _play_greeting() -> void:
	if not is_instance_valid(merchant_sprite):
		return
	merchant_sprite.frame = 0
	merchant_sprite.play(GREET_ANIMATION)


func _on_greet_finished() -> void:
	if not is_instance_valid(merchant_sprite) or merchant_sprite.animation != GREET_ANIMATION:
		return
	# The sixth supplied pose is the quiet standing pose. Do not restart it.
	merchant_sprite.frame = merchant_sprite.sprite_frames.get_frame_count(GREET_ANIMATION) - 1
	merchant_sprite.pause()
