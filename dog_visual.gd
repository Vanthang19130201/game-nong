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
var state_tween: Tween
var visibility_tween: Tween
var idle_variant_until: float = 0.0
var next_idle_variation: float = 0.0
var rng := RandomNumberGenerator.new()

@onready var sprite: AnimatedSprite2D = $Sprite
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


func configure(next_variant_id: String, display_name: String) -> void:
	# The gameplay node configures itself just after _ready. Never let a tween
	# begun before the profile arrived restore a high-resolution source image to
	# scale 1 (the old cause of the giant Black Tan).
	if is_instance_valid(state_tween):
		state_tween.kill()
		state_tween = null
	variant_id = next_variant_id
	var frames := DogData.visual_frames_for_variant(variant_id)
	texture_available = frames != null
	sprite.sprite_frames = frames
	if frames != null:
		# The full original illustration is used as one compact world sprite.
		# Fit by source height so no high-resolution artwork overwhelms the farm.
		var source_texture: Texture2D = DogData.texture_for_variant(variant_id)
		var source_height: float = float(source_texture.get_height()) if source_texture != null else 1200.0
		var scale_factor := DogData.TARGET_BODY_HEIGHT / source_height
		sprite.scale = Vector2.ONE * scale_factor
		base_scale = sprite.scale
		# The source art is centered, with paws near the lower edge.
		base_sprite_position = Vector2(0.0, -source_height * scale_factor * 0.47)
		sprite.position = base_sprite_position
	name_label.text = display_name
	set_state(state_name)
	queue_redraw()


func set_state(next_state: String) -> void:
	state_name = next_state
	idle_variant_until = 0.0
	thought_label.visible = next_state == "WAIT_FOOD"
	thought_label.text = "â€¦" if thought_label.visible else ""
	zzz_label.visible = next_state == "SLEEP"
	_play_state_animation()
	if not texture_available:
		return
	if is_instance_valid(state_tween):
		state_tween.kill()
	state_tween = create_tween()
	state_tween.set_parallel(true)
	state_tween.tween_property(sprite, "scale", base_scale, 0.16).set_trans(Tween.TRANS_SINE)
	state_tween.tween_property(sprite, "position", base_sprite_position, 0.16).set_trans(Tween.TRANS_SINE)


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
	heart_time = 0.9
	reaction_time = 0.55
	if texture_available:
		_play(&"happy", true)
		idle_variant_until = 0.48


func set_interaction_hint(show_hint: bool, display_name: String) -> void:
	interact_label.visible = show_hint
	if show_hint:
		interact_label.text = "[E] " + display_name
	# The interact prompt is the one consistent name presentation in-world.
	# A separate floating name can otherwise linger after the player moves away.
	name_label.hide()


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


func _process(delta: float) -> void:
	phase += delta
	name_time = maxf(0.0, name_time - delta)
	if name_time <= 0.0:
		name_label.hide()
	heart_time = maxf(0.0, heart_time - delta)
	var reaction_ended := reaction_time > 0.0 and reaction_time <= delta
	reaction_time = maxf(0.0, reaction_time - delta)
	if reaction_time > 0.0:
		return
	if reaction_ended:
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
	sprite.position = base_sprite_position + Vector2(0.0, bob)


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
		draw_string(ThemeDB.fallback_font, Vector2(-4, -54 - (1.0 - heart_time / 0.9) * 8.0), "â™¥", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e86d6d", heart_time / 0.9))
