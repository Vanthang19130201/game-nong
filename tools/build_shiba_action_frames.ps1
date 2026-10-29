param(
	[string]$OnlyAction = ''
)

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

# Builds only the seven uploaded Shiba action sheets.  RUN deliberately stays
# outside this tool: its ten-frame source/archive/output are treated as a
# regression fixture and verified by hash before and after this script runs.
$root = Split-Path $PSScriptRoot -Parent
$sourceRoot = Join-Path $root 'assets/animals/dogs/shiba/from_uploaded/actions'
$outputRoot = Join-Path $root 'assets/animals/dogs/shiba/animations'
$canvas = 256
$safeMargin = 24
$groundY = 210
$runStrip = Join-Path $outputRoot 'shiba_run.png'
$runFrames = Join-Path $outputRoot 'run'

$actions = @(
	[pscustomobject]@{ Name = 'idle'; File = 'idle.png'; Width = 1448; Height = 1086; Columns = 3; Rows = 2; Scale = 0.44; Fps = 5.5; Loop = $true },
	[pscustomobject]@{ Name = 'idle_blink'; File = 'idle_blink.png'; Width = 1254; Height = 1254; Columns = 2; Rows = 2; Scale = 0.34; Fps = 7.5; Loop = $false },
	[pscustomobject]@{ Name = 'walk'; File = 'walk.png'; Width = 1672; Height = 941; Columns = 4; Rows = 2; Scale = 0.46; Fps = 8.5; Loop = $true },
	[pscustomobject]@{ Name = 'sit'; File = 'sit.png'; Width = 1672; Height = 941; Columns = 5; Rows = 1; Scale = 0.47; Fps = 7.0; Loop = $false },
	[pscustomobject]@{ Name = 'sit_idle'; File = 'sit_idle.png'; Width = 1254; Height = 1254; Columns = 2; Rows = 2; Scale = 0.34; Fps = 4.5; Loop = $true },
	[pscustomobject]@{ Name = 'lie_down'; File = 'lie_down.png'; Width = 1448; Height = 1086; Columns = 3; Rows = 2; Scale = 0.44; Fps = 7.0; Loop = $false },
	[pscustomobject]@{ Name = 'lie_idle'; File = 'lie_idle.png'; Width = 1254; Height = 1254; Columns = 2; Rows = 2; Scale = 0.39; Fps = 4.5; Loop = $true }
)

if ($OnlyAction) {
	$actions = @($actions | Where-Object { $_.Name -eq $OnlyAction })
	if ($actions.Count -ne 1) { throw "Unknown Shiba action '$OnlyAction'." }
}

function Get-FileDigest([string]$path) {
	if (-not (Test-Path -LiteralPath $path)) { throw "Required RUN regression fixture is missing: $path" }
	return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
}

function Get-ActionPanel([System.Drawing.Bitmap]$source, $action, [int]$index) {
	$column = $index % $action.Columns
	$row = [math]::Floor($index / $action.Columns)
	$left = [math]::Floor($column * $source.Width / $action.Columns)
	$right = [math]::Floor(($column + 1) * $source.Width / $action.Columns)
	$top = [math]::Floor($row * $source.Height / $action.Rows)
	$bottom = [math]::Floor(($row + 1) * $source.Height / $action.Rows)
	return [System.Drawing.Rectangle]::FromLTRB($left, $top, $right, $bottom)
}

function Get-OpaqueBounds([System.Drawing.Bitmap]$source, [System.Drawing.Rectangle]$panel) {
	$minX = $panel.Width; $minY = $panel.Height; $maxX = -1; $maxY = -1
	for ($y = 0; $y -lt $panel.Height; $y++) {
		for ($x = 0; $x -lt $panel.Width; $x++) {
			if ($source.GetPixel($panel.X + $x, $panel.Y + $y).A -gt 32) {
				$minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
				$maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
			}
		}
	}
	if ($maxX -lt 0) { throw "No Shiba pixels found in action panel $panel." }
	# Two transparent pixels protect outlines without ever cutting anatomy.
	return [System.Drawing.Rectangle]::FromLTRB(
		[math]::Max(0, $minX - 2), [math]::Max(0, $minY - 2),
		[math]::Min($panel.Width, $maxX + 3), [math]::Min($panel.Height, $maxY + 3)
	)
}

