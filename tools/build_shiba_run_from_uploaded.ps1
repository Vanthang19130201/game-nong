Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sourcePath = Join-Path $root 'assets/animals/dogs/shiba/from_uploaded/source_run_10.png'
$outputRoot = Join-Path $root 'assets/animals/dogs/shiba/animations'
$frameOutput = Join-Path $outputRoot 'run'
$canvas = 256
$safeMargin = 24
$groundY = 210
$scale = 0.52

$source = [System.Drawing.Bitmap]::new($sourcePath)
if ($source.Width -ne 1983 -or $source.Height -ne 793) {
	throw "Expected the uploaded 1983x793, 2x5 Shiba run board; got $($source.Width)x$($source.Height)."
}

function Get-SourcePanel([int]$index) {
	$column = $index % 5
	$row = [math]::Floor($index / 5)
	$cellLeft = [math]::Floor($column * $source.Width / 5.0)
	$cellRight = [math]::Floor(($column + 1) * $source.Width / 5.0)
	$cellTop = [math]::Floor($row * $source.Height / 2.0)
	$cellBottom = [math]::Floor(($row + 1) * $source.Height / 2.0)
	# The uploaded board's panel decoration sits on the outer cell edges. These
	# measured gutters leave the complete Shiba (including paws and curled tail)
	# inside the extraction region.
	$topGutter = if ($row -eq 0) { 64 } else { 38 }
	return [System.Drawing.Rectangle]::FromLTRB($cellLeft + 32, $cellTop + $topGutter, $cellRight - 26, $cellBottom - 28)
}

function Get-OpaqueBounds([System.Drawing.Rectangle]$panel) {
	$minX = $panel.Width; $minY = $panel.Height; $maxX = -1; $maxY = -1
	for ($y = 0; $y -lt $panel.Height; $y++) {
		for ($x = 0; $x -lt $panel.Width; $x++) {
			if ($source.GetPixel($panel.X + $x, $panel.Y + $y).A -gt 32) {
				$minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
				$maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
			}
		}
	}
	if ($maxX -lt 0) { throw "No Shiba pixels found in source panel $panel." }
	return [System.Drawing.Rectangle]::FromLTRB(
		[math]::Max(0, $minX - 2), [math]::Max(0, $minY - 2),
		[math]::Min($panel.Width, $maxX + 3), [math]::Min($panel.Height, $maxY + 3)
	)
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

function Remove-DetachedPanelArtifacts([System.Drawing.Bitmap]$frame) {
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

function New-Frame([int]$index) {
	$panel = Get-SourcePanel $index
	$bounds = Get-OpaqueBounds $panel
	$frame = [System.Drawing.Bitmap]::new($canvas, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$graphics = [System.Drawing.Graphics]::FromImage($frame)
	$graphics.Clear([System.Drawing.Color]::Transparent)
	$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
	$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
	$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
	$width = [math]::Round($bounds.Width * $scale)
	$height = [math]::Round($bounds.Height * $scale)
	$target = [System.Drawing.Rectangle]::new([math]::Round(($canvas - $width) * 0.5), $groundY - $height, $width, $height)
	$sourceRect = [System.Drawing.Rectangle]::new($panel.X + $bounds.X, $panel.Y + $bounds.Y, $bounds.Width, $bounds.Height)
	$graphics.DrawImage($source, $target, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
	$graphics.Dispose()
	Remove-DetachedPanelArtifacts $frame
	Test-SafeFrame $frame ("run_{0:D2}" -f ($index + 1))
	return $frame
}

New-Item -ItemType Directory -Path $frameOutput -Force | Out-Null
Get-ChildItem -LiteralPath $frameOutput -Filter 'shiba_run_*.png' -File -ErrorAction SilentlyContinue | Remove-Item -Force
$frames = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
$signatures = [System.Collections.Generic.HashSet[string]]::new()
for ($index = 0; $index -lt 10; $index++) {
	$frame = New-Frame $index
	$path = Join-Path $frameOutput ("shiba_run_{0:D2}.png" -f ($index + 1))
	$frame.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
	$signature = [Convert]::ToBase64String(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([IO.File]::ReadAllBytes($path)))
	$signatures.Add($signature) | Out-Null
	$frames.Add($frame)
}
if ($signatures.Count -lt 6) { throw "Run extraction produced too few distinct frames: $($signatures.Count)." }

$strip = [System.Drawing.Bitmap]::new($canvas * 10, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stripGraphics = [System.Drawing.Graphics]::FromImage($strip)
$stripGraphics.Clear([System.Drawing.Color]::Transparent)
for ($index = 0; $index -lt 10; $index++) {
	$stripGraphics.DrawImageUnscaled($frames[$index], $index * $canvas, 0)
}
$strip.Save((Join-Path $outputRoot 'shiba_run.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$stripGraphics.Dispose(); $strip.Dispose()
foreach ($frame in $frames) { $frame.Dispose() }
$source.Dispose()
Write-Output "Built 10 clean 256x256 Shiba run frames and a 2560x256 runtime strip."
