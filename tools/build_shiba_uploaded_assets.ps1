Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sourceDir = Join-Path $root 'assets/animals/dogs/shiba/from_uploaded'
$outputDir = Join-Path $root 'assets/animals/dogs/shiba/animations'
$canvas = 256
$safeMargin = 24
$groundY = 210

$runSource = [System.Drawing.Bitmap]::new((Join-Path $sourceDir 'source_run_10.png'))
$actionSource = [System.Drawing.Bitmap]::new((Join-Path $sourceDir 'source_actions.png'))
if ($runSource.Width -ne 1983 -or $runSource.Height -ne 793) { throw "Unexpected uploaded run source size: $($runSource.Width)x$($runSource.Height)" }
if ($actionSource.Width -ne 1536 -or $actionSource.Height -ne 1024) { throw "Unexpected uploaded action source size: $($actionSource.Width)x$($actionSource.Height)" }

function Get-GridRectangle([System.Drawing.Bitmap]$source, [int]$columns, [int]$rows, [int]$index) {
	$column = $index % $columns
	$row = [math]::Floor($index / $columns)
	$left = [math]::Floor($column * $source.Width / [double]$columns)
	$right = [math]::Floor(($column + 1) * $source.Width / [double]$columns)
	$top = [math]::Floor($row * $source.Height / [double]$rows)
	$bottom = [math]::Floor(($row + 1) * $source.Height / [double]$rows)
	return [System.Drawing.Rectangle]::FromLTRB($left, $top, $right, $bottom)
}

function Get-ActionRectangle([int]$side, [int]$row, [int]$index) {
	# The uploaded board has two measured 768px halves with five source poses
	# per half.  The vertical bands deliberately start below each printed label.
	$bands = @(
		@(38, 142), @(157, 270), @(300, 412), @(438, 552),
		@(582, 697), @(727, 833), @(840, 937), @(944, 1024)
	)
	$left = [math]::Floor($side * 768 + $index * 768.0 / 5.0)
	$right = [math]::Floor($side * 768 + ($index + 1) * 768.0 / 5.0)
	return [System.Drawing.Rectangle]::FromLTRB($left, $bands[$row][0], $right, $bands[$row][1])
}

function Get-OpaqueBounds([System.Drawing.Bitmap]$source, [System.Drawing.Rectangle]$region, [bool]$keepEffects = $false) {
	$minX = $region.Width; $minY = $region.Height; $maxX = -1; $maxY = -1
	for ($y = 0; $y -lt $region.Height; $y++) {
		for ($x = 0; $x -lt $region.Width; $x++) {
			$pixel = $source.GetPixel($region.X + $x, $region.Y + $y)
			if ($pixel.A -le 32) { continue }
			# The board background is stored with alpha 0.  Exclude only detached
			# blue sleep Zs from runtime frames: the game already owns a Zzz effect.
			$isSleepZ = -not $keepEffects -and $pixel.B -gt $pixel.R * 1.25 -and $pixel.B -gt $pixel.G * 1.1
			if ($isSleepZ) { continue }
			$minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
			$maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
		}
	}
	if ($maxX -lt 0) { throw "No visible Shiba pixels in source region $region." }
	# Preserve a small source gutter so anti-aliased edge pixels never clip.
	return [System.Drawing.Rectangle]::FromLTRB(
		[math]::Max(0, $minX - 2), [math]::Max(0, $minY - 2),
		[math]::Min($region.Width, $maxX + 3), [math]::Min($region.Height, $maxY + 3)
	)
}

