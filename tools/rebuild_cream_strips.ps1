Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sourcePath = Join-Path $root 'assets/animals/dogs/cream/cream_poses.png'
$outputDir = Join-Path $root 'assets/animals/dogs/cream/animations'
$source = [System.Drawing.Bitmap]::new($sourcePath)
$frameSize = 160
$safeMargin = 11

# Cells 3, 7 and 15 touch the original board's right edge.  They are never
# used here: every selected source pose has a complete ear, tail and paws.
$animations = [ordered]@{
    idle      = @(0, 0, 0, 0, 0, 0)
    blink     = @(0, 1, 1, 0)
    walk      = @(2, 4, 5, 6, 2, 4, 5, 6)
    run       = @(6, 5, 4, 2, 6, 5, 4, 2)
    sit       = @(0, 8, 8, 8, 8)
    sit_idle  = @(8, 8, 8, 8)
    lie_down  = @(8, 9, 9, 9, 9, 9)
    lie_idle  = @(9, 9, 9, 9)
    sleep     = @(10, 10, 10, 10, 10, 10)
    wake_up   = @(10, 9, 8, 0, 0, 0)
    eat       = @(11, 11, 11, 11, 11, 11, 11, 11)
    happy     = @(12, 12, 0, 12, 0, 12)
    sniff     = @(13, 13, 13, 0, 13, 0)
    scratch   = @(14, 14, 14, 8, 14, 8, 14, 8)
    shake     = @(0, 2, 0, 4, 0, 5, 0, 6)
    alert     = @(0, 2, 0, 2, 0)
}

function Get-CellRectangle([int]$cellIndex) {
    $column = $cellIndex % 4; $row = [math]::Floor($cellIndex / 4)
    $left = [math]::Floor($column * $source.Width / 4.0)
    $right = [math]::Floor(($column + 1) * $source.Width / 4.0)
    $top = [math]::Floor($row * $source.Height / 4.0)
    $bottom = [math]::Floor(($row + 1) * $source.Height / 4.0)
    return [System.Drawing.Rectangle]::new($left, $top, $right - $left, $bottom - $top)
}

function Test-SafeFrame([System.Drawing.Bitmap]$image, [string]$label) {
    $minX = $frameSize; $minY = $frameSize; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $frameSize; $y++) {
        for ($x = 0; $x -lt $frameSize; $x++) {
            if ($image.GetPixel($x, $y).A -gt 26) {
                $minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
                $maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
            }
        }
    }
    if ($maxX -lt 0 -or $minX -lt $safeMargin -or $minY -lt $safeMargin -or $maxX -ge $frameSize - $safeMargin -or $maxY -ge $frameSize - $safeMargin) {
        throw "Cream animation frame is cropped: $label ($minX,$minY)-($maxX,$maxY)"
    }
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$destination = [System.Drawing.Rectangle]::new($safeMargin, $safeMargin, $frameSize - $safeMargin * 2, $frameSize - $safeMargin * 2)
foreach ($entry in $animations.GetEnumerator()) {
    $strip = [System.Drawing.Bitmap]::new($frameSize * $entry.Value.Count, $frameSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($strip)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    for ($frame = 0; $frame -lt $entry.Value.Count; $frame++) {
        $target = [System.Drawing.Rectangle]::new($frame * $frameSize + $destination.X, $destination.Y, $destination.Width, $destination.Height)
        $graphics.DrawImage($source, $target, (Get-CellRectangle $entry.Value[$frame]), [System.Drawing.GraphicsUnit]::Pixel)
        $frameBitmap = $strip.Clone([System.Drawing.Rectangle]::new($frame * $frameSize, 0, $frameSize, $frameSize), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        Test-SafeFrame $frameBitmap ("{0}/{1}" -f $entry.Key, $frame)
        $frameBitmap.Dispose()
    }
    $strip.Save((Join-Path $outputDir ("cream_{0}.png" -f $entry.Key)), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $strip.Dispose()
}

$preview = [System.Drawing.Bitmap]::new(640, 640, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
$previewGraphics.Clear([System.Drawing.Color]::Transparent)
$index = 0
foreach ($entry in $animations.GetEnumerator()) {
    $strip = [System.Drawing.Bitmap]::new((Join-Path $outputDir ("cream_{0}.png" -f $entry.Key)))
    $previewGraphics.DrawImage($strip, [System.Drawing.Rectangle]::new(($index % 4) * $frameSize, [math]::Floor($index / 4) * $frameSize, $frameSize, $frameSize), [System.Drawing.Rectangle]::new(0, 0, $frameSize, $frameSize), [System.Drawing.GraphicsUnit]::Pixel)
    $strip.Dispose(); $index++
}
$preview.Save((Join-Path $root 'assets/animals/dogs/cream/cream_animation_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$previewGraphics.Dispose(); $preview.Dispose(); $source.Dispose()
