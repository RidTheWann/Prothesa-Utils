# Update Shortcuts to use the proper launchers (Pure PowerShell)
$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath("Desktop")

try {
    # 1. Update Prothesa Util GUI Shortcut
    $ShortcutUtil = $WshShell.CreateShortcut("$DesktopPath\Prothesa Util GUI.lnk")
    $ShortcutUtil.TargetPath = "$PSScriptRoot\JALANKAN PROTHESA UTIL.bat"
    $ShortcutUtil.WorkingDirectory = $PSScriptRoot
    $ShortcutUtil.IconLocation = "shell32.dll, 21"
    $ShortcutUtil.Save()

    # 2. Update Prothesa Manager Shortcut
    $ShortcutManager = $WshShell.CreateShortcut("$DesktopPath\Prothesa Manager.lnk")
    $ShortcutManager.TargetPath = "$PSScriptRoot\JALANKAN MANAGER.bat"
    $ShortcutManager.WorkingDirectory = $PSScriptRoot
    $ShortcutManager.IconLocation = "shell32.dll, 3"
    $ShortcutManager.Save()

    # Hapus shortcut Dashboard lama jika masih ada
    $oldDashShortcut = "$DesktopPath\Prothesa Dashboard.lnk"
    if (Test-Path -LiteralPath $oldDashShortcut) {
        Remove-Item -LiteralPath $oldDashShortcut -Force -ErrorAction SilentlyContinue
    }

    Write-Host "✅ Shortcut Desktop telah diperbarui (Prothesa Util GUI & Manager)!" -ForegroundColor Green
} finally {
    if ($null -ne $WshShell) {
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($WshShell) | Out-Null
    }
}
