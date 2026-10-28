param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $projectRoot '.godot/core-stability-project'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets') -Destination $testRoot -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'localization') -Destination $testRoot -Recurse -Force
Get-ChildItem -LiteralPath $projectRoot -File | Where-Object {
    $_.Extension -in @('.gd', '.uid', '.tscn', '.godot', '.svg', '.import')
} | Copy-Item -Destination $testRoot -Force
$managerPath = Join-Path $testRoot 'save_manager.gd'
$managerText = [IO.File]::ReadAllText($managerPath)
$managerText = $managerText.Replace('user://save.cfg', 'res://test-save.cfg').Replace('user://save_backup.cfg', 'res://test-backup.cfg')
[IO.File]::WriteAllText($managerPath, $managerText)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'core_stability_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'gameplay_regression_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fishing_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'upgrade_treasure_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fish_market_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'market_stall_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'order_board_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'level_audit_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'localization_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'storage_ui_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bakery_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'crop_expansion_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'warehouse_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'mouse_interaction_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'farm_edit_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'land_expansion_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'camera_control_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'soil_plot_edit_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'stability_edge_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dairy_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'spinning_machine_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rock_types_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fishing_resource_update_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'cozy_ui_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'plot_purchase_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ui_polish_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'visual_asset_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'building_artwork_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'farm_world_presence_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'collision_animal_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'character_selection_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'character_size_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'animal_wander_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'animal_entity_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'station_status_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'crop_visual_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'floating_feedback_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'hud_completion_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'level_up_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'feed_mill_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'pig_sheep_placement_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'world_expansion_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'discovery_system_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'audio_manager_test.gd') -Destination $testRoot -Force
$projectPath = Join-Path $testRoot 'project.godot'
Add-Content -LiteralPath $projectPath -Value "`n[debug]`nfile_logging/enable_file_logging=false"
# Reuse the project's existing imports; no editor/settings writes are needed.
$importSource = Join-Path $projectRoot '.godot/imported'
if (-not (Test-Path -LiteralPath $importSource)) {
    throw 'Open the real project in Godot once to import its assets, then run tests.'
}
$cacheRoot = Join-Path $testRoot '.godot'
New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
Copy-Item -LiteralPath $importSource -Destination $cacheRoot -Recurse -Force
$uidCache = Join-Path $projectRoot '.godot/uid_cache.bin'
if (Test-Path -LiteralPath $uidCache) { Copy-Item -LiteralPath $uidCache -Destination $cacheRoot -Force }
$previousPreference = $ErrorActionPreference
$stages = @('size_core', 'size_write', 'size_read', 'character_core', 'character_missing', 'character_write', 'character_read', 'character_legacy_write', 'character_legacy_read', 'character_invalid_write', 'character_invalid_read', 'collision_core', 'animal_context', 'fixes_write', 'fixes_read', 'fixes_hungry_read', 'core', 'position_write', 'position_read', 'legacy_write', 'legacy_read',
    'invalid_write', 'invalid_read', 'offline_write', 'offline_read',
    'backup_write', 'backup_read', 'defaults_write', 'defaults_read', 'duplicates',
    'fishing_core', 'fishing_limits', 'fishing_write', 'fishing_read', 'market_core', 'market_read', 'stall_core', 'stall_write', 'stall_read', 'stall_reset_read',
    'audit_core', 'animal_output', 'audit_write', 'audit_read', 'audit_again', 'audit_close', 'discovery_core', 'audio_core', 'localization', 'storage_ui', 'cozy_ui', 'plot_popup', 'ui_polish', 'art_core', 'building_artwork', 'world_presence',
    'orders_core', 'orders_write', 'orders_read', 'orders_expired_read', 'orders_legacy_write', 'orders_legacy_read',
    'bakery_core', 'bakery_write', 'bakery_read', 'bakery_again', 'bakery_reset_read',
    'bakery_cakes', 'bakery_cakes_write', 'bakery_cakes_read', 'bakery_cakes_again', 'bakery_legacy_write', 'bakery_legacy_read',
	'crop_core', 'crop_rare_write', 'crop_rare_read', 'crop_rare_again', 'crop_write', 'crop_read', 'crop_again', 'warehouse_core', 'warehouse_write', 'warehouse_read', 'mouse_core',
    'edit_core', 'edit_write', 'edit_read', 'edit_legacy_write', 'edit_legacy_read', 'land_core', 'land_write', 'land_read', 'land_reset_read', 'land_legacy_write', 'land_legacy_read', 'camera_core',
    'soil_edit_core','soil_edit_write','soil_edit_read','soil_edit_offline_write','soil_edit_offline_read','soil_edit_reset_read','soil_edit_legacy_write','soil_edit_legacy_read','soil_edit_invalid_write','soil_edit_invalid_read',
    'edge_input','edge_move','edge_orders','edge_orders_read','edge_orders_again','edge_decoration','edge_decoration_read',
    'dairy_core','dairy_write','dairy_read','dairy_again','dairy_reset_read','dairy_legacy_write','dairy_legacy_read',
    'spinning_core','spinning_write','spinning_read','spinning_again','spinning_reset_read','spinning_legacy_write','spinning_legacy_read',
    'rock_core','rock_write','rock_read','rock_respawn_write','rock_respawn_read','rock_legacy_write','rock_legacy_read','rock_reset_read',
    'resource_update_core','resource_update_write','resource_update_read','resource_update_legacy_write','resource_update_legacy_read',
    'animals_core','animals_write','animals_read','animals_again','animals_reset_read',
    'animal_entity_core','animal_entity_write','animal_entity_read',
    'pig_sheep_placement','expansion_core','expansion_write','expansion_read','expansion_legacy_write','expansion_legacy_read',
    'station_status_core','station_status_write','station_status_read',
    'crop_visual_core','crop_visual_write','crop_visual_read',
    'floating_core','floating_write','floating_read',
    'hud_completion','calendar_write','calendar_read','calendar_legacy_write','calendar_legacy_read','calendar_invalid_write','calendar_invalid_read',
    'feed_core','feed_write','feed_read','feed_again','feed_offline_write','feed_offline_read','feed_legacy_write','feed_legacy_read','feed_reset_read',
    'feed_cancel','feed_cancel_write','feed_cancel_read','feed_cancel_again','level_up',
    'upgrade_treasure_core','upgrade_treasure_legacy_write','upgrade_treasure_legacy_read')
