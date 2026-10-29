param([string]$OnlyAction = '')

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$sourceRoot = Join-Path $root 'assets/animals/dogs/shiba/from_uploaded/actions_part2_redone'
$outputRoot = Join-Path $root 'assets/animals/dogs/shiba/animations'
$canvas = 256
$safeMargin = 24
$groundY = 210

# Counts/order are detected from the ZIP by whole-body connected components.
# x = one deliberate left-to-right row; row = top row then bottom row.
$actions = @(
	[pscustomobject]@{ Name='sleep'; File='sleep.png'; Width=1672; Height=941; Frames=6; Order='x'; Scale=0.65 },
	[pscustomobject]@{ Name='wake_up'; File='wake_up.png'; Width=1672; Height=941; Frames=6; Order='x'; Scale=0.50 },
	[pscustomobject]@{ Name='eat'; File='eat.png'; Width=1448; Height=1086; Frames=8; Order='row'; Scale=0.46 },
	[pscustomobject]@{ Name='happy'; File='happy.png'; Width=1672; Height=941; Frames=6; Order='x'; Scale=0.55 },
	[pscustomobject]@{ Name='sniff'; File='sniff.png'; Width=1672; Height=941; Frames=6; Order='x'; Scale=0.58 },
	[pscustomobject]@{ Name='scratch'; File='scratch.png'; Width=1448; Height=1086; Frames=8; Order='row'; Scale=0.45 },
	[pscustomobject]@{ Name='shake'; File='shake.png'; Width=1448; Height=1086; Frames=8; Order='row'; Scale=0.46 },
	[pscustomobject]@{ Name='alert'; File='alert.png'; Width=1672; Height=941; Frames=6; Order='x'; Scale=0.50 }
)
if ($OnlyAction) { $actions = @($actions | Where-Object { $_.Name -eq $OnlyAction }); if ($actions.Count -ne 1) { throw "Unknown action: $OnlyAction" } }

