extends Node2D

const DogData = preload("res://dog_data.gd")

var base_scale: Vector2 = Vector2.ONE
var base_sprite_position: Vector2 = Vector2.ZERO
var state_name: String = "IDLE"
var variant_id: String = "shiba"
var phase: float = 0.0
var texture_available: bool = false
var name_time: float = 0.0
var heart_time: float = 0.0
var reaction_time: float = 0.0
var reaction_duration: float = 0.0
var state_tween: Tween
var visibility_tween: Tween
var idle_variant_until: float = 0.0
var next_idle_variation: float = 0.0
var rng := RandomNumberGenerator.new()

@onready var motion_root: Node2D = $MotionRoot
@onready var sprite: AnimatedSprite2D = $MotionRoot/Sprite
@onready var name_label: Label = $NameLabel
@onready var zzz_label: Label = $ZzzLabel
@onready var thought_label: Label = $ThoughtLabel
@onready var interact_label: Label = $InteractLabel


func _ready() -> void:
	rng.randomize()
	name_label.theme = preload("res://assets/ui/ui_theme.tres")
	zzz_label.theme = name_label.theme
	thought_label.theme = name_label.theme
	name_label.hide()
	zzz_label.hide()
	thought_label.hide()
	interact_label.hide()
	next_idle_variation = rng.randf_range(2.5, 6.0)
	sprite.frame_changed.connect(_on_sprite_frame_changed)


func configure(next_variant_id: String, display_name: String) -> void:
	# The gameplay node configures itself just after _ready. Never let a tween
	# begun before the profile arrived restore a high-resolution source image to
	# scale 1 (the old cause of the giant Black Tan).
	if is_instance_valid(state_tween):
		state_tween.kill()
		state_tween = null
	variant_id = next_variant_id
	motion_root.position = Vector2.ZERO
	motion_root.rotation = 0.0
	var frames := DogData.visual_frames_for_variant(variant_id)
	texture_available = frames != null
	sprite.sprite_frames = frames
	if frames != null:
		var pose_sheet: Texture2D = DogData.visual_sheet_for_variant(variant_id)
		if pose_sheet != null:
			# Normal path: each animation uses AtlasTexture frames cut from its
			# own pose board. Scale and baseline live in DogData per breed.
			sprite.scale = Vector2.ONE * DogData.visual_scale_for_variant(variant_id)
			base_sprite_position = Vector2(0.0, DogData.visual_ground_offset_for_variant(variant_id, pose_sheet))
		else:
			# Emergency fallback only; never reached while the valid pose sheet is
			# present. It keeps a corrupted install playable without giant artwork.
			var source_texture: Texture2D = DogData.texture_for_variant(variant_id)
			var source_height: float = float(source_texture.get_height()) if source_texture != null else 1200.0
			var fallback_scale := 56.0 / source_height
			sprite.scale = Vector2.ONE * fallback_scale
			base_sprite_position = Vector2(0.0, -source_height * fallback_scale * 0.47)
		base_scale = sprite.scale
		sprite.position = base_sprite_position
	name_label.text = display_name
	set_state(state_name)
	_apply_frame_anchor()
	queue_redraw()


func set_state(next_state: String) -> void:
	state_name = next_state
	idle_variant_until = 0.0
	_refresh_hungry_badge()
	zzz_label.visible = next_state == "SLEEP"
	if not zzz_label.visible:
		zzz_label.text = ""
	_play_state_animation()
	if texture_available:
		# Base placement is configured once. Frame alignment is exclusively kept
		# in Sprite2D.offset, while MotionRoot owns intentional bob/tilt.
		sprite.scale = base_scale
		sprite.position = base_sprite_position
		_apply_frame_anchor()


func set_facing(right: bool) -> void:
	# Only the animated art flips. Physics, shadow, label and status effects do
	# not mirror or jump as the dog changes direction.
	sprite.flip_h = not right


func show_name(seconds: float = 2.5) -> void:
	name_time = seconds
	# The nearby interaction prompt already includes the dog's name. Keeping
	# this separate label hidden in that moment prevents two identical names.
	if not interact_label.visible:
		name_label.show()


func happy() -> void:
	heart_time = 1.1
	reaction_duration = 0.8 if variant_id == "shiba" else 1.0 if variant_id == "cream" else 0.85
	reaction_time = reaction_duration
	if texture_available:
		_play(&"happy", true)
		idle_variant_until = 0.48