$onlyStage = $env:GODOT_TEST_ONLY
if (-not [string]::IsNullOrWhiteSpace($onlyStage)) {
    $stages = @($stages | Where-Object { $_ -eq $onlyStage })
    if ($stages.Count -eq 0) { throw "Unknown test stage: $onlyStage" }
}
foreach ($stage in $stages) {
    $log = Join-Path $testRoot "$stage.log"
    $ErrorActionPreference = 'Continue'
    $testScript = if ($stage.StartsWith('fishing_')) { 'fishing_test.gd' } else { 'core_stability_test.gd' }
    if ($stage.StartsWith('upgrade_treasure_')) { $testScript = 'upgrade_treasure_test.gd' }
    if ($stage -in @('collision_core','animal_context','fixes_write','fixes_read','fixes_hungry_read')) { $testScript = 'collision_animal_test.gd' }
    if ($stage.StartsWith('character_')) { $testScript = 'character_selection_test.gd' }
    if ($stage.StartsWith('size_')) { $testScript = 'character_size_test.gd' }
    if ($stage.StartsWith('market_')) { $testScript = 'fish_market_test.gd' }
    if ($stage.StartsWith('stall_')) { $testScript = 'market_stall_test.gd' }
    if ($stage.StartsWith('orders_')) { $testScript = 'order_board_test.gd' }
    if ($stage.StartsWith('audit_')) { $testScript = 'level_audit_test.gd' }
    if ($stage -eq 'animal_output') { $testScript = 'level_audit_test.gd' }
    if ($stage -eq 'discovery_core') { $testScript = 'discovery_system_test.gd' }
    if ($stage -eq 'audio_core') { $testScript = 'audio_manager_test.gd' }
    if ($stage.StartsWith('bakery_')) { $testScript = 'bakery_test.gd' }
    if ($stage.StartsWith('crop_')) { $testScript = 'crop_expansion_test.gd' }
    if ($stage.StartsWith('warehouse_')) { $testScript = 'warehouse_test.gd' }
    if ($stage.StartsWith('mouse_')) { $testScript = 'mouse_interaction_test.gd' }
    if ($stage.StartsWith('edit_')) { $testScript = 'farm_edit_test.gd' }
    if ($stage.StartsWith('land_')) { $testScript = 'land_expansion_test.gd' }
    if ($stage.StartsWith('camera_')) { $testScript = 'camera_control_test.gd' }
    if ($stage.StartsWith('soil_edit_')) { $testScript = 'soil_plot_edit_test.gd' }
    if ($stage.StartsWith('edge_')) { $testScript = 'stability_edge_test.gd' }
    if ($stage.StartsWith('dairy_')) { $testScript = 'dairy_test.gd' }
    if ($stage.StartsWith('spinning_')) { $testScript = 'spinning_machine_test.gd' }
    if ($stage.StartsWith('rock_')) { $testScript = 'rock_types_test.gd' }
    if ($stage.StartsWith('resource_update_')) { $testScript = 'fishing_resource_update_test.gd' }
    if ($stage -eq 'localization') { $testScript = 'localization_test.gd' }
    if ($stage -eq 'storage_ui') { $testScript = 'storage_ui_test.gd' }
    if ($stage -eq 'cozy_ui') { $testScript = 'cozy_ui_test.gd' }
    if ($stage -eq 'plot_popup') { $testScript = 'plot_purchase_test.gd' }
    if ($stage -eq 'ui_polish') { $testScript = 'ui_polish_test.gd' }
    if ($stage -eq 'art_core') { $testScript = 'visual_asset_test.gd' }
    if ($stage -eq 'building_artwork') { $testScript = 'building_artwork_test.gd' }
    if ($stage -eq 'world_presence') { $testScript = 'farm_world_presence_test.gd' }
    if ($stage.StartsWith('animals_')) { $testScript = 'animal_wander_test.gd' }
    if ($stage.StartsWith('animal_entity_')) { $testScript = 'animal_entity_test.gd' }
    if ($stage.StartsWith('station_status_')) { $testScript = 'station_status_test.gd' }
    if ($stage.StartsWith('crop_visual_')) { $testScript = 'crop_visual_test.gd' }
    if ($stage.StartsWith('floating_')) { $testScript = 'floating_feedback_test.gd' }
    if ($stage -eq 'hud_completion' -or $stage.StartsWith('calendar_')) { $testScript = 'hud_completion_test.gd' }
    if ($stage -eq 'level_up') { $testScript = 'level_up_test.gd' }
    if ($stage.StartsWith('feed_')) { $testScript = 'feed_mill_test.gd' }
    if ($stage -eq 'pig_sheep_placement') { $testScript = 'pig_sheep_placement_test.gd' }
    if ($stage.StartsWith('expansion_')) { $testScript = 'world_expansion_test.gd' }
    & $Godot --headless --path $testRoot --script $testScript --quit-after 1800 --log-file $log -- $stage
    $ErrorActionPreference = $previousPreference
    $output = Get-Content -LiteralPath $log -Raw
    $unexpected = @($output -split "`n" | Where-Object {
        $_ -match '^ERROR:' -and $_ -notmatch 'root certificate store|user://logs' -and
        -not ($stage -eq 'pig_sheep_placement' -and $_ -match '^ERROR: \d+ (RID allocations of type .* were leaked at exit|resources still in use at exit)') -and
        -not ($stage -in @('backup_read','defaults_read') -and $_ -match 'ConfigFile parse error') -and
        -not ($stage -eq 'duplicates' -and $_ -match 'Duplicate .* ID:')
    })
    if ($output -notmatch "PASS: (stability )?$stage" -or $output -match 'SCRIPT ERROR|TEST FAILED|GDScript::reload|Node not found' -or $unexpected.Count -gt 0) {
        Write-Output $output
        throw "Stability test failed: $stage. See $log"
    }
    Write-Output "PASS: $stage"
}
$ErrorActionPreference = 'Continue'
if ([string]::IsNullOrWhiteSpace($onlyStage)) {
    & $Godot --headless --path $testRoot --script gameplay_regression_test.gd --quit-after 1800 --log-file (Join-Path $testRoot 'gameplay.log')
}
$ErrorActionPreference = $previousPreference
if (-not [string]::IsNullOrWhiteSpace($onlyStage)) {
    Write-Output "Selected test stage passed. Logs: $testRoot"
    exit 0
}
$gameplayOutput = Get-Content -LiteralPath (Join-Path $testRoot 'gameplay.log') -Raw
$unexpected = @($gameplayOutput -split "`n" | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch 'root certificate store|user://logs' })
if ($gameplayOutput -notmatch 'PASS: eight crops' -or $gameplayOutput -match 'SCRIPT ERROR|TEST FAILED|GDScript::reload|Node not found' -or $unexpected.Count -gt 0) {
    Write-Output $gameplayOutput
    throw 'Gameplay regression failed.'
}
Write-Output 'PASS: gameplay regression'
Write-Output "All stability stages passed. Logs: $testRoot"
