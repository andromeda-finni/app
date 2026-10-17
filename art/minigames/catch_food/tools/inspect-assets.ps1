param(
  [string]$AssetDirectory = (Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class AssetInspector {
  public static object Inspect(string path) {
    using (var original = new Bitmap(path))
    using (var bmp = original.Clone(new Rectangle(0, 0, original.Width, original.Height), PixelFormat.Format32bppArgb)) {
      var data = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      try {
        int length = Math.Abs(data.Stride) * bmp.Height;
        byte[] bytes = new byte[length];
        Marshal.Copy(data.Scan0, bytes, 0, length);
        int minX=bmp.Width, minY=bmp.Height, maxX=-1, maxY=-1;
        long transparent=0, partial=0, opaque=0;
        for (int y=0;y<bmp.Height;y++) {
          int row = data.Stride >= 0 ? y*data.Stride : (bmp.Height-1-y)*(-data.Stride);
          for(int x=0;x<bmp.Width;x++) {
            byte a=bytes[row+x*4+3];
            if(a==0) transparent++; else if(a==255) opaque++; else partial++;
            if(a>8) {minX=Math.Min(minX,x);minY=Math.Min(minY,y);maxX=Math.Max(maxX,x);maxY=Math.Max(maxY,y);}
          }
        }
        return new {
          width=bmp.Width, height=bmp.Height,
          transparentPixels=transparent, partialAlphaPixels=partial, opaquePixels=opaque,
          hasTransparency=transparent>0,
          visibleBounds=new {left=minX,top=minY,right=maxX,bottom=maxY},
          touchesEdge=maxX>=0 && (minX==0 || minY==0 || maxX==bmp.Width-1 || maxY==bmp.Height-1)
        };
      } finally {bmp.UnlockBits(data);}
    }
  }
}
'@ -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core,System.Collections
$manifestPath = Join-Path $AssetDirectory 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$report = @()
foreach ($asset in $manifest.assets) {
  $path = Join-Path $AssetDirectory $asset.file
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing asset: $($asset.file)" }
  $info = [AssetInspector]::Inspect($path)
  $passed = $info.width -gt 0 -and $info.height -gt 0 -and $info.visibleBounds.right -ge $info.visibleBounds.left -and $info.visibleBounds.bottom -ge $info.visibleBounds.top
  if ($asset.dimensions -and ($info.width -ne $asset.dimensions.width -or $info.height -ne $asset.dimensions.height)) { $passed = $false }
  if (-not (Test-Path -LiteralPath (Join-Path $AssetDirectory $asset.prompt))) { $passed = $false }
  foreach ($reference in $asset.referenceImages) {
    if (-not (Test-Path -LiteralPath (Join-Path $AssetDirectory $reference))) { $passed = $false }
  }
  if ($asset.transparent -and -not $info.hasTransparency) { $passed = $false }
  if (-not $asset.transparent -and $info.hasTransparency) { $passed = $false }
  if ($asset.transparent -and $info.touchesEdge) { $passed = $false }
  $report += [pscustomobject]@{file=$asset.file; passed=$passed; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant(); info=$info}
}
$result = [pscustomobject]@{
  checkedAt=(Get-Date).ToUniversalTime().ToString('o')
  expectedCount=$manifest.assets.Count
  actualPngCount=@(Get-ChildItem -LiteralPath $AssetDirectory -Filter '*.png' -File).Count
  allPassed=(@($report | Where-Object {-not $_.passed}).Count -eq 0)
  assets=$report
}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $AssetDirectory 'validation.json') -Encoding utf8
$result | Select-Object expectedCount,actualPngCount,allPassed
$report | Select-Object file,passed,@{n='size';e={"$($_.info.width)x$($_.info.height)"}},@{n='alpha';e={$_.info.hasTransparency}},@{n='edge';e={$_.info.touchesEdge}} | Format-Table -AutoSize
if (-not $result.allPassed -or $result.expectedCount -ne $result.actualPngCount) { exit 1 }
