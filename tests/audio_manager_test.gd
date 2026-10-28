extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		push_error("TEST FAILED: " + message)
		quit(1)
		assert(value, message)

func run_checks() -> void:
	await process_frame
	var audio: Node = root.get_node("AudioManager")
	var previous_settings := ConfigFile.new()
	var had_previous_settings: bool = previous_settings.load(audio.SETTINGS_PATH) == OK
	check(ProjectSettings.get_setting("audio/buses/default_bus_layout") == "res://assets/audio/default_bus_layout.tres", "project uses the shared default bus layout")
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		check(AudioServer.get_bus_index(bus) >= 0, "audio bus exists: " + bus)
	if had_previous_settings:
		check(audio.music_enabled == bool(previous_settings.get_value("audio", "music_enabled", true)) and audio.sfx_enabled == bool(previous_settings.get_value("audio", "sfx_enabled", true)), "saved audio preferences load")
	else:
		check(audio.music_enabled and audio.sfx_enabled, "first-run audio defaults on")
		check(is_equal_approx(audio.music_volume, 0.42) and is_equal_approx(audio.sfx_volume, 0.62), "default mix is softer at 42% music and 62% SFX")
	check(audio.SOUND_FILES.size() >= 30, "core sound library registered")
	for sound_id in audio.SOUND_FILES:
		for relative_path in audio.SOUND_FILES[sound_id]:
			check(ResourceLoader.exists(audio.SFX_ROOT + relative_path), "registered SFX file exists: " + str(relative_path))
	var music: AudioStream = load("res://assets/audio/music/farm_day.wav")
	check(music != null and music.get_length() >= 60.0 and music.get_length() <= 120.0, "original Farm Day music is a long loop")
	await create_timer(0.8).timeout # Let the intentional crossfade switch tracks.
	check(audio.get_node_or_null("MusicPlayer") != null and audio.get_node("MusicPlayer").stream != null, "one persistent music player is loaded")
	audio.play_sfx("ui_click")
	await create_timer(0.01).timeout
	var heard_sfx := false
	for player in audio._sfx_players:
		heard_sfx = heard_sfx or player.playing
	check(heard_sfx, "SFX pool plays a registered clip")
	var weather: Node = root.get_node("WeatherManager")
	weather.current_weather = "rain"
	weather.changed.emit("rain")
	check(audio._rain_ambience.playing, "existing WeatherManager starts rain ambience")
	weather.current_weather = "sunny"
	weather.changed.emit("sunny")
	audio.set_sfx_enabled(false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "SFX toggle mutes effects")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")), "SFX toggle also mutes ambience")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "SFX toggle leaves music enabled")
	audio.set_music_enabled(false)
	await create_timer(0.6).timeout
	check(not audio.music_enabled and not audio.get_node("MusicPlayer").playing and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Music toggle fades/stops music independently of SFX")
	audio.set_sfx_enabled(true)
	var settings := ConfigFile.new()
	check(settings.load(audio.SETTINGS_PATH) == OK and not settings.get_value("audio", "music_enabled", true) and settings.get_value("audio", "sfx_enabled", false), "music and SFX preferences persist independently in ConfigFile")
	audio.set_music_enabled(true)
	var menu: Control = load("res://start_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.get_child_count() > 0, "start menu builds with audio settings access")
	menu.queue_free()
	for player in audio._sfx_players:
		player.stop()
	audio._music_player.stop()
	audio._farm_ambience.stop()
	audio._rain_ambience.stop()
	if had_previous_settings:
		previous_settings.save(audio.SETTINGS_PATH)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(audio.SETTINGS_PATH))
	audio.queue_free()
	await process_frame
	print("PASS: AudioManager core, bus mutes, original music, registered assets, and settings persistence")
	quit()