function New-AlignedFrame([System.Drawing.Bitmap]$source, [System.Drawing.Rectangle]$region, [double]$scale, [string]$label) {
	$bounds = Get-OpaqueBounds $source $region
	$frame = [System.Drawing.Bitmap]::new($canvas, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$graphics = [System.Drawing.Graphics]::FromImage($frame)
	$graphics.Clear([System.Drawing.Color]::Transparent)
	$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
	$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
	$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
	$width = [math]::Round($bounds.Width * $scale)
	$height = [math]::Round($bounds.Height * $scale)
	$drawX = [math]::Round($canvas * 0.5 - $width * 0.5)
	$drawY = [math]::Round($groundY - $height)
	$destination = [System.Drawing.Rectangle]::new($drawX, $drawY, $width, $height)
	$sourceRect = [System.Drawing.Rectangle]::new($region.X + $bounds.X, $region.Y + $bounds.Y, $bounds.Width, $bounds.Height)
	$graphics.DrawImage($source, $destination, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
	$graphics.Dispose()
	Test-SafeFrame $frame $label
	return $frame
}

function Test-SafeFrame([System.Drawing.Bitmap]$image, [string]$label) {
	$minX = $canvas; $minY = $canvas; $maxX = -1; $maxY = -1
	for ($y = 0; $y -lt $canvas; $y++) {
		for ($x = 0; $x -lt $canvas; $x++) {
			if ($image.GetPixel($x, $y).A -gt 26) {
				$minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
				$maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
			}
		}
	}
	if ($maxX -lt 0 -or $minX -lt $safeMargin -or $minY -lt $safeMargin -or $maxX -ge $canvas - $safeMargin -or $maxY -ge $canvas - $safeMargin) {
		throw "Cropped Shiba frame: $label ($minX,$minY)-($maxX,$maxY)"
	}
}

function Save-Strip([string]$name, [System.Collections.Generic.List[System.Drawing.Bitmap]]$frames) {
	if ($frames.Count -lt 1) { throw "No frames for $name" }
	$strip = [System.Drawing.Bitmap]::new($canvas * $frames.Count, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$graphics = [System.Drawing.Graphics]::FromImage($strip)
	$graphics.Clear([System.Drawing.Color]::Transparent)
	for ($index = 0; $index -lt $frames.Count; $index++) {
		$graphics.DrawImageUnscaled($frames[$index], $index * $canvas, 0)
	}
	$strip.Save((Join-Path $outputDir ("shiba_{0}.png" -f $name)), [System.Drawing.Imaging.ImageFormat]::Png)
	$graphics.Dispose(); $strip.Dispose()
}

function Copy-Frame([System.Drawing.Bitmap]$frame) {
	$copy = [System.Drawing.Bitmap]::new($canvas, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$graphics = [System.Drawing.Graphics]::FromImage($copy)
	$graphics.DrawImageUnscaled($frame, 0, 0)
	$graphics.Dispose()
	return $copy
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
Get-ChildItem -LiteralPath $outputDir -Filter 'shiba_*.png' -File | Remove-Item -Force

$animationFrames = @{}
function Read-Action([string]$name, [int]$side, [int]$row) {
	$frames = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
	for ($index = 0; $index -lt 5; $index++) {
		$frames.Add((New-AlignedFrame $actionSource (Get-ActionRectangle $side $row $index) 1.18 ("$name/$($index + 1)")))
	}
	$animationFrames[$name] = $frames
}

Read-Action 'idle' 0 0
Read-Action 'walk' 1 0
Read-Action 'run_fast' 1 1
Read-Action 'happy' 0 2
Read-Action 'bark' 1 2
Read-Action 'sit_idle' 0 3
Read-Action 'sit_to_stand' 1 3
Read-Action 'stand_to_sit' 0 4
Read-Action 'lie_down' 1 4
Read-Action 'sleep' 0 5
Read-Action 'eat' 1 5
Read-Action 'drink' 0 6
Read-Action 'shake' 1 6
Read-Action 'hurt' 0 7
# The final action row places DEAD in the centre and GET_UP in the right half.
Read-Action 'dead' 1 7
Read-Action 'get_up' 1 7

$runFrames = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
for ($index = 0; $index -lt 10; $index++) {
	$runFrames.Add((New-AlignedFrame $runSource (Get-GridRectangle $runSource 5 2 $index) 0.52 ("run/$($index + 1)")))
}
$animationFrames['run'] = $runFrames

# Runtime API mappings.  These use only the newly uploaded source; unavailable
# source actions resolve to compatible new animation strips instead of old art.
$runtimeMap = [ordered]@{
	idle = 'idle'; blink = 'idle'; walk = 'walk'; run = 'run'
	sit = 'stand_to_sit'; sit_idle = 'sit_idle'; lie_down = 'lie_down'
	lie_idle = 'lie_down'; sleep = 'sleep'; wake_up = 'get_up'
	eat = 'eat'; happy = 'happy'; sniff = 'idle'; scratch = 'sit_idle'
	shake = 'shake'; alert = 'bark'
}
foreach ($entry in $runtimeMap.GetEnumerator()) {
	$sourceFrames = $animationFrames[$entry.Value]
	if ($entry.Key -eq 'lie_idle') {
		$single = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
		$single.Add((Copy-Frame $sourceFrames[$sourceFrames.Count - 1]))
		Save-Strip $entry.Key $single
		$single[0].Dispose()
	} else {
		Save-Strip $entry.Key $sourceFrames
	}
}

foreach ($name in @('run_fast', 'bark', 'sit_to_stand', 'stand_to_sit', 'drink', 'hurt', 'dead', 'get_up')) {
	Save-Strip $name $animationFrames[$name]
}

# The store/static recovery art is new source frame 1, not the old Shiba board.
$animationFrames['idle'][0].Save((Join-Path $outputDir 'shiba_card.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$preview = [System.Drawing.Bitmap]::new($canvas * 5, $canvas * 6, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
$previewGraphics.Clear([System.Drawing.Color]::Transparent)
$previewOrder = @('idle', 'walk', 'run_fast', 'happy', 'bark', 'sit_idle', 'sit_to_stand', 'stand_to_sit', 'lie_down', 'sleep', 'eat', 'drink', 'shake', 'hurt', 'dead', 'get_up')
for ($index = 0; $index -lt $previewOrder.Count; $index++) {
	$previewGraphics.DrawImageUnscaled($animationFrames[$previewOrder[$index]][0], ($index % 5) * $canvas, [math]::Floor($index / 5) * $canvas)
}
for ($index = 0; $index -lt $runFrames.Count; $index++) {
	$previewGraphics.DrawImageUnscaled($runFrames[$index], ($index % 5) * $canvas, (4 + [math]::Floor($index / 5)) * $canvas)
}
$preview.Save((Join-Path $root 'assets/animals/dogs/shiba/shiba_animation_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$previewGraphics.Dispose(); $preview.Dispose()

foreach ($frames in $animationFrames.Values) {
	foreach ($frame in $frames) { $frame.Dispose() }
}
$runSource.Dispose(); $actionSource.Dispose()
Write-Output 'Built Shiba runtime strips from the two uploaded source images.'
