extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)


func run_checks() -> void:
	var merchant_script: Script = load("res://wandering_merchant_visual.gd")
	var merchant: Variant = merchant_script.new()
	var frames: SpriteFrames = merchant._create_sprite_frames()
	check(frames.get_animation_names() == PackedStringArray([&"merchant_greet"]), "only one merchant animation exists")
	check(frames.get_frame_count(&"merchant_greet") == 6, "greet uses every supplied pose")
	check(is_equal_approx(frames.get_animation_speed(&"merchant_greet"), 6.0), "greet runs at 6 FPS")
	check(not frames.get_animation_loop(&"merchant_greet"), "greet never loops")
	var first_texture: AtlasTexture = frames.get_frame_texture(&"merchant_greet", 0) as AtlasTexture
	check(first_texture != null and first_texture.atlas != null, "merchant frame is an atlas texture")
	check(first_texture.atlas.resource_path.ends_with("assets/characters/merchant/merchant_greet.png"), "merchant uses the supplied sprite sheet")
	check(first_texture.region.size == Vector2(1448.0 / 3.0, 1086.0 / 2.0), "all frames use a consistent uncropped region")
	print("PASS: merchant_visual")
	quit()
