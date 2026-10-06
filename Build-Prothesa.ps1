<#
.SYNOPSIS
  Build software ProthesaUtil 100% PowerShell — portable ZIP GitHub-clean.
.DESCRIPTION
  Reverse-engineered dari kebutuhan repo publik: staging HANYA berisi file aman
  (allowlist), data pasien A=/B=/C=, prothesa-status.json, ProthesaConfig.json,
  template asli (*.doc/*.xlsx), dan PACK-PROTHESA TIDAK PERNAH ikut.
  Tanpa dependensi eksternal (hanya Compress-Archive bawaan Windows).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Build-Prothesa.ps1
  powershell -ExecutionPolicy Bypass -File .\Build-Prothesa.ps1 -VerifyGitClean
#>
[CmdletBinding()]
param(
    [string]$OutDir = '',
    [switch]$VerifyGitClean,
    [switch]$SkipZip,
    [switch]$MakeExe
)
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $OutDir) { $OutDir = Join-Path $Root 'dist' }
$VersionFile = Join-Path $Root 'Prothesa.version.json'
$Version = 'dev'
try {
    if (Test-Path -LiteralPath $VersionFile) {
        $Version = (Get-Content -Raw -LiteralPath $VersionFile | ConvertFrom-Json).version
    }
} catch { $Version = 'dev' }

function Test-Syntax($Path) {
    $errs = $null; $toks = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$toks, [ref]$errs)
    if ($errs.Count -gt 0) { throw "Syntax error di $Path : $($errs[0].Message)" }
}

Write-Host "[Build] ProthesaUtil v$Version" -ForegroundColor Cyan
Test-Syntax (Join-Path $Root 'ProthesaManager.ps1')
Test-Syntax (Join-Path $Root 'ProthesaWinUtil.ps1')
Test-Syntax $PSCommandPath
Write-Host '[Build] Syntax OK (Manager + WinUtil).' -ForegroundColor Green

# Allowlist file aman untuk repo publik / portable.
$SafeFiles = @(
    'ProthesaWinUtil.ps1', 'ProthesaManager.ps1', 'ProthesaDataVault.ps1',
    'Build-Prothesa.ps1', 'Install-Prothesa.ps1', 'Uninstall-Prothesa.ps1',
    'Merge-Prothesa.ps1', 'Build-Setup.ps1',
    'JALANKAN PROTHESA UTIL.bat', 'JALANKAN MANAGER.bat',
    'BUAT-SHORTCUT-DESKTOP.ps1', 'UPDATE-SHORTCUT.ps1',
    'README.md', 'ProthesaConfig.default.json', 'Prothesa.version.json',
    '.gitignore', '.gitmodules.example'
)
$SafeTemplates = @('_TEMPLATES\README.md', '_TEMPLATES\.gitkeep')

if ($VerifyGitClean -and (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '[Build] Verifikasi git check-ignore untuk data sensitif...' -ForegroundColor Yellow
    $Sensitive = @('A=PROTHESA 2024', 'B=PROTHESA 2025', 'C=PROTHESA 2026', 'prothesa-status.json', 'ProthesaConfig.json', 'PACK-PROTHESA') |
        Where-Object { Test-Path -LiteralPath (Join-Path $Root $_) }
    $Leak = @()
    foreach ($s in $Sensitive) {
        $p = Join-Path $Root $s
        $out = git -C $Root check-ignore -q $p 2>&1
        if ($LASTEXITCODE -ne 0) { $Leak += $s }
    }
    # Template asli harus ter-ignore, placeholder harus TIDAK ter-ignore.
    foreach ($t in @('_TEMPLATES\Administrasi Klaim TEMPLATE.xlsx', '_TEMPLATES\REKAP PROTHESA TEMPLATE.doc')) {
        $p = Join-Path $Root $t
        if (Test-Path -LiteralPath $p) {
            git -C $Root check-ignore -q $p 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $Leak += $t }
        }
    }
    if ($Leak.Count -gt 0) { throw "[Build] BOCOR: file sensitif tidak ter-ignore: $($Leak -join ', '). Perbaiki .gitignore dulu." }
    Write-Host '[Build] Git-clean OK: data sensitif ter-ignore.' -ForegroundColor Green
} elseif ($VerifyGitClean) {
    Write-Warning '[Build] git tidak ditemukan, lewati verifikasi git (allowlist tetap dipakai).'
}

$Staging = Join-Path $OutDir 'staging'
if (Test-Path -LiteralPath $Staging) { Remove-Item -LiteralPath $Staging -Recurse -Force }
New-Item -ItemType Directory -Path $Staging | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging '_TEMPLATES') | Out-Null

foreach ($f in $SafeFiles) {
    $src = Join-Path $Root $f
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $Staging $f) -Force }
    else { Write-Warning "[Build] allowlist hilang (skip): $f" }
}
foreach ($t in $SafeTemplates) {
    $src = Join-Path $Root $t
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $Staging $t) -Force }
}
$instStage = Join-Path $Staging 'installer'
New-Item -ItemType Directory -Path $instStage | Out-Null
foreach ($f in @('installer\ProthesaUtil.iss', 'installer\Seed-Sample.ps1')) {
    $src = Join-Path $Root $f
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $Staging $f) -Force }
}

# Smoke test headless: dot-source manager + scan di sandbox (isolasi %TEMP%).
Write-Host '[Build] Smoke test headless (Export-StatusJson di sandbox)...' -ForegroundColor Yellow
$env:PROTHESA_SKIP_MENU = '1'
. (Join-Path $Root 'ProthesaManager.ps1')
Remove-Item Env:PROTHESA_SKIP_MENU -ErrorAction SilentlyContinue
$Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('prothesa-build-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Sandbox | Out-Null
$OldBase = $Script:BasePath
try {
    $Script:BasePath = $Sandbox
    if (-not (Test-ArchiveEmpty)) { throw 'Smoke: sandbox seharusnya kosong.' }
    Export-StatusJson | Out-Null
    $sj = Join-Path $Sandbox 'prothesa-status.json'
    if (-not (Test-Path -LiteralPath $sj)) { throw 'Smoke: prothesa-status.json tidak terbentuk.' }
    Write-Host '[Build] Smoke OK (arsip kosong + scan jalan).' -ForegroundColor Green
} finally {
    $Script:BasePath = $OldBase
    Remove-Item -LiteralPath $Sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

$ZipPath = $null
if (-not $SkipZip) {
    $ZipPath = Join-Path $OutDir ("ProthesaUtil-v$Version-portable.zip")
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    Compress-Archive -Path (Join-Path $Staging '*') -DestinationPath $ZipPath -CompressionLevel Optimal
    $mb = [math]::Round((Get-Item -LiteralPath $ZipPath).Length / 1MB, 2)
    Write-Host "[Build] Portable ZIP: $ZipPath ($mb MB)" -ForegroundColor Green
}

@{ name = 'ProthesaUtil'; version = $Version; built_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); zip = $ZipPath } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutDir 'build-info.json') -Encoding UTF8

if ($MakeExe) {
    Write-Host '[Build] Merge single-file + compile EXE (ps2exe, STA/x64/noConsole)...' -ForegroundColor Yellow
    $mergeScript = Join-Path $Root 'Merge-Prothesa.ps1'
    if (-not (Test-Path -LiteralPath $mergeScript)) { throw '[Build] Merge-Prothesa.ps1 tidak ditemukan.' }
    & $mergeScript
    if (-not (Get-Module -ListAvailable ps2exe)) { throw '[Build] Modul ps2exe belum di-install (Install-Module ps2exe -Scope CurrentUser).' }
    Import-Module ps2exe -Force
    Invoke-PS2EXE -inputFile (Join-Path $OutDir 'ProthesaUtil-merged.ps1') `
        -outputFile (Join-Path $OutDir 'ProthesaUtil.exe') `
        -STA -x64 -noConsole -title 'Prothesa Util' `
        -description 'Prothesa Util - drg. Danny Hanggono' -company 'Ridwan Gatro (RidTheWann)' `
        -product 'ProthesaUtil' -version "$Version.0"
    Write-Host '[Build] EXE OK.' -ForegroundColor Green
}

Write-Host '[Build] Selesai.' -ForegroundColor Green
