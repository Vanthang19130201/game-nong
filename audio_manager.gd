extends Node

## Central audio service. Missing resources fail quietly so gameplay never depends on audio.
const SETTINGS_PATH := "user://settings.cfg"
const SFX_ROOT := "res://assets/audio/sfx/"
const MUSIC_ROOT := "res://assets/audio/music/"
const AMBIENCE_ROOT := "res://assets/audio/ambience/"
const SFX_POOL_SIZE := 12
const SPATIAL_POOL_SIZE := 4
const DEFAULT_MUSIC_VOLUME := 0.5
const DEFAULT_SFX_VOLUME := 0.75

var music_enabled := true
var sfx_enabled := true
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _spatial_players: Array[AudioStreamPlayer2D] = []
var _pool_cursor := 0
var _spatial_cursor := 0
var _music_player: AudioStreamPlayer
var _farm_ambience: AudioStreamPlayer
var _rain_ambience: AudioStreamPlayer
var _music_tween: Tween
var _rain_tween: Tween
var _last_coins := -1

const SOUND_FILES := {
	"ui_click": ["ui/ui_click_01.wav", "ui/ui_click_02.wav"],
	"ui_success": ["ui/ui_success.wav"], "ui_error": ["ui/ui_error.wav"],
	"coin": ["ui/coin_01.wav", "ui/coin_02.wav"],
	"plant_seed": ["farming/plant_seed.wav"],
	"harvest_crop": ["farming/harvest_crop_01.wav", "farming/harvest_crop_02.wav", "farming/harvest_crop_03.wav"],
	"axe_swing": ["tools/axe_swing.wav"],
	"axe_hit_wood": ["tools/axe_hit_wood_01.wav", "tools/axe_hit_wood_02.wav", "tools/axe_hit_wood_03.wav"],
	"tree_break": ["tools/tree_break.wav"], "hammer_swing": ["tools/hammer_swing.wav"],
	"hammer_hit_rock": ["tools/hammer_hit_rock_01.wav", "tools/hammer_hit_rock_02.wav", "tools/hammer_hit_rock_03.wav"],
	"rock_break": ["tools/rock_break.wav"], "dig_hit": ["tools/dig_hit.wav"], "dig_find": ["tools/dig_find.wav"],
	"fishing_cast": ["fishing/fishing_cast.wav"], "fishing_splash": ["fishing/fishing_splash.wav"],
	"fishing_bite": ["fishing/fishing_bite.wav"], "fishing_reel_tick": ["fishing/fishing_reel_tick.wav"],
	"fish_caught": ["fishing/fish_caught.wav"], "fishing_fail": ["fishing/fishing_fail.wav"],
	"treasure_found": ["fishing/treasure_found.wav"],
	"chicken_cluck": ["animals/chicken_cluck.wav"], "cow_moo": ["animals/cow_moo.wav"],
	"pig_oink": ["animals/pig_oink.wav"], "sheep_baa": ["animals/sheep_baa.wav"],
	"animal_feed": ["animals/animal_feed.wav"], "collect_egg": ["animals/collect_egg.wav"],
	"collect_milk": ["animals/collect_milk.wav"], "collect_wool": ["animals/collect_wool.wav"],
	"item_collect": ["animals/item_collect.wav"],
	"production_start": ["production/production_start.wav"],
	"production_ready": ["production/production_ready.wav"],
	"product_collect": ["production/product_collect.wav"],
	"building_place": ["production/building_place.wav"],
	"upgrade_success": ["production/upgrade_success.wav"],
	"footstep_soft": ["world/footstep_soft_01.wav", "world/footstep_soft_02.wav", "world/footstep_soft_03.wav"]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_load_settings()
	_apply_bus_settings()
	_create_players()
	get_tree().node_added.connect(_on_node_added)
	if is_instance_valid(Inventory):
		Inventory.inventory_changed.connect(_on_inventory_changed)
		Inventory.action_failed.connect(_on_action_failed)
		_last_coins = Inventory.coins
	if is_instance_valid(WeatherManager):
		WeatherManager.changed.connect(_on_weather_changed)
		_on_weather_changed(WeatherManager.current_weather)
	if is_instance_valid(GameClock):
		GameClock.changed.connect(_on_clock_changed)
	_sync_ambience.call_deferred()
	_play_farm_music()

func _ensure_audio_buses() -> void:
	# Keep the project bus layout as the editor default, and also ensure the named
	# runtime buses exist in exported/headless runs where that layout is unavailable.
	for bus_name in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var bus_index := AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")

func _create_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_farm_ambience = AudioStreamPlayer.new()
	_farm_ambience.name = "FarmAmbience"
	_farm_ambience.bus = "Ambience"
	_farm_ambience.volume_db = -19.0
	_farm_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_farm_ambience)
	_rain_ambience = AudioStreamPlayer.new()
	_rain_ambience.name = "RainAmbience"
	_rain_ambience.bus = "Ambience"
	_rain_ambience.volume_db = -35.0
	_rain_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_rain_ambience)
	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%02d" % index
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)
	for index in range(SPATIAL_POOL_SIZE):
		var player := AudioStreamPlayer2D.new()
		player.name = "SpatialSFX_%02d" % index
		player.bus = "SFX"
		player.max_distance = 520.0
		player.attenuation = 1.25
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_spatial_players.append(player)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))
	music_volume = clampf(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_apply_bus_settings()
	_save_settings()
	if enabled:
		_play_farm_music()
	else:
		if _music_tween != null and _music_tween.is_valid():
			_music_tween.kill()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -36.0, 0.55)
		_music_tween.tween_callback(_music_player.stop)

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_apply_bus_settings()
	_save_settings()
	if enabled:
		_sync_ambience()
		play_sfx("ui_click")

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_settings()
	_save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_settings()
	_save_settings()

