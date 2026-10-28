extends Node2D

var base_scale: Vector2 = Vector2.ONE
var state_name: String = "IDLE"
var phase: float = 0.0
var texture_available: bool = false
var name_time: float = 0.0
var heart_time: float = 0.0
var state_tween: Tween
var visibility_tween: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel
@onready var zzz_label: Label = $ZzzLabel
@onready var thought_label: Label = $ThoughtLabel

func _ready() -> void:
	name_label.theme = preload("res://assets/ui/ui_theme.tres")
	zzz_label.theme = name_label.theme
	thought_label.theme = name_label.theme
	name_label.hide()
	zzz_label.hide()
	thought_label.hide()

func configure(variant_id: String, display_name: String) -> void:
	# `_ready()` starts the idle pose before a saved profile has supplied its
	# texture. Cancel that pre-configured tween: otherwise it can finish later
	# and restore the sprite to scale 1, which is enormous for high-resolution
	# dog artwork.
	if is_instance_valid(state_tween):
		state_tween.kill()
		state_tween = null
	var texture := preload("res://dog_data.gd").texture_for_variant(variant_id)
	texture_available = texture != null
	sprite.texture = texture
	if texture != null:
		var size := texture.get_size()
		var scale_factor := 64.0 / maxf(size.y, 1.0)
		sprite.scale = Vector2.ONE * scale_factor
		# Anchor texture feet on the parent origin without stretching it.
		sprite.position.y = -size.y * scale_factor * 0.5
		base_scale = sprite.scale
	name_label.text = display_name
	# Reapply the current pose from the newly calculated, fixed display scale.
	set_state(state_name)
	queue_redraw()

func set_state(next_state: String) -> void:
	state_name = next_state
	thought_label.visible = next_state == "WAIT_FOOD"
	thought_label.text = "…" if thought_label.visible else ""
	zzz_label.visible = next_state == "SLEEP"
	var target_scale := base_scale
	var target_position := Vector2(0, sprite.position.y)
	if next_state in ["LIE_DOWN", "SLEEP"]:
		target_scale = base_scale * Vector2(1.05, 0.81)
		target_position.y += 5.0
	if is_instance_valid(state_tween):
		state_tween.kill()
	state_tween = create_tween()
	state_tween.set_parallel(true)
	state_tween.tween_property(sprite, "scale", target_scale, 0.22).set_trans(Tween.TRANS_SINE)
	state_tween.tween_property(sprite, "position", target_position, 0.22).set_trans(Tween.TRANS_SINE)

func set_facing(right: bool) -> void:
	sprite.flip_h = not right

func show_name(seconds: float = 2.5) -> void:
	name_time = seconds
	name_label.show()

func happy() -> void:
	show_name(2.0)
	heart_time = 0.9
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y - 4.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", sprite.position.y, 0.18).set_trans(Tween.TRANS_BOUNCE)

func set_inside(inside: bool) -> void:
	if is_instance_valid(visibility_tween):
		visibility_tween.kill()
	if not inside:
		show()
	visibility_tween = create_tween()
	visibility_tween.tween_property(self, "modulate:a", 0.0 if inside else 1.0, 0.18)
	if inside:
		visibility_tween.tween_callback(hide)

func _process(delta: float) -> void:
	phase += delta
	name_time = maxf(0.0, name_time - delta)
	if name_time <= 0.0:
		name_label.hide()
	heart_time = maxf(0.0, heart_time - delta)
	if state_name == "SLEEP":
		zzz_label.text = "Z" if int(phase * 1.5) % 3 == 0 else "Zz" if int(phase * 1.5) % 3 == 1 else "Zzz"
		zzz_label.position = Vector2(7, -52 - fmod(phase * 7.0, 11.0))
		zzz_label.modulate.a = 0.55 + sin(phase * 2.0) * 0.25
	elif state_name == "WANDER" or state_name == "GREET_PLAYER" or state_name == "RETURN_HOME":
		sprite.rotation = sin(phase * 10.0) * 0.026
		sprite.position.y = -sprite.texture.get_size().y * base_scale.y * 0.5 + sin(phase * 10.0) * 1.2 if sprite.texture != null else 0.0
	else:
		sprite.rotation = 0.0
		if state_name == "IDLE":
			sprite.position.y = -sprite.texture.get_size().y * base_scale.y * 0.5 + sin(phase * 2.0) * 0.7 if sprite.texture != null else 0.0
		elif state_name == "EATING":
			sprite.position.y = -sprite.texture.get_size().y * base_scale.y * 0.5 + absf(sin(phase * 9.0)) * 1.4 if sprite.texture != null else 0.0
	queue_redraw()

func _draw() -> void:
	# Grounded fallback and shared shadow; the fallback dog is deliberately
	# simple but never uses a farmer/character texture when an asset is missing.
	var shadow_size := Vector2(24, 6) if state_name not in ["LIE_DOWN", "SLEEP"] else Vector2(30, 7)
	draw_set_transform(Vector2(0, -2), 0.0, shadow_size)
	draw_circle(Vector2.ZERO, 1.0, Color(0.08, 0.13, 0.08, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not texture_available:
		draw_circle(Vector2(0, -20), 15.0, Color("c9823d"))
		draw_circle(Vector2(-9, -32), 6.0, Color("9f5c2d"))
		draw_circle(Vector2(9, -32), 6.0, Color("9f5c2d"))
	if heart_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-4, -54), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e86d6d", heart_time / 0.9))
