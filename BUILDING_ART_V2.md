# Farm Buildings Pack v2 — 2026-10-30

Base HEAD inspected: `1beb903b575549771a2e4e2dc38a112c1e5570bc`.

## Result and existing limitation

Nine existing world buildings now use the uploaded artwork. All ten supplied
images have cached, aspect-preserving icon/preview mappings. The originals are
retained byte-for-byte in `assets/buildings/v2/`; existing older assets remain.

**Loom is not implemented as a world building in this HEAD.** `farm_data.gd`
points to `res://loom.tscn`, but that scene and its controller do not exist.
Only `loom_data.gd`, inventory ownership, recipes and save queue data exist.
The uploaded Loom artwork is prepared and mapped to its existing `loom` ID for
icons and a future visual scene. No new production/gameplay was invented in
this visual-only patch. World appearance, interaction and production of Loom
are therefore not claimed complete or tested.

## Mapping and fitted transforms

All coordinates below are local to the existing Sprite2D. Scale applies only
to that sprite, equally on X/Y. Root position, root scale, physical collision,
interaction range and saved IDs are unchanged. The offset anchors the bottom
of the visible source region to `position.y`.

| Supplied file | Existing ID / node | Uniform scale | Sprite position | Sprite offset |
| --- | --- | ---: | --- | --- |
| `01_main_house.png` | `house` / `House` | 0.167891 | (0, 80) | (0, -476.5) |
| `02_feed_mill.png` | `feed_mill` / `FeedMill` | 0.131148 | (0, 38) | (0, -457.5) |
| `03_bakery.png` | `bakery` / `Bakery` | 0.128571 | (0, 54) | (0, -525) |
| `04_spinning_machine.png` | `spinning_machine` / `SpinningMachine` | 0.152625 | (0, 48) | (0, -409.5) |
| `05_loom.png` | `loom` / scene missing | 0.133690 prepared | (0, 48) prepared | (0, -467.5) prepared |
| `06_cow_barn.png` | `cow_shed` / `CowShed` | 0.153339 | (0, 52) | (0, -493.5) |
| `07_chicken_coop.png` | `chicken_coop` / `ChickenCoop` | 0.130199 | (0, 36) | (0, -437) |
| `08_pig_pen.png` | `pig_pen` / `PigPen` | 0.159664 | (0, 56) | (0, -469) |
| `09_sheep_barn.png` | `sheep_barn` / `SheepBarn` | 0.160473 | (0, 56) | (0, -485) |
| `10_market_stall.png` | `market_stall` / `MarketStall` | 0.104712 | (0, 29) | (0, -485.5) |

`building_art_v2.gd` stores the source regions, target sizes and baselines.
The region removes blank canvas only; it encloses the entire visible artwork.
Nine original images have an opaque cream paper background. Render copies in
`assets/buildings/v2/transparent/` remove only pale exterior pixels reachable
from the canvas edge. Interior pale details retain their original artwork.
Rebuild with `tools/prepare_building_pack_v2.ps1`. No illustration was regenerated.

Runtime sprites, thumbnails and edit ghosts use Nearest sampling. New PNG
imports use lossless compression, original resolution and no mipmaps.
Textures/thumbnails are loaded once and cached; there is no per-frame loading
or runtime image generation.

## Files

Created:

- `assets/buildings/v2/`: ten original PNGs and their Godot import files.
- `assets/buildings/v2/transparent/`: ten render PNGs and import files.
- `building_art_v2.gd` and its UID: shared visual mapping/cache/ground alignment.
- `tools/prepare_building_pack_v2.ps1`: repeatable exterior-alpha preparation.
- `tests/building_pack_v2_test.gd` and its UID.
- This report.

Modified:

- `main.tscn`: existing HouseSprite selects the new `house` artwork.
- `chicken_coop.tscn`, `cow_shed.tscn`, `pig_pen.tscn`, `sheep_barn.tscn`:
  existing BuildingSprite selects its new artwork; gameplay nodes unchanged.