function Remove-DetachedArtifacts([System.Drawing.Bitmap]$frame) {
	# Retain the large connected dog silhouette and immediately adjacent pieces.
	# This removes source-sheet specks and the separate Z graphic in lie_idle
	# without applying unsafe global colour removal to the red scarf/gold bell.
	$length = $canvas * $canvas
	$active = [bool[]]::new($length)
	$visited = [bool[]]::new($length)
	for ($y = 0; $y -lt $canvas; $y++) {
		for ($x = 0; $x -lt $canvas; $x++) {
			$active[$y * $canvas + $x] = $frame.GetPixel($x, $y).A -gt 32
		}
	}
	$components = [System.Collections.Generic.List[object]]::new()
	for ($seed = 0; $seed -lt $length; $seed++) {
		if (-not $active[$seed] -or $visited[$seed]) { continue }
		$queue = [System.Collections.Generic.Queue[int]]::new()
		$pixels = [System.Collections.Generic.List[int]]::new()
		$queue.Enqueue($seed); $visited[$seed] = $true
		$minX = $canvas; $minY = $canvas; $maxX = -1; $maxY = -1
		while ($queue.Count -gt 0) {
			$current = $queue.Dequeue(); $pixels.Add($current)
			$x = $current % $canvas; $y = [math]::Floor($current / $canvas)
			$minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
			$maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
			for ($dy = -1; $dy -le 1; $dy++) {
				for ($dx = -1; $dx -le 1; $dx++) {
					if ($dx -eq 0 -and $dy -eq 0) { continue }
					$nx = $x + $dx; $ny = $y + $dy
					if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $canvas -or $ny -ge $canvas) { continue }
					$next = $ny * $canvas + $nx
					if ($active[$next] -and -not $visited[$next]) { $visited[$next] = $true; $queue.Enqueue($next) }
				}
			}
		}
		$components.Add([pscustomobject]@{ Pixels = $pixels; Bounds = [System.Drawing.Rectangle]::FromLTRB($minX, $minY, $maxX + 1, $maxY + 1) })
	}
	$body = $components | Sort-Object { $_.Pixels.Count } -Descending | Select-Object -First 1
	if ($null -eq $body) { throw 'No connected Shiba body found after extraction.' }
	$keep = [bool[]]::new($length)
	foreach ($component in $components) {
		$bounds = $component.Bounds; $bodyBounds = $body.Bounds
		$gapX = [math]::Max(0, [math]::Max($bounds.Left - $bodyBounds.Right, $bodyBounds.Left - $bounds.Right))
		$gapY = [math]::Max(0, [math]::Max($bounds.Top - $bodyBounds.Bottom, $bodyBounds.Top - $bounds.Bottom))
		if ($component -ne $body -and ($component.Pixels.Count -lt 8 -or [math]::Max($gapX, $gapY) -gt 7)) { continue }
		foreach ($pixelIndex in $component.Pixels) { $keep[[int]$pixelIndex] = $true }
	}
	for ($index = 0; $index -lt $length; $index++) {
		if (-not $keep[$index]) { $frame.SetPixel($index % $canvas, [math]::Floor($index / $canvas), [System.Drawing.Color]::Transparent) }
	}
}

function Test-SafeFrame([System.Drawing.Bitmap]$frame, [string]$label) {
	$minX = $canvas; $minY = $canvas; $maxX = -1; $maxY = -1
	for ($y = 0; $y -lt $canvas; $y++) {
		for ($x = 0; $x -lt $canvas; $x++) {
			if ($frame.GetPixel($x, $y).A -gt 26) {
				$minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
				$maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
			}
		}
	}
	if ($maxX -lt 0 -or $minX -lt $safeMargin -or $minY -lt $safeMargin -or $maxX -ge $canvas - $safeMargin -or $maxY -ge $canvas - $safeMargin) {
		throw "Cropped or panel-contaminated Shiba frame ${label}: ($minX,$minY)-($maxX,$maxY)"
	}
}

