<#
.SYNOPSIS
  ProthesaDataVault — kompres (ZIP) + enkripsi (DPAPI) untuk data penting. 100% PowerShell + .NET.
.DESCRIPTION
  Format bundel: <nama>.prothesa (bytes DPAPI) + <nama>.prothesa.json (manifest plaintext).
  Kunci diikat ke akun Windows lokal (DPAPI CurrentUser): tanpa password, mudah untuk semua orang,
  hanya bisa dibuka di user/mesin yang sama (prioritaskan lokal). BUKAN untuk dibagikan via GitHub.
.NOTES
  Butuh: Add-Type System.Security (bawaan .NET). Tanpa modul eksternal.
#>
$ErrorActionPreference = 'Stop'

function Get-ProthesaEntropy {
    # Tujuan/fungsi tetap sebagai entropy tambahan (bukan rahasia; rahasia = kunci DPAPI akun).
    return [System.Text.Encoding]::UTF8.GetBytes('ProthesaUtil-sample-v1')
}

function New-ProthesaBundle {
    <#
    .SYNOPSIS
    Kompres folder menjadi ZIP lalu enkripsi DPAPI menjadi file .prothesa + manifest .json.
    #>
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$Label = ''
    )
    if (-not (Test-Path -LiteralPath $SourceDir)) { throw "SourceDir tidak ditemukan: $SourceDir" }
    Add-Type -AssemblyName System.Security
    $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("prothesa-pack-" + [Guid]::NewGuid().ToString('N') + '.zip')
    try {
        Compress-Archive -Path (Join-Path $SourceDir '*') -DestinationPath $tmpZip -CompressionLevel Optimal -Force
        $plain = [System.IO.File]::ReadAllBytes($tmpZip)
        $enc = [System.Security.Cryptography.ProtectedData]::Protect(
            $plain, (Get-ProthesaEntropy), [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        $outDir = Split-Path -Parent $OutFile
        if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
        [System.IO.File]::WriteAllBytes($OutFile, $enc)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($plain)).Replace('-', '').ToLower() }
        finally { $sha.Dispose() }
        $files = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File -ErrorAction SilentlyContinue)
        $manifest = [ordered]@{
            format       = 'prothesa-bundle-v1'
            label        = $Label
            created_at   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            created_by   = [System.Environment]::UserName
            scope        = 'DPAPI-CurrentUser'
            source       = (Split-Path -Leaf $SourceDir)
            file_count   = $files.Count
            plain_bytes  = $plain.Length
            cipher_bytes = $enc.Length
            sha256_plain = $hash
        }
        $manifest | ConvertTo-Json | Set-Content -LiteralPath ($OutFile + '.json') -Encoding UTF8
        return [pscustomobject]@{ Bundle = $OutFile; Manifest = ($OutFile + '.json'); PlainBytes = $plain.Length; Files = $files.Count }
    } finally {
        Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
    }
}