func wake() -> void:
	# Wake is visual-only: dog.gd keeps ownership, hunger and state authority.
	reaction_duration = 0.62 if variant_id != "cream" else 0.72
	reaction_time = reaction_duration
	if texture_available:
		_play(&"wake_up", true)


func set_interaction_hint(show_hint: bool, display_name: String) -> void:
	interact_label.visible = show_hint
	if show_hint:
		interact_label.text = display_name
	_refresh_hungry_badge()
	# The interact prompt is the one consistent name presentation in-world.
	# A separate floating name can otherwise linger after the player moves away.
	name_label.hide()


func _refresh_hungry_badge() -> void:
	var waiting_for_food := state_name == "WAIT_FOOD"
	# The prompt is more actionable at close range. Hiding the badge there keeps
	# the two labels from covering one another; it returns immediately on exit.
	thought_label.visible = waiting_for_food and not interact_label.visible
	thought_label.text = tr("DOG_HUNGRY_BADGE") if waiting_for_food else ""


func set_inside(inside: bool) -> void:
	if is_instance_valid(visibility_tween):
		visibility_tween.kill()
	if not inside:
		show()
	visibility_tween = create_tween()
	visibility_tween.tween_property(self, "modulate:a", 0.0 if inside else 1.0, 0.18)
	if inside:
		visibility_tween.tween_callback(hide)


func _play_state_animation() -> void:
	if not texture_available:
		return
	match state_name:
		"WANDER", "GO_INSIDE", "EXIT_HOUSE":
			_play(&"walk")
		"RETURN_HOME", "GREET_PLAYER":
			_play(&"run")
		"WAIT_FOOD":
			_play(&"sit_idle")
		"LIE_DOWN":
			_play(&"lie_down")
		"SLEEP":
			_play(&"sleep")
		"EATING":
			_play(&"eat")
		"INSIDE_HOUSE":
			sprite.stop()
		_:
			_play(&"idle")


func _play(animation_name: StringName, restart: bool = false) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return
	if restart or sprite.animation != animation_name:
		sprite.play(animation_name)
	_apply_frame_anchor()


func _on_sprite_frame_changed() -> void:
	_apply_frame_anchor()


func _apply_frame_anchor() -> void:
	var sheet: Texture2D = DogData.visual_sheet_for_variant(variant_id)
	if sheet == null or sprite.sprite_frames == null:
		sprite.offset = Vector2.ZERO
		return
	var source_cell := DogData.cell_for_animation_frame(variant_id, sprite.animation, sprite.frame)
	var source_anchor := DogData.cell_anchor_for_variant(variant_id, source_cell)
	var target_anchor := DogData.target_anchor_for_variant(variant_id, sheet)
	# offset is in unscaled texture pixels. Sprite.scale applies it once, so the
	# body root, collision, ground shadow and labels remain completely stable.
	sprite.offset = target_anchor - source_anchor


func _process(delta: float) -> void:
	phase += delta
	name_time = maxf(0.0, name_time - delta)
	if name_time <= 0.0:
		name_label.hide()
	heart_time = maxf(0.0, heart_time - delta)
	_update_zzz()
	var reaction_ended := reaction_time > 0.0 and reaction_time <= delta
	reaction_time = maxf(0.0, reaction_time - delta)
	if reaction_time > 0.0:
		_update_reaction_motion()
		return
	if reaction_ended:
		motion_root.rotation = 0.0
		motion_root.position = Vector2.ZERO
		_play_state_animation()
	_update_idle_variation(delta)
	_update_secondary_motion()
	queue_redraw()


func _update_idle_variation(delta: float) -> void:
	if state_name != "IDLE" or not texture_available:
		return
	if idle_variant_until > 0.0:
		idle_variant_until = maxf(0.0, idle_variant_until - delta)
		if idle_variant_until <= 0.0:
			_play(&"idle", true)
		return
	next_idle_variation -= delta
	if next_idle_variation > 0.0:
		return
	# Visual-only personality beats. They never alter the dog state machine,
	# hunger, movement, or save data.
	var choices: Array[StringName] = [&"idle_blink", &"sniff", &"alert", &"sit_idle"]
	var weights: Array[float] = [0.38, 0.25, 0.17, 0.20]
	if variant_id == "cream":
		weights = [0.32, 0.12, 0.08, 0.48]
	elif variant_id == "blacktan":
		weights = [0.27, 0.28, 0.31, 0.14]
	var roll := rng.randf()
	var sum := 0.0
	var choice: StringName = &"idle_blink"
	for index in choices.size():
		sum += weights[index]
		if roll <= sum:
			choice = choices[index]
			break
	_play(choice, true)
	idle_variant_until = 0.5 if choice == &"idle_blink" else rng.randf_range(1.0, 1.7)
	next_idle_variation = rng.randf_range(8.0, 18.0)