function New-ActionFrame([System.Drawing.Bitmap]$source, $action, [int]$index) {
	$panel = Get-ActionPanel $source $action $index
	$bounds = Get-OpaqueBounds $source $panel
	$frame = [System.Drawing.Bitmap]::new($canvas, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$graphics = [System.Drawing.Graphics]::FromImage($frame)
	$graphics.Clear([System.Drawing.Color]::Transparent)
	$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
	$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
	$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
	$width = [math]::Round($bounds.Width * $action.Scale)
	$height = [math]::Round($bounds.Height * $action.Scale)
	$target = [System.Drawing.Rectangle]::new([math]::Round(($canvas - $width) * 0.5), $groundY - $height, $width, $height)
	$sourceRect = [System.Drawing.Rectangle]::new($panel.X + $bounds.X, $panel.Y + $bounds.Y, $bounds.Width, $bounds.Height)
	$graphics.DrawImage($source, $target, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
	$graphics.Dispose()
	Remove-DetachedArtifacts $frame
	Test-SafeFrame $frame ("{0}_{1:D2}" -f $action.Name, ($index + 1))
	return $frame
}

$runDigestBefore = Get-FileDigest $runStrip
$runFrameDigestsBefore = @((Get-ChildItem -LiteralPath $runFrames -Filter 'shiba_run_*.png' -File | Sort-Object Name | ForEach-Object { Get-FileDigest $_.FullName }))
if ($runFrameDigestsBefore.Count -ne 10) { throw "RUN regression fixture must contain exactly 10 separate frames, found $($runFrameDigestsBefore.Count)." }

foreach ($action in $actions) {
	$sourcePath = Join-Path $sourceRoot $action.File
	$source = [System.Drawing.Bitmap]::new($sourcePath)
	if ($source.Width -ne $action.Width -or $source.Height -ne $action.Height) {
		throw "Expected uploaded $($action.Name) sheet $($action.Width)x$($action.Height); got $($source.Width)x$($source.Height)."
	}
	$frameCount = $action.Columns * $action.Rows
	$frameOutput = Join-Path $outputRoot $action.Name
	New-Item -ItemType Directory -Path $frameOutput -Force | Out-Null
	Get-ChildItem -LiteralPath $frameOutput -Filter ("shiba_{0}_*.png" -f $action.Name) -File -ErrorAction SilentlyContinue | Remove-Item -Force
	$frames = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
	$signatures = [System.Collections.Generic.HashSet[string]]::new()
	for ($index = 0; $index -lt $frameCount; $index++) {
		$frame = New-ActionFrame $source $action $index
		$framePath = Join-Path $frameOutput ("shiba_{0}_{1:D2}.png" -f $action.Name, ($index + 1))
		$frame.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
		$signatures.Add((Get-FileDigest $framePath)) | Out-Null
		$frames.Add($frame)
	}
	if ($signatures.Count -lt 2) { throw "$($action.Name) extraction produced fewer than two distinct source frames." }
	$strip = [System.Drawing.Bitmap]::new($canvas * $frameCount, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$stripGraphics = [System.Drawing.Graphics]::FromImage($strip)
	$stripGraphics.Clear([System.Drawing.Color]::Transparent)
	for ($index = 0; $index -lt $frameCount; $index++) { $stripGraphics.DrawImageUnscaled($frames[$index], $index * $canvas, 0) }
	$assetName = if ($action.Name -eq 'idle_blink') { 'blink' } else { $action.Name }
	$strip.Save((Join-Path $outputRoot ("shiba_{0}.png" -f $assetName)), [System.Drawing.Imaging.ImageFormat]::Png)
	$stripGraphics.Dispose(); $strip.Dispose()
	foreach ($frame in $frames) { $frame.Dispose() }
	$source.Dispose()
	Write-Output ("{0}: {1} full-body 256x256 frames" -f $action.Name, $frameCount)
}

if ((Get-FileDigest $runStrip) -ne $runDigestBefore) { throw 'RUN strip was modified; refusing this action-only build.' }
$runFrameDigestsAfter = @((Get-ChildItem -LiteralPath $runFrames -Filter 'shiba_run_*.png' -File | Sort-Object Name | ForEach-Object { Get-FileDigest $_.FullName }))
if (($runFrameDigestsAfter.Count -ne 10) -or -not (@($runFrameDigestsAfter | Compare-Object $runFrameDigestsBefore -SyncWindow 0).Count -eq 0)) {
	throw 'RUN frames were modified; refusing this action-only build.'
}

Write-Output 'Built seven clean action strips; the 10-frame RUN fixture is unchanged.'
