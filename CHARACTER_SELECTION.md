# Player characters

The project starts at `start_menu.tscn`. New Game opens the four cosmetic cards;
confirming creates a fresh save and enters `main.tscn`. Continue enters the farm
with the saved appearance. Cancelling selection preserves existing progress.
The existing Settings reset keeps its current flow and resets appearance to Farmer 1.

`player.gd` remains the only gameplay controller. Appearance is held in
`character_data.gd` and applied by `character_visual.gd` only on ready or
`SaveManager.selected_character_changed`. Dog visuals do not read the player selection.

## Replace artwork

For any `farmer_01` through `farmer_04`, add or replace:

`assets/characters/<id>/character.png`

Godot imports the PNG when the project is opened. Restart the running game to
refresh its cached frames. Keep the supplied `character.svg` and `frames.tres`;
the PNG takes priority over the SVG atlas at runtime, including in card previews.

The supplied sheet is **3 columns × 4 rows**:

| Row | Direction | Column 0 | Column 1 | Column 2 |
| --- | --- | --- | --- | --- |
| 0 | down | idle / neutral | walk step 1 | walk step 2 |
| 1 | up | idle / neutral | walk step 1 | walk step 2 |
| 2 | left | idle / neutral | walk step 1 | walk step 2 |
| 3 | right | idle / neutral | walk step 1 | walk step 2 |

The SVG is 144 × 256 pixels, with 48 × 64 cells. A PNG may use any resolution
with the same grid and proportions (for example 288 × 512, cells 96 × 128).
Atlas regions scale to the PNG dimensions automatically. Use transparent
backgrounds and consistent character/feet placement in every cell.
Player height is fitted uniformly to 48 world pixels; speed and collision stay the same.

For a different sheet layout, edit that character's `frames.tres` in Godot's
SpriteFrames editor. Replace its atlas/frame textures and preserve these names:

`idle_down`, `idle_up`, `idle_left`, `idle_right`,
`walk_down`, `walk_up`, `walk_left`, `walk_right`.

Each animation must contain non-null textures. For custom frames pointing to PNG
or other textures, those authored textures are used directly; only atlas references
to `character.svg` receive the automatic `character.png` substitution.
No gameplay script needs editing. Previews use the same SpriteFrames as Player.

To add Farmer 5 or more, add an entry to `CharacterData.CHARACTERS` and its assets.
The selection grid is built from the catalog automatically and scrolls when needed.

## Save and future appearance changes

The existing `user://save.cfg` stores `[player] selected_character_id`.
Missing/invalid IDs use `farmer_01`; incomplete frames fall back to Farmer 1,
then to a neutral SVG silhouette. No Godot logo is used for Player.

`SaveManager.set_selected_character("farmer_03")` saves and refreshes the active
Player immediately. This is the entry point for a future wardrobe.
`start_new_game(id)` performs the existing reset then commits the selected ID.
The internal `[game] character_selection_pending` marker prevents an abandoned
first launch from exposing a Continue button before a character is confirmed.