- `artwork_sprite.gd`: reuse shared mapping for matching building IDs; retain
  manual texture overrides and the legacy loader for everything else.
- `item_icon.gd`: use shared new building thumbnails, including Loom.
- `building_placement.gd`: ghost sprite copies source texture filtering.
- `tests/building_artwork_test.gd`, `tests/visual_asset_test.gd`: update obsolete
  texture/size assertions, use owned visual fixtures for placement buildings,
  and check animal base fit rather than its existing idle breathing transform.
- `tests/run_core_stability.ps1`: register the three `v2_*` isolated stages.

Feed Mill, Bakery, Spinning Machine and Market Stall scenes already identify
their artwork by the existing IDs; the shared loader switches their textures.
Dog House, animals/player artwork, gameplay data, prices, outputs, timers,
recipes, ownership, save architecture, audio, crops and fishing were not edited.

## Collision, depth, merchant and saves

No collision needed adjustment. Existing lower-body colliders and authored
placement rectangles are retained. Transparent padding creates no new blocker.
WorldDepth still sorts by existing physical foot position; automated checks
verify Player depth in front of and behind each of the nine buildings.

`MarketStall` keeps its exact node name, stable ID, position and interaction.
The current merchant actually anchors to `OrderBoard`, not Market Stall.
Its placement helper still returns a valid nearby point. The merchant is also
visible in the rendered House screenshot. No merchant spawn logic changed.

No artwork fields or migrations were added to saves. Separate-process tests
loaded existing building positions and an active Bakery queue, then displayed
the new artwork automatically. A version-17 save fixture also loads successfully.
Tests use `res://test-save.cfg` in a disposable project; no player save was used.

## Tests actually run

Godot `4.7.2.stable.official.ed1daf0bf`, Windows / Compatibility renderer.

| Check | Result |
| --- | --- |
| Source asset import / script parsing | Completed; no patch parser errors |
| `v2_write` final | PASS, 224 checks |
| `v2_legacy_prepare` then fresh-process `v2_read` | PASS; read stage 224 checks |
| GUI-rendered `v2_write --capture` at 1280×720 | PASS; nine screenshots saved |
| `building_artwork` at 1152×648 | PASS; E, ESC, panels, labels, fallback handling |
| `art_core` after adapting old visual fixtures | PASS |
| `pig_sheep_placement` | PASS; real purchase, placement, charging and saving |
| `animal_output` | PASS; chicken/cow/sheep output and normal/Lucky Pig output |
| `feed_core` old suite | FAILED at fixture purchase before production checks |

The focused v2 scenarios additionally ran Feed Mill production/collection,
Spinning Machine production/collection, Bakery enqueue/save, collision against
all nine buildings, real edit-mode movement, ghost texture/region/filter checks,
unchanged root/IDs/saved anchors, ten icon mappings, and front/behind depth.
The old `feed_core` fixture calls `buy_building("feed_mill")` without a placement
source, which the current purchase API rejects. That suite is not reported PASS;
the dedicated production scenario passes through the existing station logic.

Several processes emit the environment's root-certificate warning. Some existing
suites also emit ObjectDB/resource-in-use warnings at exit; those are not claimed
fixed by this asset patch. Editor import reports restricted write access to user
editor settings; project asset imports still complete. No full-game regression
suite or Loom gameplay PASS is claimed.

Logs and rendered previews are under `.godot/`, including:

- `building-v2-final-v2_write.log`, `building-v2-final-v2_read.log`.
- `building-v2-render.log`, `building-v2-artwork.log`, `building-v2-art-core3.log`.
- `building-v2-animal-output.log`, `building-v2-placement.log`.
- `core-stability-project/building-v2-<building_id>.png`.

Re-run isolated stages through `tests/run_core_stability.ps1` with
`GODOT_TEST_ONLY` set in turn to `v2_write`, `v2_legacy_prepare`, `v2_read`.
