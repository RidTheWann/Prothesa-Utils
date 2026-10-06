# Script untuk membuat shortcut di Desktop (100% PowerShell)
$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath("Desktop")

try {
    # 1. Shortcut Prothesa Util GUI (Modern Desktop WinForms)
    $ShortcutUtil = $WshShell.CreateShortcut("$DesktopPath\Prothesa Util GUI.lnk")
    $ShortcutUtil.TargetPath = "$PSScriptRoot\JALANKAN PROTHESA UTIL.bat"
    $ShortcutUtil.WorkingDirectory = $PSScriptRoot
    $ShortcutUtil.IconLocation = "shell32.dll, 21"
    $ShortcutUtil.Save()

    # 2. Shortcut Prothesa Manager (Terminal CLI)
    $ShortcutManager = $WshShell.CreateShortcut("$DesktopPath\Prothesa Manager.lnk")
    $ShortcutManager.TargetPath = "$PSScriptRoot\JALANKAN MANAGER.bat"
    $ShortcutManager.WorkingDirectory = $PSScriptRoot
    $ShortcutManager.IconLocation = "shell32.dll, 3"
    $ShortcutManager.Save()

    Write-Host "✅ Shortcut Desktop berhasil dibuat (Prothesa Util GUI & Prothesa Manager)!" -ForegroundColor Green
} finally {
    if ($null -ne $WshShell) {
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($WshShell) | Out-Null
    }
}
