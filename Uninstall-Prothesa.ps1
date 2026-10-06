<#
.SYNOPSIS
  Uninstall ProthesaUtil per-user (pasangan Install-Prothesa.ps1). Tanpa admin.
.DESCRIPTION
  Menghapus shortcut, entri Programs & Features, dan folder install.
  Data dipertahankan (dipindah ke Desktop) kecuali -RemoveData.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Uninstall-Prothesa.ps1
  powershell -ExecutionPolicy Bypass -File .\Uninstall-Prothesa.ps1 -RemoveData
#>
[CmdletBinding()]
param([switch]$RemoveData)
$ErrorActionPreference = 'Stop'
$InstallDir = $PSScriptRoot
if (-not $InstallDir) { $InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host "[Uninstall] ProthesaUtil dari $InstallDir" -ForegroundColor Yellow

# 1. Data: pertahankan (pindah ke Desktop) kecuali diminta hapus.
$dataDir = Join-Path $InstallDir 'data'
if ((Test-Path -LiteralPath $dataDir) -and -not $RemoveData) {
    $keep = Join-Path ([System.Environment]::GetFolderPath('Desktop')) 'ProthesaUtil-data'
    if (Test-Path -LiteralPath $keep) { Remove-Item -LiteralPath $keep -Recurse -Force }
    Move-Item -LiteralPath $dataDir -Destination $keep -Force
    Write-Host "[Uninstall] Data dipindah ke: $keep" -ForegroundColor Green
}

# 2. Shortcut.
foreach ($n in @('Prothesa Util.lnk', 'Uninstall Prothesa Util.lnk', 'Prothesa Util GUI.lnk', 'Prothesa Manager.lnk')) {
    $p = Join-Path ([System.Environment]::GetFolderPath('Desktop')) $n
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}

# 3. Entri Programs & Features.
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProthesaUtil'
if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }

# 4. Folder install.
if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $InstallDir) {
        Write-Warning '[Uninstall] Folder masih terkunci (tutup dulu aplikasinya), hapus manual bila perlu.'
    } else {
        Write-Host '[Uninstall] Selesai.' -ForegroundColor Green
    }
}
