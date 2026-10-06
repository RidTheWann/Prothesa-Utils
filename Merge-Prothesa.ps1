<#
.SYNOPSIS
  Gabung ProthesaWinUtil.ps1 + ProthesaManager.ps1 menjadi single-file PS (EXE-safe).
.DESCRIPTION
  100% PowerShell. Mengganti blok dot-source dengan isi Manager inline,
  plus patch $ScriptRoot sadar-EXE dan nonaktifkan STA-relaunch di dalam EXE.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Merge-Prothesa.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile = ''
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $OutFile) { $OutFile = Join-Path $Root 'dist\ProthesaUtil-merged.ps1' }

$winPath = Join-Path $Root 'ProthesaWinUtil.ps1'
$manPath = Join-Path $Root 'ProthesaManager.ps1'
$verPath = Join-Path $Root 'Prothesa.version.json'
$Version = 'dev'
try { $Version = (Get-Content -Raw -LiteralPath $verPath | ConvertFrom-Json).version } catch { }

$win = Get-Content -Raw -LiteralPath $winPath
$man = Get-Content -Raw -LiteralPath $manPath
$vaultPath = Join-Path $Root 'ProthesaDataVault.ps1'
$vault = if (Test-Path -LiteralPath $vaultPath) { Get-Content -Raw -LiteralPath $vaultPath } else { '' }

# 1. Patch $ScriptRoot sadar-EXE.
$oldRoot = '$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }'
$newRoot = @'
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else {
    try {
        $ea = [System.Reflection.Assembly]::GetEntryAssembly().Location
        if ($ea -and $ea -match '\.exe$') { Split-Path -Parent $ea }
        elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
        else { (Get-Location).Path }
    } catch {
        if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
    }
}
'@
if (-not $win.Contains($oldRoot)) { throw 'Merge gagal: pola $ScriptRoot tidak ditemukan (file berubah?).' }
$win = $win.Replace($oldRoot, $newRoot)

# 2. Nonaktifkan STA-relaunch saat berjalan sebagai EXE (EXE sudah di-compile -STA).
$oldRelaunch = "if (-not (`$env:PROTHESA_NO_RELAUNCH -eq '1') -and [System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {"
$newRelaunch = @'
$isExeHost = $false
try { $eal = [System.Reflection.Assembly]::GetEntryAssembly().Location; if ($eal -match '\.exe$') { $isExeHost = $true } } catch { }
if (-not $isExeHost -and -not ($env:PROTHESA_NO_RELAUNCH -eq '1') -and [System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
'@
if (-not $win.Contains($oldRelaunch)) { throw 'Merge gagal: pola STA-relaunch tidak ditemukan.' }
$win = $win.Replace($oldRelaunch, $newRelaunch)

# 3. Ganti blok dot-source dengan isi Manager inline.
$oldDot = @'
$env:PROTHESA_SKIP_MENU = '1'
$managerPath = Join-Path $ScriptRoot 'ProthesaManager.ps1'
if (-not (Test-Path -LiteralPath $managerPath)) { throw "ProthesaManager.ps1 tidak ditemukan di: $ScriptRoot" }
. $managerPath
Remove-Item Env:PROTHESA_SKIP_MENU -ErrorAction SilentlyContinue
'@
if (-not $win.Contains($oldDot)) { throw 'Merge gagal: blok dot-source tidak ditemukan.' }
$mergedManager = @'
$env:PROTHESA_SKIP_MENU = '1'
# ===== BEGIN MERGED ProthesaDataVault.ps1 (jangan edit manual; edit file aslinya lalu re-merge) =====
'@
$mergedManager += "`r`n" + $vault.Trim() + "`r`n"
$mergedManager += @'
# ===== END MERGED ProthesaDataVault.ps1 =====
# ===== BEGIN MERGED ProthesaManager.ps1 (jangan edit manual; edit file aslinya lalu re-merge) =====
'@
$mergedManager += "`r`n" + $man.Trim() + "`r`n"
$mergedManager += @'
# ===== END MERGED ProthesaManager.ps1 =====
Remove-Item Env:PROTHESA_SKIP_MENU -ErrorAction SilentlyContinue
'@
$win = $win.Replace($oldDot, $mergedManager)

# 4. Penegakan wajib-install khusus host EXE (dev .ps1 / smoke tidak diblokir).
$enforceAnchor = '$form = Build-Main'
if (-not $win.Contains($enforceAnchor)) { throw 'Merge gagal: anchor Build-Main tidak ditemukan.' }
$enforceBlock = @'
# ===== WAJIB INSTALL (exe-only) =====
if ($isExeHost -and $env:PROTHESA_DEV -ne '1' -and $env:PROTHESA_SMOKE -ne '1' -and -not (Test-ProthesaInstalled)) {
    try {
        [void][System.Windows.Forms.MessageBox]::Show('Prothesa Util harus dipasang via installer (Setup.exe / Install-Prothesa.ps1) dan tidak bisa dijalankan langsung dari file EXE.', 'Prothesa Util - Belum Terinstall', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    } catch { }
    exit 1
}
$form = Build-Main
'@
$win = $win.Replace($enforceAnchor, $enforceBlock)

# 5. EXE-safe: guard semua [Console]::OutputEncoding yang masih telanjang
# (EXE GUI -noConsole tidak punya console handle -> "The handle is invalid").
$win = $win -replace '(?<!try \{ )\[Console\]::OutputEncoding = \[System\.Text\.Encoding\]::UTF8', 'try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }'
# EXE-safe: tidak boleh ada Join-Path/Test-Path dengan $PSScriptRoot telanjang
# ($PSScriptRoot kosong di host ps2exe -> "Cannot bind argument to parameter 'Path'...").
if ($win -match 'Join-Path \$PSScriptRoot|Test-Path[^\n]*\$PSScriptRoot') {
    throw 'Merge gagal: masih ada $PSScriptRoot telanjang (pakai Get-AppScriptRoot).'
}

$header = "# ProthesaUtil MERGED single-file v$Version - generated by Merge-Prothesa.ps1. Do not edit manually.`r`n"
$out = $header + $win
$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$out | Set-Content -LiteralPath $OutFile -Encoding UTF8

$errs = $null; $toks = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($OutFile, [ref]$toks, [ref]$errs)
if ($errs.Count -gt 0) { throw "Syntax merged cacat: $($errs[0].Message)" }
$kb = [math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB, 1)
Write-Host "[Merge] OK: $OutFile ($kb KB, v$Version)" -ForegroundColor Green
