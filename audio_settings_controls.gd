extends VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_toggle_row("MUSIC", true)
	_build_toggle_row("SOUND_EFFECTS", false)

func _build_toggle_row(label_key: String, music: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = tr(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var toggle := Button.new()
	toggle.custom_minimum_size = Vector2(88, 36)
	toggle.focus_mode = Control.FOCUS_NONE
	var update := func() -> void:
		var enabled: bool = AudioManager.music_enabled if music else AudioManager.sfx_enabled
		toggle.text = tr("ON") if enabled else tr("OFF")
	update.call()
	toggle.pressed.connect(func() -> void:
		if music:
			AudioManager.set_music_enabled(not AudioManager.music_enabled)
		else:
			AudioManager.set_sfx_enabled(not AudioManager.sfx_enabled)
		update.call()
	)
	row.add_child(toggle)
	add_child(row)
