<#
.SYNOPSIS
  Dijalankan installer setelah copy file: tulis marker + config, opsional pasang sampel terenkripsi.
  Dipanggil: powershell -ExecutionPolicy Bypass -File Seed-Sample.ps1 -AppDir "{app}" [-NoSample]
#>
[CmdletBinding()]
param([string]$AppDir = '', [switch]$NoSample)
$ErrorActionPreference = 'Stop'
if (-not $AppDir) { $AppDir = $PSScriptRoot }
if (-not $AppDir) { $AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$dataDir = Join-Path $AppDir 'data'
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
if (-not $NoSample) {
    . (Join-Path $AppDir 'ProthesaDataVault.ps1')
    $bundle = Find-ProthesaBundle $AppDir
    if ($bundle) {
        $r = Install-ProthesaSample -BundleFile $bundle.FullName -BasePath $dataDir
        Write-Host ("[Seed] Sampel dipasang: " + $r.Path)
    } else {
        Write-Host '[Seed] Tanpa bundel sampel.'
    }
} else {
    Write-Host '[Seed] Sampel dilewati.'
}
@{ base_path = $dataDir; auto_update_after_copy = $false } | ConvertTo-Json |
    Set-Content -LiteralPath (Join-Path $AppDir 'ProthesaConfig.json') -Encoding UTF8
[ordered]@{
    app          = 'ProthesaUtil'
    method       = 'inno-setup'
    installed_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    developer    = 'Ridwan Gatro (RidTheWann)'
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $AppDir 'installed.json') -Encoding UTF8
Write-Host '[Seed] Marker + config ditulis.'
