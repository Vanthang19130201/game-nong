Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sourceDir = Join-Path $root 'assets/animals/dogs/shiba/from_uploaded'
$outputDir = Join-Path $root 'assets/animals/dogs/shiba/animations'
$canvas = 192
$safeMargin = 12
$groundY = 154
$scale = 0.39

$runSource = [System.Drawing.Bitmap]::new((Join-Path $sourceDir 'uploaded_run_sequence.png'))
$actionSource = [System.Drawing.Bitmap]::new((Join-Path $sourceDir 'uploaded_action_poses.png'))

function Get-CellRectangle([System.Drawing.Bitmap]$source, [int]$index) {
    $column = $index % 5; $row = [math]::Floor($index / 5)
    $left = [math]::Floor($column * $source.Width / 5.0)
    $right = [math]::Floor(($column + 1) * $source.Width / 5.0)
    $top = [math]::Floor($row * $source.Height / 2.0)
    $bottom = [math]::Floor(($row + 1) * $source.Height / 2.0)
    return [System.Drawing.Rectangle]::new($left, $top, $right - $left, $bottom - $top)
}

function Get-CleanCell([System.Drawing.Bitmap]$source, [System.Drawing.Rectangle]$cell) {
    $width = $cell.Width; $height = $cell.Height; $length = $width * $height
    $active = [bool[]]::new($length); $visited = [bool[]]::new($length)
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
			# The upload's opaque grid/separators live at cell edges. The dog itself
			# has room inside the grid, so ignore that matte before component analysis.
            $insideSourceSafeZone = $x -ge 12 -and $y -ge 12 -and $x -lt $width - 12 -and $y -lt $height - 12
            $active[$y * $width + $x] = $insideSourceSafeZone -and $source.GetPixel($cell.X + $x, $cell.Y + $y).A -gt 32
        }
    }
    $components = [System.Collections.Generic.List[object]]::new()
    for ($seed = 0; $seed -lt $length; $seed++) {
        if (-not $active[$seed] -or $visited[$seed]) { continue }
        $queue = [System.Collections.Generic.Queue[int]]::new()
        $pixels = [System.Collections.Generic.List[int]]::new()
		$warmPixels = 0
        $queue.Enqueue($seed); $visited[$seed] = $true
        $minX = $width; $minY = $height; $maxX = -1; $maxY = -1
        while ($queue.Count -gt 0) {
            $point = $queue.Dequeue(); $pixels.Add($point)
            $x = $point % $width; $y = [math]::Floor($point / $width)
			$color = $source.GetPixel($cell.X + $x, $cell.Y + $y)
			if ($color.R -gt $color.G * 1.08 -and $color.G -gt $color.B * 0.85) { $warmPixels++ }
            $minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
            $maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
            for ($dy = -1; $dy -le 1; $dy++) {
                for ($dx = -1; $dx -le 1; $dx++) {
                    if ($dx -eq 0 -and $dy -eq 0) { continue }
                    $nx = $x + $dx; $ny = $y + $dy
                    if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height) { continue }
                    $next = $ny * $width + $nx
                    if ($active[$next] -and -not $visited[$next]) { $visited[$next] = $true; $queue.Enqueue($next) }
                }
            }
        }
        $components.Add([pscustomobject]@{ Pixels = $pixels; WarmPixels = $warmPixels; Bounds = [System.Drawing.Rectangle]::FromLTRB($minX, $minY, $maxX + 1, $maxY + 1) })
    }
	# The upload includes checker/grid remnants that can form large transparent
	#-matte components. A dog is a warm, central component that does not touch
	# the cell's top or bottom separator, so score those features first.
	$candidates = $components | Where-Object { $_.Bounds.Top -gt 2 -and $_.Bounds.Bottom -lt $height - 2 }
	if ($null -eq $candidates -or @($candidates).Count -eq 0) { $candidates = $components }
	$body = $candidates | Sort-Object @{ Expression = { $_.WarmPixels * 4 + $_.Pixels.Count }; Descending = $true } | Select-Object -First 1
    if ($null -eq $body) { throw 'Uploaded Shiba cell has no visible dog component.' }
	if ($body.Pixels.Count -lt 100) { throw "Uploaded Shiba body selection is too small: $($body.Pixels.Count) pixels." }
	$bodyBounds = $body.Bounds
    $keep = [bool[]]::new($length)
    # Some real legs/paws are separated from the main paint mass by a fully
    # transparent line in the uploaded artwork.  Keeping only the biggest
    # alpha component therefore made a running Shiba lose a foot.  Retain all
    # small, warm components that belong to the body neighbourhood, while
    # rejecting the border-attached grid/checker remnants.
    $bodyZone = [System.Drawing.Rectangle]::FromLTRB(
        [math]::Max(12, $bodyBounds.Left - 28),
        [math]::Max(12, $bodyBounds.Top - 28),
        [math]::Min($width - 12, $bodyBounds.Right + 28),
        [math]::Min($height - 12, $bodyBounds.Bottom + 28)
    )
	foreach ($component in $components) {
		$componentBounds = $component.Bounds
		$touchesCellBorder = $componentBounds.Left -le 2 -or $componentBounds.Top -le 2 -or $componentBounds.Right -ge $width - 2 -or $componentBounds.Bottom -ge $height - 2
		$belongsToDog = $component -eq $body -or (
			-not $touchesCellBorder -and
			$component.Pixels.Count -ge 6 -and
			$component.WarmPixels -ge 2 -and
			$componentBounds.IntersectsWith($bodyZone)
		)
		if (-not $belongsToDog) { continue }
		for ($pixelIndex = 0; $pixelIndex -lt $component.Pixels.Count; $pixelIndex++) {
			$keep[[int]$component.Pixels[$pixelIndex]] = $true
		}
	}
    $clean = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($index = 0; $index -lt $length; $index++) {
        if ($keep[$index]) {
            $x = $index % $width; $y = [math]::Floor($index / $width)
            $clean.SetPixel($x, $y, $source.GetPixel($cell.X + $x, $cell.Y + $y))
        }
    }
    return [pscustomobject]@{ Image = $clean; Bounds = $bodyBounds }
}