function Test-ProthesaBundle {
    <#
    .SYNOPSIS
    Cek cepat bundel: file + manifest ada, bisa di-decrypt, isi berupa ZIP valid (magic PK).
    #>
    param([Parameter(Mandatory)][string]$BundleFile)
    $mf = $BundleFile + '.json'
    if (-not (Test-Path -LiteralPath $BundleFile)) { return $false }
    if (-not (Test-Path -LiteralPath $mf)) { return $false }
    try {
        Add-Type -AssemblyName System.Security
        $enc = [System.IO.File]::ReadAllBytes($BundleFile)
        $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $enc, (Get-ProthesaEntropy), [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        return ($plain.Length -gt 4 -and $plain[0] -eq 0x50 -and $plain[1] -eq 0x4B)
    } catch { return $false }
}

function Find-ProthesaBundle {
    <#
    .SYNOPSIS
    Cari file *.prothesa di folder aplikasi (samping EXE/skrip). Kembalikan yang terbaru.
    #>
    param([string]$AppRoot = '')
    if (-not $AppRoot) { $AppRoot = Get-AppScriptRoot }
    if (-not (Test-Path -LiteralPath $AppRoot)) { return $null }
    return (Get-ChildItem -LiteralPath $AppRoot -Filter '*.prothesa' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1)
}

function New-ProthesaSampleBundle {
    <#
    .SYNOPSIS
    Pack 1 folder bulan sebagai sampel, sekaligus catat konteks tahun+bulan di manifest.
    #>
    param(
        [Parameter(Mandatory)][string]$MonthPath,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$Label = ''
    )
    $monthDir = Get-Item -LiteralPath $MonthPath
    $yearDir = Get-Item -LiteralPath (Split-Path -Parent $MonthPath)
    $r = New-ProthesaBundle -SourceDir $monthDir.FullName -OutFile $OutFile -Label $Label
    $mf = Get-Content -Raw -LiteralPath ($OutFile + '.json') | ConvertFrom-Json
    $mf | Add-Member -NotePropertyName 'year_folder' -NotePropertyValue $yearDir.Name -Force
    $mf | Add-Member -NotePropertyName 'month_folder' -NotePropertyValue $monthDir.Name -Force
    $mf | ConvertTo-Json | Set-Content -LiteralPath ($OutFile + '.json') -Encoding UTF8
    return $r
}

function Install-ProthesaSample {
    <#
    .SYNOPSIS
    Pasang bundel sampel ke BasePath dengan struktur tahun/bulan aslinya. Lewati bila bulan sudah ada.
    #>
    param(
        [Parameter(Mandatory)][string]$BundleFile,
        [Parameter(Mandatory)][string]$BasePath
    )
    $mf = Get-Content -Raw -LiteralPath ($BundleFile + '.json') | ConvertFrom-Json
    if (-not $mf.month_folder) { throw 'Bundel ini bukan sampel bulan (tanpa konteks month_folder).' }
    $yearPath = Join-Path $BasePath $mf.year_folder
    $monthPath = Join-Path $yearPath $mf.month_folder
    if (Test-Path -LiteralPath $monthPath) { return [pscustomobject]@{ Installed = $false; Path = $monthPath; Note = 'sudah ada, dilewati' } }
    New-Item -ItemType Directory -Path $monthPath -Force | Out-Null
    $files = Expand-ProthesaBundle -BundleFile $BundleFile -DestDir $monthPath
    return [pscustomobject]@{ Installed = $true; Path = $monthPath; Files = @($files).Count }
}

function Expand-ProthesaBundle {
    <#
    .SYNOPSIS
    Decrypt + verifikasi SHA256 + expand ZIP ke DestDir. Mengembalikan daftar file.
    #>
    param(
        [Parameter(Mandatory)][string]$BundleFile,
        [Parameter(Mandatory)][string]$DestDir,
        [switch]$Force
    )
    $mf = $BundleFile + '.json'
    if (-not (Test-Path -LiteralPath $BundleFile)) { throw "Bundel tidak ditemukan: $BundleFile" }
    if (-not (Test-Path -LiteralPath $mf)) { throw "Manifest tidak ditemukan: $mf" }
    Add-Type -AssemblyName System.Security
    $manifest = Get-Content -Raw -LiteralPath $mf | ConvertFrom-Json
    if ($manifest.format -ne 'prothesa-bundle-v1') { throw "Format bundel tidak dikenal: $($manifest.format)" }
    try {
        $enc = [System.IO.File]::ReadAllBytes($BundleFile)
        $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $enc, (Get-ProthesaEntropy), [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    } catch {
        throw "Gagal decrypt (bundel hanya bisa dibuka di akun Windows yang membuatnya): $($_.Exception.Message)"
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($plain)).Replace('-', '').ToLower() }
    finally { $sha.Dispose() }
    if ($manifest.sha256_plain -and ($hash -ne $manifest.sha256_plain)) { throw 'Integritas bundel rusak (SHA256 tidak cocok).' }
    if (-not (Test-Path -LiteralPath $DestDir)) { New-Item -ItemType Directory -Path $DestDir | Out-Null }
    $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("prothesa-unpack-" + [Guid]::NewGuid().ToString('N') + '.zip')
    try {
        [System.IO.File]::WriteAllBytes($tmpZip, $plain)
        Expand-Archive -LiteralPath $tmpZip -DestinationPath $DestDir -Force:$Force
        return @(Get-ChildItem -LiteralPath $DestDir -Recurse -File -ErrorAction SilentlyContinue)
    } finally {
        Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
    }
}