func _update_secondary_motion() -> void:
	if not texture_available:
		return
	# Feeding begins while the dog walks to its bowl. Keep the existing EATING
	# state intact, but show locomotion until its body has actually arrived.
	if state_name == "EATING":
		var body := get_parent() as CharacterBody2D
		_play(&"walk" if is_instance_valid(body) and body.velocity.length_squared() > 1.0 else &"eat")
	if state_name == "LIE_DOWN" and sprite.animation == &"lie_down" and not sprite.is_playing():
		_play(&"lie_idle")
	var bob := 0.0
	if state_name in ["WANDER", "RETURN_HOME", "GO_INSIDE", "EXIT_HOUSE", "GREET_PLAYER"]:
		bob = sin(phase * (11.0 if state_name in ["RETURN_HOME", "GREET_PLAYER"] else 8.0)) * 0.7
		sprite.speed_scale = 1.15 if variant_id == "shiba" else 0.90 if variant_id == "cream" else 1.05
	elif state_name == "SLEEP":
		bob = sin(phase * 1.8) * 0.35
		sprite.speed_scale = 0.92
	else:
		bob = sin(phase * (2.0 if variant_id != "blacktan" else 2.6)) * 0.28
		sprite.speed_scale = 1.0
	motion_root.position = Vector2(0.0, bob)
	motion_root.rotation = 0.0


func _update_zzz() -> void:
	if state_name != "SLEEP":
		return
	var sequence := ["Z", "Zz", "Zzz"]
	zzz_label.text = sequence[posmod(int(floor(phase * 1.35)), sequence.size())]
	zzz_label.position = Vector2(20.0, -70.0 - fmod(phase * 7.0, 14.0))
	zzz_label.modulate.a = 0.55 + fmod(phase * 0.8, 0.35)


func _update_reaction_motion() -> void:
	var progress := 1.0 - reaction_time / maxf(0.01, reaction_duration)
	var arc := sin(progress * PI)
	var lift := 4.0 if variant_id == "shiba" else 2.8 if variant_id == "cream" else 3.4
	var tilt := deg_to_rad(1.5 if variant_id == "shiba" else 0.8 if variant_id == "cream" else 1.2)
	motion_root.position = Vector2(0.0, -arc * lift)
	motion_root.rotation = sin(progress * TAU) * tilt


func _draw_clean_heart() -> void:
	var progress := 1.0 - heart_time / 1.1
	var alpha := 1.0 if progress < 0.60 else clampf(1.0 - (progress - 0.60) / 0.40, 0.0, 1.0)
	var heart := String.chr(0x2665)
	var pop := lerpf(0.75, 1.12, minf(progress / 0.16, 1.0))
	draw_set_transform(Vector2(-12, -54 - progress * 18.0), 0.0, Vector2.ONE * pop)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, heart, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1.0, 0.33, 0.42, alpha))
	var delayed_progress := maxf(0.0, (progress - 0.10) / 0.90)
	draw_set_transform(Vector2(5, -48 - delayed_progress * 16.0), 0.0, Vector2.ONE * (pop * 0.86))
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, heart, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.55, 0.62, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var shadow_size := Vector2(24, 6) if state_name not in ["LIE_DOWN", "SLEEP"] else Vector2(30, 7)
	draw_set_transform(Vector2(0, -2), 0.0, shadow_size)
	draw_circle(Vector2.ZERO, 1.0, Color(0.08, 0.13, 0.08, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not texture_available:
		draw_circle(Vector2(0, -20), 15.0, Color("c9823d"))
		draw_circle(Vector2(-9, -32), 6.0, Color("9f5c2d"))
		draw_circle(Vector2(9, -32), 6.0, Color("9f5c2d"))
	if heart_time > 0.0:
		_draw_clean_heart()
