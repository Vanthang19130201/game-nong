# Audio System

## Architecture

`AudioManager` is an autoload and owns one music player, one farm ambience player, one rain ambience player, a 12-player non-spatial SFX pool, and a 4-player spatial SFX pool. Audio uses four buses: Master, Music, SFX, and Ambience. SFX mute also mutes ambience.

Use `AudioManager.play_sfx("plant_seed")` after a successful action. Pass a world position as the second argument for distance-attenuated animal/world sounds. `play_random_sfx` chooses among the registered variations. Missing files are ignored so gameplay remains independent from audio imports.

## Asset folders

- `assets/audio/music/`: original background tracks.
- `assets/audio/sfx/`: short, event-driven effects grouped by UI, farming, tools, fishing, animals, production, and world.
- `assets/audio/ambience/`: looping farm and weather beds.
- `assets/audio/default_bus_layout.tres`: shared bus routing.
- `tools/generate_audio.ps1`: reproducibly synthesizes the original WAV assets; Python is not needed at runtime.

## Event mapping

- UI buttons: `ui_click`; failed actions: `ui_error`.
- Coin balance changes after transactions: `coin` once per Inventory change.
- Plant and crop harvest: `plant_seed`, `harvest_crop`.
- Tool action: `axe_swing`/`hammer_swing`, successful resource hit: `axe_hit_wood`/`hammer_hit_rock`, depleted node: `tree_break`/`rock_break`.
- Dig: `dig_hit`; reward/found treasure: `dig_find`.
- Fishing state transitions: `fishing_cast`, `fishing_splash`, `fishing_bite`, `fish_caught`, `fishing_fail`, or `treasure_found`.
- Feed, animal products, production, building placement, and upgrades use their matching `animal_*`, `collect_*`, `production_*`, `product_collect`, `building_place`, and `upgrade_success` cues.
- Animal vocal cues use spatial playback and a shared cooldown. The three dog
  breeds use that same pooled positional path: greeting cues are globally
  spaced, while eating/lick sounds remain quiet and local.
- WeatherManager controls the rain ambience fade. GameClock remains the only time source.

## Dog sound set

`assets/audio/sfx/animals/dogs/` contains original, reproducibly synthesized
cozy cues for Shiba, Cream Dog, and Black Tan Dog. Each breed has its own soft
bark pair and happy cue; shared files cover the rare hunger whine, eating,
licking, sniffing, shake, sleep, and grass-paw details. `dog.gd` only triggers
them on state entry or a short eating beat—never every frame.

## Music and settings

The single `farm_day` original track runs on the Music bus through scene changes, preventing duplicate playback. Farm ambience and rain ambience are separate and subtle. Music and SFX/ambience have separate live toggles. Preferences and volumes are stored in `user://settings.cfg`, never in the farm save; new game and farm reset do not touch them. New profiles start at 38% music and 56% SFX, with additional bus and per-effect attenuation for a softer mix. Existing saved volume preferences remain honored while the mix trims also soften them.

## Copyright and adding sounds

All current audio is synthesized specifically for this project; no third-party audio is used. Add a WAV in the appropriate folder, register its path in `AudioManager.SOUND_FILES`, then call it after the corresponding successful gameplay event. Never add music or recordings without a verified license; record third-party source and license in `assets/audio/LICENSES.md`.
