<#
.SYNOPSIS
  Install ProthesaUtil per-user 100% PowerShell (tanpa admin).
.DESCRIPTION
  Menyalin EXE (atau .ps1 bila EXE belum ada) + bundel sampel terenkripsi ke InstallDir,
  men-decrypt sampel ke folder data, membuat shortcut Desktop, dan entri Uninstall (HKCU).
  Kunci DPAPI = akun Windows ini (lokal, tanpa password).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\Install-Prothesa.ps1
  powershell -ExecutionPolicy Bypass -File .\Install-Prothesa.ps1 -InstallDir "D:\ProthesaUtil" -NoSample
#>
[CmdletBinding()]
param(
    [string]$InstallDir = '',
    [switch]$NoSample,
    [switch]$NoShortcut,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$SrcRoot = $PSScriptRoot
if (-not $SrcRoot) { $SrcRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $InstallDir) { $InstallDir = Join-Path $env:LocalAppData 'ProthesaUtil' }
$DataDir = Join-Path $InstallDir 'data'

$ver = 'dev'
try { $ver = (Get-Content -Raw -LiteralPath (Join-Path $SrcRoot 'Prothesa.version.json') | ConvertFrom-Json).version } catch { }

Write-Host "[Install] ProthesaUtil v$ver -> $InstallDir" -ForegroundColor Cyan

# Cegah install ganda (kunci milik PS-installer maupun Inno Setup; kecuali -Force).
$alreadyReg = (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProthesaUtil') -or
              (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProthesaUtil_is1') -or
              (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{3F2A1B4C-9D8E-4F7A-8C6B-1A2B3C4D5E6F}_is1')
$alreadyMark = (Test-Path -LiteralPath (Join-Path $InstallDir 'installed.json')) -or
                (Test-Path -LiteralPath (Join-Path $InstallDir '.installed'))
if (($alreadyReg -or $alreadyMark) -and -not $Force) {
    Write-Warning "[Install] Prothesa Util SUDAH terinstall. Uninstall dulu (Uninstall-Prothesa.ps1) atau ulangi dengan -Force untuk timpa."
    exit 1
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
# Penanda wajib-install (dibaca EXE saat startup agar tidak bisa jalan portabel).
"installed=$((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))`r`nversion=$ver`r`nby=Ridwan Gatro (RidTheWann)`r`n" |
    Set-Content -LiteralPath (Join-Path $InstallDir '.installed') -Encoding ASCII

# 1. File aplikasi (EXE diutamakan; fallback mode .ps1 portable).
$exeSrc = Join-Path $SrcRoot 'dist\ProthesaUtil.exe'
if (-not (Test-Path -LiteralPath $exeSrc)) { $exeSrc = Join-Path $SrcRoot 'ProthesaUtil.exe' }
$launchTarget = ''
if (Test-Path -LiteralPath $exeSrc) {
    Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $InstallDir 'ProthesaUtil.exe') -Force
    $launchTarget = Join-Path $InstallDir 'ProthesaUtil.exe'
    Write-Host '[Install] EXE terpasang.' -ForegroundColor Green
} else {
    foreach ($f in @('ProthesaWinUtil.ps1', 'ProthesaManager.ps1', 'ProthesaDataVault.ps1',
        'JALANKAN PROTHESA UTIL.bat', 'JALANKAN MANAGER.bat')) {
        $s = Join-Path $SrcRoot $f
        if (Test-Path -LiteralPath $s) { Copy-Item -LiteralPath $s -Destination (Join-Path $InstallDir $f) -Force }
    }
    $launchTarget = Join-Path $InstallDir 'JALANKAN PROTHESA UTIL.bat'
    Write-Host '[Install] Mode .ps1 portable (EXE belum di-build).' -ForegroundColor Yellow
}

# 2. Vault + uninstaller selalu ikut (mandiri, tahu lokasinya sendiri).
foreach ($f in @('ProthesaDataVault.ps1', 'Uninstall-Prothesa.ps1', 'ProthesaConfig.default.json')) {
    $s = Join-Path $SrcRoot $f
    if (Test-Path -LiteralPath $s) { Copy-Item -LiteralPath $s -Destination (Join-Path $InstallDir $f) -Force }
}

# 2b. Marker resmi terinstall (dibaca EXE untuk penegakan wajib-install).
[ordered]@{
    app       = 'ProthesaUtil'
    version   = $ver
    method    = 'ps-installer'
    installed_at = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    developer = 'Ridwan Gatro (RidTheWann)'
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallDir 'installed.json') -Encoding UTF8

# 3. Config lokal menunjuk ke folder data (tidak menimpa milik user).
$cfgPath = Join-Path $InstallDir 'ProthesaConfig.json'
if (-not (Test-Path -LiteralPath $cfgPath)) {
    @{ base_path = $DataDir; auto_update_after_copy = $false } | ConvertTo-Json |
        Set-Content -LiteralPath $cfgPath -Encoding UTF8
}

# 4. Sampel terenkripsi: copy bundel lalu decrypt ke data (akun ini = pembuat).
if (-not $NoSample) {
    $bundle = Get-ChildItem -LiteralPath $SrcRoot -Filter '*.prothesa' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $bundle) {
        $bundle = Get-ChildItem -LiteralPath (Join-Path $SrcRoot 'dist') -Filter '*.prothesa' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if ($bundle) {
        Copy-Item -LiteralPath $bundle.FullName -Destination $InstallDir -Force
        Copy-Item -LiteralPath ($bundle.FullName + '.json') -Destination $InstallDir -Force -ErrorAction SilentlyContinue
        try {
            . (Join-Path $InstallDir 'ProthesaDataVault.ps1')
            $dst = Join-Path $InstallDir (Split-Path -Leaf $bundle.FullName)
            $r = Install-ProthesaSample -BundleFile $dst -BasePath $DataDir
            Write-Host ("[Install] Sampel dipasang: " + $r.Path) -ForegroundColor Green
        } catch { Write-Warning ("[Install] Sampel tidak bisa di-decrypt di sini (beda akun/mesin?): " + $_.Exception.Message) }
    } else {
        Write-Host '[Install] Tanpa bundel sampel (tidak ditemukan).' -ForegroundColor DarkGray
    }
} else {
    Write-Host '[Install] Sampel dilewati (-NoSample).' -ForegroundColor DarkGray
}

# 5. Shortcut Desktop.
if (-not $NoShortcut) {
    $Wsh = New-Object -ComObject WScript.Shell
    try {
        $Desktop = [System.Environment]::GetFolderPath('Desktop')
        $sc = $Wsh.CreateShortcut("$Desktop\Prothesa Util.lnk")
        $sc.TargetPath = $launchTarget
        $sc.WorkingDirectory = $InstallDir
        $sc.IconLocation = 'shell32.dll, 21'
        $sc.Save()
        $sc2 = $Wsh.CreateShortcut("$Desktop\Uninstall Prothesa Util.lnk")
        $sc2.TargetPath = 'powershell.exe'
        $sc2.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $InstallDir 'Uninstall-Prothesa.ps1') + '"'
        $sc2.WorkingDirectory = $InstallDir
        $sc2.IconLocation = 'shell32.dll, 3'
        $sc2.Save()
        Write-Host '[Install] Shortcut Desktop dibuat.' -ForegroundColor Green
    } finally {
        if ($null -ne $Wsh) { [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Wsh) | Out-Null }
    }
}

# 6. Entri Programs & Features (HKCU, tanpa admin).
try {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProthesaUtil'
    if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -LiteralPath $key -Name 'DisplayName' -Value 'Prothesa Util'
    Set-ItemProperty -LiteralPath $key -Name 'DisplayVersion' -Value $ver
    Set-ItemProperty -LiteralPath $key -Name 'Publisher' -Value 'Ridwan Gatro (RidTheWann)'
    Set-ItemProperty -LiteralPath $key -Name 'InstallLocation' -Value $InstallDir
    Set-ItemProperty -LiteralPath $key -Name 'UninstallString' -Value ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $InstallDir 'Uninstall-Prothesa.ps1') + '"')
    Set-ItemProperty -LiteralPath $key -Name 'NoModify' -Value 1 -Type DWord
    Set-ItemProperty -LiteralPath $key -Name 'NoRepair' -Value 1 -Type DWord
} catch { Write-Warning ("[Install] Gagal tulis entri uninstall: " + $_.Exception.Message) }

Write-Host '[Install] Selesai.' -ForegroundColor Green