function New-AlignedFrame([System.Drawing.Bitmap]$source, [int]$index) {
    $cell = Get-CellRectangle $source $index
    $clean = Get-CleanCell $source $cell
    $frame = [System.Drawing.Bitmap]::new($canvas, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($frame)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $drawX = [math]::Round($canvas * 0.5 - ($clean.Bounds.Left + $clean.Bounds.Width * 0.5) * $scale)
    $drawY = [math]::Round($groundY - $clean.Bounds.Bottom * $scale)
    $target = [System.Drawing.Rectangle]::new($drawX, $drawY, [math]::Round($cell.Width * $scale), [math]::Round($cell.Height * $scale))
    $graphics.DrawImage($clean.Image, $target, [System.Drawing.Rectangle]::new(0, 0, $cell.Width, $cell.Height), [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose(); $clean.Image.Dispose()
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
        throw "Shiba uploaded frame is cropped: $label ($minX,$minY)-($maxX,$maxY)"
    }
}

function Save-Frame([System.Drawing.Bitmap]$frame, [string]$path, [string]$label) {
	Test-SafeFrame $frame $label
    $frame.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$actionCells = [ordered]@{
    idle = 0; walk = 1; sit = 3; lie = 4; sleep = 5; eat = 6; happy = 7; sniff = 8; scratch = 9
}
$actions = @{}
foreach ($entry in $actionCells.GetEnumerator()) {
    $frame = New-AlignedFrame $actionSource $entry.Value
    Save-Frame $frame (Join-Path $sourceDir ("shiba_{0}_pose.png" -f $entry.Key)) ("action/{0}" -f $entry.Key)
    $actions[$entry.Key] = $frame
}

$runFrames = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()
for ($index = 0; $index -lt 10; $index++) {
    $frame = New-AlignedFrame $runSource $index
    Save-Frame $frame (Join-Path $sourceDir ("shiba_run_{0:D2}.png" -f ($index + 1))) ("run/{0:D2}" -f ($index + 1))
    $runFrames.Add($frame)
}

$singlePoseMap = @{ idle = 'idle'; blink = 'idle'; walk = 'walk'; sit = 'sit'; sit_idle = 'sit'; lie_down = 'lie'; lie_idle = 'lie'; sleep = 'sleep'; wake_up = 'sit'; eat = 'eat'; happy = 'happy'; sniff = 'sniff'; scratch = 'scratch'; shake = 'happy'; alert = 'idle' }
foreach ($entry in $singlePoseMap.GetEnumerator()) {
    $actions[$entry.Value].Save((Join-Path $outputDir ("shiba_{0}.png" -f $entry.Key)), [System.Drawing.Imaging.ImageFormat]::Png)
}

# The source includes a few airborne poses whose occluded legs become unclear
# at the game's world scale.  Keep the archive of all ten exact source frames,
# but play only the four clearest full-body stride frames in the live loop.
$runtimeRunCells = @(0, 1, 2, 4)
$runStrip = [System.Drawing.Bitmap]::new($canvas * $runtimeRunCells.Count, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$runGraphics = [System.Drawing.Graphics]::FromImage($runStrip)
$runGraphics.Clear([System.Drawing.Color]::Transparent)
for ($index = 0; $index -lt $runtimeRunCells.Count; $index++) {
	$runGraphics.DrawImage($runFrames[$runtimeRunCells[$index]], [System.Drawing.Rectangle]::new($index * $canvas, 0, $canvas, $canvas))
}
$runStrip.Save((Join-Path $outputDir 'shiba_run.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$runGraphics.Dispose(); $runStrip.Dispose()

$preview = [System.Drawing.Bitmap]::new($canvas * 5, $canvas * 4, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
$previewGraphics.Clear([System.Drawing.Color]::Transparent)
$previewOrder = @('idle', 'walk', 'sit', 'lie', 'sleep', 'eat', 'happy', 'sniff', 'scratch')
for ($index = 0; $index -lt $previewOrder.Count; $index++) {
    $previewGraphics.DrawImage($actions[$previewOrder[$index]], [System.Drawing.Rectangle]::new(($index % 5) * $canvas, [math]::Floor($index / 5) * $canvas, $canvas, $canvas))
}
for ($index = 0; $index -lt 10; $index++) {
    $previewGraphics.DrawImage($runFrames[$index], [System.Drawing.Rectangle]::new(($index % 5) * $canvas, 2 * $canvas + [math]::Floor($index / 5) * $canvas, $canvas, $canvas))
}
$preview.Save((Join-Path $root 'assets/animals/dogs/shiba/shiba_animation_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$previewGraphics.Dispose(); $preview.Dispose()

foreach ($frame in $runFrames) { $frame.Dispose() }
foreach ($frame in $actions.Values) { $frame.Dispose() }
$runSource.Dispose(); $actionSource.Dispose()
