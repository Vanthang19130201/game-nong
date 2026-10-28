Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sourcePath = Join-Path $root 'assets/animals/dogs/shiba/shiba_poses.png'
$outputDir = Join-Path $root 'assets/animals/dogs/shiba/animations'
$source = [System.Drawing.Bitmap]::new($sourcePath)
$baseline = 108

# Do not use pose cells 3, 7, or 15: the original board clips their right edge.
$animations = [ordered]@{
    idle      = @(0, 0, 0, 0, 0, 0)
    blink     = @(0, 1, 1, 0)
    walk      = @(2, 4, 5, 6, 2, 4, 5, 6)
    run       = @(6, 4, 5, 6, 4, 5, 6, 4)
    sit       = @(0, 8, 8, 8, 8)
    sit_idle  = @(8, 8, 8, 8)
    lie_down  = @(8, 9, 9, 9, 9, 9)
    lie_idle  = @(9, 9, 9, 9)
    sleep     = @(10, 10, 10, 10, 10, 10)
    wake_up   = @(10, 9, 8, 0, 0, 0)
    eat       = @(11, 11, 11, 11, 11, 11, 11, 11)
    happy     = @(12, 12, 0, 12, 0, 12)
    sniff     = @(13, 13, 13, 0, 13, 0)
    scratch   = @(14, 14, 14, 0, 14, 0, 14, 0)
    shake     = @(0, 2, 0, 4, 0, 2, 0, 4)
    alert     = @(0, 2, 0, 2, 0)
}

function Get-SourceBounds([int]$cellIndex) {
    $column = $cellIndex % 4; $row = [math]::Floor($cellIndex / 4)
    $originX = [math]::Floor($column * $source.Width / 4.0)
    $originY = [math]::Floor($row * $source.Height / 4.0)
    $endX = [math]::Floor(($column + 1) * $source.Width / 4.0) - 1
    $endY = [math]::Floor(($row + 1) * $source.Height / 4.0) - 1
    $cellWidth = $endX - $originX + 1; $cellHeight = $endY - $originY + 1
    $minX = $cellWidth; $minY = $cellHeight; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $cellHeight; $y++) {
        for ($x = 0; $x -lt $cellWidth; $x++) {
            if ($source.GetPixel($originX + $x, $originY + $y).A -gt 8) {
                $minX = [math]::Min($minX, $x); $minY = [math]::Min($minY, $y)
                $maxX = [math]::Max($maxX, $x); $maxY = [math]::Max($maxY, $y)
            }
        }
    }
    if ($maxX -lt 0) { throw "No visible Shiba pixels in pose cell $cellIndex." }
    $pad = 4
    $left = [math]::Max(0, $minX - $pad); $top = [math]::Max(0, $minY - $pad)
    $right = [math]::Min($cellWidth - 1, $maxX + $pad); $bottom = [math]::Min($cellHeight - 1, $maxY + $pad)
    return [System.Drawing.Rectangle]::new($originX + $left, $originY + $top, $right - $left + 1, $bottom - $top + 1)
}

function Draw-Cell([System.Drawing.Graphics]$graphics, [int]$cellIndex, [int]$destinationX) {
    $sourceBounds = Get-SourceBounds $cellIndex
    $maxWidth = 116.0; $maxHeight = 104.0
    $scale = [math]::Min($maxWidth / $sourceBounds.Width, $maxHeight / $sourceBounds.Height)
    $drawWidth = [math]::Max(1, [math]::Round($sourceBounds.Width * $scale))
    $drawHeight = [math]::Max(1, [math]::Round($sourceBounds.Height * $scale))
    $destinationY = $baseline - $drawHeight
    $destination = [System.Drawing.Rectangle]::new($destinationX + [math]::Round((128 - $drawWidth) / 2.0), $destinationY, $drawWidth, $drawHeight)
    $graphics.DrawImage($source, $destination, $sourceBounds, [System.Drawing.GraphicsUnit]::Pixel)
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
foreach ($entry in $animations.GetEnumerator()) {
    $strip = [System.Drawing.Bitmap]::new(128 * $entry.Value.Count, 128, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($strip)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    for ($frame = 0; $frame -lt $entry.Value.Count; $frame++) {
        Draw-Cell $graphics $entry.Value[$frame] (128 * $frame)
    }
    $strip.Save((Join-Path $outputDir ("shiba_{0}.png" -f $entry.Key)), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $strip.Dispose()
}

$preview = [System.Drawing.Bitmap]::new(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
$previewGraphics.Clear([System.Drawing.Color]::Transparent)
$index = 0
foreach ($entry in $animations.GetEnumerator()) {
    $stripPath = Join-Path $outputDir ("shiba_{0}.png" -f $entry.Key)
    $strip = [System.Drawing.Bitmap]::new($stripPath)
    $destination = [System.Drawing.Rectangle]::new(($index % 4) * 128, [math]::Floor($index / 4) * 128, 128, 128)
    $previewGraphics.DrawImage($strip, $destination, [System.Drawing.Rectangle]::new(0, 0, 128, 128), [System.Drawing.GraphicsUnit]::Pixel)
    $strip.Dispose(); $index++
}
$preview.Save((Join-Path $root 'assets/animals/dogs/shiba/shiba_animation_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$previewGraphics.Dispose(); $preview.Dispose()
$source.Dispose()