function Get-Digest([string]$Path) {
	if (-not (Test-Path -LiteralPath $Path)) { throw "Protected asset missing: $Path" }
	return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Get-DirectoryDigest([string]$Path) {
	if (-not (Test-Path -LiteralPath $Path)) { throw "Protected directory missing: $Path" }
	return ((Get-ChildItem -LiteralPath $Path -Filter '*.png' -File | Sort-Object Name | ForEach-Object { "$( $_.Name ):$(Get-Digest $_.FullName)" }) -join "`n")
}
function Get-DogComponents([System.Drawing.Bitmap]$Source, [string]$Order) {
	$w=$Source.Width; $h=$Source.Height
	$active=[bool[]]::new($w*$h); $seen=[bool[]]::new($w*$h)
	for($y=0;$y-lt$h;$y++){for($x=0;$x-lt$w;$x++){$active[$y*$w+$x]=$Source.GetPixel($x,$y).A -gt 32}}
	$dogs=[System.Collections.Generic.List[object]]::new()
	for($seed=0;$seed-lt$active.Length;$seed++){
		if(-not $active[$seed] -or $seen[$seed]){continue}
		$q=[System.Collections.Generic.Queue[int]]::new();$q.Enqueue($seed);$seen[$seed]=$true
		$area=0;$minX=$w;$minY=$h;$maxX=-1;$maxY=-1
		while($q.Count){
			$current=$q.Dequeue();$area++;$x=$current%$w;$y=[math]::Floor($current/$w)
			$minX=[math]::Min($minX,$x);$minY=[math]::Min($minY,$y);$maxX=[math]::Max($maxX,$x);$maxY=[math]::Max($maxY,$y)
			for($dy=-1;$dy-le1;$dy++){for($dx=-1;$dx-le1;$dx++){
				if($dx-eq0 -and $dy-eq0){continue};$nx=$x+$dx;$ny=$y+$dy
				if($nx-lt0 -or $ny-lt0 -or $nx-ge$w -or $ny-ge$h){continue};$next=$ny*$w+$nx
				if($active[$next] -and -not $seen[$next]){$seen[$next]=$true;$q.Enqueue($next)}
			}}
		}
		# Effects (Z, hearts, alert/motion marks) are separate, much smaller
		# components. The game supplies those effects at runtime.
		if($area-ge10000){$dogs.Add([pscustomobject]@{Area=$area;Bounds=[Drawing.Rectangle]::FromLTRB($minX,$minY,$maxX+1,$maxY+1)})}
	}
	if($Order-eq'x'){return @($dogs|Sort-Object {$_.Bounds.Left})}
	return @($dogs|Sort-Object {$_.Bounds.Top},{$_.Bounds.Left})
}
function Test-SafeFrame([System.Drawing.Bitmap]$Frame,[string]$Label){
	$minX=$canvas;$minY=$canvas;$maxX=-1;$maxY=-1
	for($y=0;$y-lt$canvas;$y++){for($x=0;$x-lt$canvas;$x++){if($Frame.GetPixel($x,$y).A-gt26){$minX=[math]::Min($minX,$x);$minY=[math]::Min($minY,$y);$maxX=[math]::Max($maxX,$x);$maxY=[math]::Max($maxY,$y)}}}
	if($maxX-lt0 -or $minX-lt$safeMargin -or $minY-lt$safeMargin -or $maxX-ge($canvas-$safeMargin) -or $maxY-ge($canvas-$safeMargin)){throw "Cropped or contaminated ${Label}: ($minX,$minY)-($maxX,$maxY)"}
}
function New-Frame([System.Drawing.Bitmap]$Source,[Drawing.Rectangle]$Body,[float]$Scale,[string]$Label){
	# Four pixels of source padding preserve outline/ear/tail edge pixels; the
	# source background is already transparent, so a crop never includes a panel.
	$pad=4;$crop=[Drawing.Rectangle]::FromLTRB([math]::Max(0,$Body.Left-$pad),[math]::Max(0,$Body.Top-$pad),[math]::Min($Source.Width,$Body.Right+$pad),[math]::Min($Source.Height,$Body.Bottom+$pad))
	$frame=[Drawing.Bitmap]::new($canvas,$canvas,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g=[Drawing.Graphics]::FromImage($frame);$g.Clear([Drawing.Color]::Transparent);$g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::NearestNeighbor;$g.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::Half;$g.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy
	$tw=[math]::Round($crop.Width*$Scale);$th=[math]::Round($crop.Height*$Scale);$target=[Drawing.Rectangle]::new([math]::Round(($canvas-$tw)*0.5),$groundY-$th,$tw,$th)
	$g.DrawImage($Source,$target,$crop,[Drawing.GraphicsUnit]::Pixel);$g.Dispose();Test-SafeFrame $frame $Label;return $frame
}

# Part 1 and RUN must never move during this action-only rebuild.
$protected=@('shiba_run.png','shiba_idle.png','shiba_blink.png','shiba_walk.png','shiba_sit.png','shiba_sit_idle.png','shiba_lie_down.png','shiba_lie_idle.png')
$before=@{};foreach($asset in $protected){$before[$asset]=Get-Digest (Join-Path $outputRoot $asset)}
$protectedDirs=@('run','idle','idle_blink','walk','sit','sit_idle','lie_down','lie_idle');foreach($dir in $protectedDirs){$before["dir:${dir}"]=Get-DirectoryDigest (Join-Path $outputRoot $dir)}

foreach($action in $actions){
	$source=[Drawing.Bitmap]::new((Join-Path $sourceRoot $action.File))
	if($source.Width-ne$action.Width -or $source.Height-ne$action.Height){throw "Unexpected dimensions for $($action.Name)"}
	$dogs=Get-DogComponents $source $action.Order
	if($dogs.Count-ne$action.Frames){throw "$($action.Name): found $($dogs.Count) dogs, expected $($action.Frames)"}
	$folder=Join-Path $outputRoot $action.Name;New-Item -ItemType Directory -Path $folder -Force|Out-Null
	Get-ChildItem -LiteralPath $folder -Filter "shiba_$($action.Name)_*.png" -File -ErrorAction SilentlyContinue|Remove-Item -Force
	$frames=[System.Collections.Generic.List[System.Drawing.Bitmap]]::new();$hashes=[System.Collections.Generic.HashSet[string]]::new()
	for($i=0;$i-lt$dogs.Count;$i++){
		$frame=New-Frame $source $dogs[$i].Bounds $action.Scale ("{0}_{1:D2}"-f$action.Name,($i+1));$path=Join-Path $folder ("shiba_{0}_{1:D2}.png"-f$action.Name,($i+1));$frame.Save($path,[Drawing.Imaging.ImageFormat]::Png);$hashes.Add((Get-Digest $path))|Out-Null;$frames.Add($frame)
	}
	if($hashes.Count-lt2){throw "$($action.Name) does not contain distinct source frames"}
	$strip=[Drawing.Bitmap]::new($canvas*$frames.Count,$canvas,[Drawing.Imaging.PixelFormat]::Format32bppArgb);$g=[Drawing.Graphics]::FromImage($strip);$g.Clear([Drawing.Color]::Transparent);for($i=0;$i-lt$frames.Count;$i++){$g.DrawImageUnscaled($frames[$i],$i*$canvas,0)};$strip.Save((Join-Path $outputRoot "shiba_$($action.Name).png"),[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$strip.Dispose();foreach($frame in $frames){$frame.Dispose()};$source.Dispose();Write-Output "$($action.Name): $($dogs.Count) extracted frames"
}
foreach($asset in $protected){if((Get-Digest (Join-Path $outputRoot $asset))-ne$before[$asset]){throw "Protected animation changed: $asset"}}
foreach($dir in $protectedDirs){if((Get-DirectoryDigest (Join-Path $outputRoot $dir))-ne$before["dir:${dir}"]){throw "Protected frames changed: $dir"}}
Write-Output 'Rebuilt only the eight Part 2 actions from the redone ZIP.'
