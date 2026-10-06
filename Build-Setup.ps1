<#
.SYNOPSIS
  Build Setup.exe Prothesa Util via Inno Setup (tahap: stage -> isi versi -> compile).
.DESCRIPTION
  100% PowerShell sebagai orkestrator. Butuh ISCC.exe (Inno Setup 6). Bila belum ada,
  dicoba install via winget; bila gagal, cetak panduan manual.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Build-Setup.ps1
#>
[CmdletBinding()]
param([string]$OutDir = '')
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$InstDir = Join-Path $Root 'installer'
$Stage = Join-Path $InstDir 'stage'

$ver = 'dev'
try { $ver = (Get-Content -Raw -LiteralPath (Join-Path $Root 'Prothesa.version.json') | ConvertFrom-Json).version } catch { }
Write-Host "[Setup] ProthesaUtil v$ver" -ForegroundColor Cyan

# 1. Stage: EXE + bundel + pendukung (EXE wajib sudah di-build).
$exe = Join-Path $Root 'dist\ProthesaUtil.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "[Setup] EXE belum ada. Jalankan dulu: .\Build-Prothesa.ps1 -MakeExe" }
if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
New-Item -ItemType Directory -Path $Stage | Out-Null
Copy-Item -LiteralPath $exe -Destination (Join-Path $Stage 'ProthesaUtil.exe') -Force
foreach ($f in @('ProthesaDataVault.ps1', 'ProthesaConfig.default.json')) {
    Copy-Item -LiteralPath (Join-Path $Root $f) -Destination (Join-Path $Stage $f) -Force
}
Copy-Item -LiteralPath (Join-Path $InstDir 'Seed-Sample.ps1') -Destination (Join-Path $Stage 'Seed-Sample.ps1') -Force
$bundles = Get-ChildItem -LiteralPath (Join-Path $Root 'dist') -Filter '*.prothesa*' -File -ErrorAction SilentlyContinue
foreach ($b in $bundles) { Copy-Item -LiteralPath $b.FullName -Destination $Stage -Force }
if (-not $bundles) { Write-Warning '[Setup] Tanpa bundel sampel (lanjut tanpa data contoh).' }

# 2. Suntik versi ke .iss.
('#define MyAppVersion "' + $ver + '"') | Set-Content -LiteralPath (Join-Path $InstDir 'app-version.isi') -Encoding ASCII

# 3. Cari ISCC.
function Find-ISCC {
    $cands = @()
    try {
        foreach ($hive in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')) {
            Get-ChildItem -LiteralPath $hive -ErrorAction SilentlyContinue | ForEach-Object {
                try { $loc = (Get-ItemProperty -LiteralPath $_.PsPath -ErrorAction SilentlyContinue).InstallLocation; if ($loc) { $cands += (Join-Path $loc 'ISCC.exe') } } catch { }
            }
        }
    } catch { }
    $cands += @('C:\Program Files (x86)\Inno Setup 6\ISCC.exe', 'C:\Program Files\Inno Setup 6\ISCC.exe')
    $fromPath = (Get-Command ISCC.exe -ErrorAction SilentlyContinue)
    if ($fromPath) { $cands += $fromPath.Source }
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}
$iscc = Find-ISCC
if (-not $iscc) {
    Write-Host '[Setup] ISCC tidak ditemukan, coba install via winget...' -ForegroundColor Yellow
    try {
        $wg = Get-Command winget.exe -ErrorAction Stop
        & $wg.Source install -e --id JRSoftware.InnoSetup --silent --accept-source-agreements --accept-package-agreements
        $iscc = Find-ISCC
    } catch { Write-Warning ("[Setup] winget gagal: " + $_.Exception.Message) }
}
if (-not $iscc) {
    throw "[Setup] Inno Setup 6 belum terinstall. Install manual dari https://jrsoftware.org/isinfo.php lalu jalankan lagi script ini. (Stage sudah siap di: $Stage)"
}

# 4. Compile.
Write-Host ("[Setup] Compile via: " + $iscc) -ForegroundColor Yellow
& $iscc (Join-Path $InstDir 'ProthesaUtil.iss')
$setup = Join-Path $InstDir ("Output\ProthesaUtil-Setup-$ver.exe")
if (-not (Test-Path -LiteralPath $setup)) { throw '[Setup] Output Setup.exe tidak terbentuk.' }
$mb = [math]::Round((Get-Item -LiteralPath $setup).Length / 1MB, 2)
Write-Host ("[Setup] OK: $setup ($mb MB)") -ForegroundColor Green
