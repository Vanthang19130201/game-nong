# Derive transparent render copies without repainting, resizing, or cropping
# the supplied artwork. Original ZIP images remain intact in assets/buildings/v2.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class BuildingPackV2Alpha {
    public static string Prepare(string source, string destination) {
        using (var input = new Bitmap(source))
        using (var bitmap = new Bitmap(input.Width, input.Height, PixelFormat.Format32bppArgb)) {
            using (var graphics = Graphics.FromImage(bitmap)) graphics.DrawImageUnscaled(input, 0, 0);
            int width = bitmap.Width, height = bitmap.Height, count = width * height;
            var bits = bitmap.LockBits(new Rectangle(0,0,width,height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            var pixels = new byte[bits.Stride * height];
            Marshal.Copy(bits.Scan0, pixels, 0, pixels.Length);
            // The market already has its authored transparent/glowing backdrop.
            bool removePaper = pixels[3] == 255;
            var visited = new bool[count];
            var queue = new int[count];
            int head = 0, tail = 0;
            Action<int> add = index => {
                if (visited[index]) return;
                visited[index] = true;
                int p = (index / width) * bits.Stride + (index % width) * 4;
                int b=pixels[p], g=pixels[p+1], r=pixels[p+2];
                if (r >= 232 && g >= 228 && b >= 215 && Math.Max(r,Math.Max(g,b))-Math.Min(r,Math.Min(g,b)) < 35)
                    queue[tail++] = index;
            };
            if (removePaper) {
                for(int x=0;x<width;x++) { add(x); add((height-1)*width+x); }
                for(int y=0;y<height;y++) { add(y*width); add(y*width+width-1); }
                while(head<tail) {
                    int index=queue[head++], x=index%width, y=index/width;
                    pixels[y*bits.Stride+x*4+3]=0;
                    if(x>0) add(index-1); if(x+1<width) add(index+1);
                    if(y>0) add(index-width); if(y+1<height) add(index+width);
                }
            }
            int left=width,top=height,right=-1,bottom=-1;
            for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
                if(pixels[y*bits.Stride+x*4+3]==0) continue;
                left=Math.Min(left,x); top=Math.Min(top,y); right=Math.Max(right,x); bottom=Math.Max(bottom,y);
            }
            Marshal.Copy(pixels,0,bits.Scan0,pixels.Length);
            bitmap.UnlockBits(bits);
            bitmap.Save(destination,ImageFormat.Png);
            return String.Format("{0}: visible Rect2({1}, {2}, {3}, {4}); removed {5} exterior pixels",System.IO.Path.GetFileName(source),left,top,right-left+1,bottom-top+1,tail);
        }
    }
}
'@
$assetRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets/buildings/v2'
$renderRoot = Join-Path $assetRoot 'transparent'
New-Item -ItemType Directory -Path $renderRoot -Force | Out-Null
Get-ChildItem -LiteralPath $assetRoot -Filter '*.png' -File | Sort-Object Name | ForEach-Object {
    [BuildingPackV2Alpha]::Prepare($_.FullName, (Join-Path $renderRoot $_.Name))
}
