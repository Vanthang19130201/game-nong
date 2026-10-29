extends SceneTree

const Data = preload("res://character_data.gd")


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)


func run_checks() -> void:
	var frames: SpriteFrames = Data.frames_for("farmer_01")
	check(Data.complete(frames), "Farmer 1 has all eight directional animations")
	# Only the artist-labelled horizontal idle strips face the opposite screen
	# direction. Walk strips retain the established player-controller mapping.
	var expected_horizontal_sources := {
		&"idle_left": "player1_idle_right.png",
		&"idle_right": "player1_idle_left.png",
	}
	for animation_name in Data.ANIMATIONS:
		check(frames.get_frame_count(animation_name) == 6, animation_name + " has exactly six frames")
		check(frames.get_animation_loop(animation_name), animation_name + " loops")
		check(is_equal_approx(frames.get_animation_speed(animation_name), 8.0 if animation_name.begins_with("walk") else 3.0), animation_name + " has the intended FPS")
		for frame_index in range(6):
			var frame: AtlasTexture = frames.get_frame_texture(animation_name, frame_index) as AtlasTexture
			check(frame != null, animation_name + " frame exists " + str(frame_index))
			check(frame.region == Rect2(frame_index * 362, 0, 362, 724), animation_name + " uses the fixed 362x724 strip grid")
			check(frame.atlas != null and frame.atlas.resource_path.contains("assets/characters/farmer_01/player1/player1_"), animation_name + " uses only Player 1's supplied strip")
			if expected_horizontal_sources.has(animation_name):
				check(frame.atlas.resource_path.ends_with(str(expected_horizontal_sources[animation_name])), animation_name + " faces the matching screen direction")
	print("PASS: player1_animation")
	quit()