func _apply_bus_settings() -> void:
	_set_bus_volume("Music", music_volume, true)
	_set_bus_volume("SFX", sfx_volume, sfx_enabled)
	_set_bus_volume("Ambience", 0.42, sfx_enabled)

func _set_bus_volume(bus_name: String, value: float, enabled: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, not enabled or value <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, value)))

func play_sfx(sound_id: String, world_position: Vector2 = Vector2.INF, vary_pitch := true) -> void:
	if not sfx_enabled:
		return
	var variants: Array = SOUND_FILES.get(sound_id, [])
	if variants.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key := _cooldown_key(sound_id)
	var cooldown := _cooldown_for(sound_id)
	if now - float(_last_played.get(key, -INF)) < cooldown:
		return
	_last_played[key] = now
	var path := SFX_ROOT + str(variants[randi() % variants.size()])
	var stream := _get_stream(path)
	if stream == null:
		return
	var player: Node
	if world_position.is_finite():
		player = _spatial_players[_spatial_cursor]
		_spatial_cursor = (_spatial_cursor + 1) % _spatial_players.size()
		(player as AudioStreamPlayer2D).global_position = world_position
	else:
		player = _sfx_players[_pool_cursor]
		_pool_cursor = (_pool_cursor + 1) % _sfx_players.size()
	player.stop()
	player.stream = stream
	player.pitch_scale = randf_range(0.985, 1.015) if vary_pitch else 1.0
	player.play()

func play_random_sfx(sound_id: String, world_position: Vector2 = Vector2.INF) -> void:
	play_sfx(sound_id, world_position, true)

func _get_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if path.begins_with(MUSIC_ROOT) or path.begins_with(AMBIENCE_ROOT) else AudioStreamWAV.LOOP_DISABLED
		if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
			stream.loop_begin = 0
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	_streams[path] = stream
	return stream

func play_music(track_id := "farm_day", fade_seconds := 1.5) -> void:
	var path := MUSIC_ROOT + track_id + ".wav"
	var stream := _get_stream(path)
	if stream == null or not music_enabled:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -36.0, maxf(0.0, fade_seconds * 0.45))
	_music_tween.tween_callback(func() -> void:
		_music_player.stream = stream
		_music_player.play()
		_music_player.volume_db = -36.0
	)
	_music_tween.tween_property(_music_player, "volume_db", 0.0, maxf(0.05, fade_seconds * 0.55))

func _play_farm_music() -> void:
	play_music("farm_day", 1.4)

func _sync_ambience() -> void:
	var farm_stream := _get_stream(AMBIENCE_ROOT + "farm_ambience.wav")
	if farm_stream != null and _farm_ambience.stream != farm_stream:
		_farm_ambience.stream = farm_stream
		_farm_ambience.play()
	var raining := is_instance_valid(WeatherManager) and WeatherManager.current_weather == "rain"
	if raining:
		if _rain_ambience.stream == null:
			_rain_ambience.stream = _get_stream(AMBIENCE_ROOT + "rain_loop.wav")
		if _rain_ambience.stream != null and not _rain_ambience.playing:
			_rain_ambience.play()
	_fade_player(_rain_ambience, -9.0 if raining and sfx_enabled else -42.0, 1.8)

func _fade_player(player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	if player.stream == null:
		return
	if _rain_tween != null and _rain_tween.is_valid() and player == _rain_ambience:
		_rain_tween.kill()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, duration)
	if player == _rain_ambience and target_db <= -40.0:
		tween.tween_callback(player.stop)
	if player == _rain_ambience:
		_rain_tween = tween

func _on_weather_changed(_weather_id: String) -> void:
	_sync_ambience()

func _on_clock_changed() -> void:
	# One Farm Day track is intentionally reused; no second time system or duplicate player.
	_sync_ambience()

func _cooldown_key(sound_id: String) -> String:
	if sound_id.begins_with("chicken_") or sound_id.begins_with("cow_") or sound_id.begins_with("pig_") or sound_id.begins_with("sheep_"):
		return "animal_vocal"
	if sound_id == "production_ready":
		return "production_ready_global"
	return sound_id

func _cooldown_for(sound_id: String) -> float:
	if sound_id == "ui_click": return 0.045
	if sound_id in ["axe_hit_wood", "hammer_hit_rock", "harvest_crop", "footstep_soft"]: return 0.10
	if _cooldown_key(sound_id) == "animal_vocal": return randf_range(8.0, 20.0)
	if sound_id == "production_ready": return 3.5
	if sound_id == "fishing_reel_tick": return 0.8
	return 0.0

func _on_inventory_changed() -> void:
	if SaveManager.resetting:
		_last_coins = Inventory.coins
		return
	if _last_coins >= 0 and Inventory.coins != _last_coins:
		play_sfx("coin")
	_last_coins = Inventory.coins

func _on_action_failed(_message: String) -> void:
	play_sfx("ui_error")

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_ui_button_pressed):
		node.pressed.connect(_on_ui_button_pressed)

func _on_ui_button_pressed() -> void:
	play_sfx("ui_click")
