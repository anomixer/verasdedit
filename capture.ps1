$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$src = @'
using System;
using System.Runtime.InteropServices;
public class Win32 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
Add-Type -TypeDefinition $src
$p = Get-Process AppleWin -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { Write-Output "no process"; exit 1 }
$h = $p.MainWindowHandle
if ($h -eq 0) { Write-Output "no window handle"; exit 1 }
$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($h, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$ht = $rect.Bottom - $rect.Top
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$bmp.Save('C:\dev\verasdedit\applewin_shot.png', [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "saved $w x $ht"
