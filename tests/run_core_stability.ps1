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
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fish_market_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'level_audit_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'localization_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'storage_ui_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bakery_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'crop_expansion_test.gd') -Destination $testRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'warehouse_test.gd') -Destination $testRoot -Force
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
$stages = @('core', 'position_write', 'position_read', 'legacy_write', 'legacy_read',
    'invalid_write', 'invalid_read', 'offline_write', 'offline_read',
    'backup_write', 'backup_read', 'defaults_write', 'defaults_read', 'duplicates',
    'fishing_core', 'fishing_limits', 'fishing_write', 'fishing_read', 'market_core', 'market_read',
    'audit_core', 'audit_write', 'audit_read', 'audit_again', 'audit_close', 'localization', 'storage_ui',
    'bakery_core', 'bakery_write', 'bakery_read', 'bakery_again', 'bakery_reset_read',
    'crop_core', 'crop_write', 'crop_read', 'crop_again', 'warehouse_core', 'warehouse_write', 'warehouse_read')
foreach ($stage in $stages) {
    $log = Join-Path $testRoot "$stage.log"
    $ErrorActionPreference = 'Continue'
    $testScript = if ($stage.StartsWith('fishing_')) { 'fishing_test.gd' } else { 'core_stability_test.gd' }
    if ($stage.StartsWith('market_')) { $testScript = 'fish_market_test.gd' }
    if ($stage.StartsWith('audit_')) { $testScript = 'level_audit_test.gd' }
    if ($stage.StartsWith('bakery_')) { $testScript = 'bakery_test.gd' }
    if ($stage.StartsWith('crop_')) { $testScript = 'crop_expansion_test.gd' }
    if ($stage.StartsWith('warehouse_')) { $testScript = 'warehouse_test.gd' }
    if ($stage -eq 'localization') { $testScript = 'localization_test.gd' }
    if ($stage -eq 'storage_ui') { $testScript = 'storage_ui_test.gd' }
    & $Godot --headless --path $testRoot --script $testScript --quit-after 1800 -- $stage *> $log
    $ErrorActionPreference = $previousPreference
    $output = Get-Content -LiteralPath $log -Raw
    $unexpected = @($output -split "`n" | Where-Object {
        $_ -match '^ERROR:' -and $_ -notmatch 'root certificate store|user://logs' -and
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
& $Godot --headless --path $testRoot --script gameplay_regression_test.gd --quit-after 1800 *> (Join-Path $testRoot 'gameplay.log')
$ErrorActionPreference = $previousPreference
$gameplayOutput = Get-Content -LiteralPath (Join-Path $testRoot 'gameplay.log') -Raw
$unexpected = @($gameplayOutput -split "`n" | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch 'root certificate store|user://logs' })
if ($gameplayOutput -notmatch 'PASS: eight crops' -or $gameplayOutput -match 'SCRIPT ERROR|TEST FAILED|GDScript::reload|Node not found' -or $unexpected.Count -gt 0) {
    Write-Output $gameplayOutput
    throw 'Gameplay regression failed.'
}
Write-Output 'PASS: gameplay regression'
Write-Output "All stability stages passed. Logs: $testRoot"
