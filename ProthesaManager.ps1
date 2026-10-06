# ============================================================================
# ProthesaManager.ps1
# Tools Otomasi Arsip Klaim Prothesa Gigi          drg. Danny Hanggono
# ============================================================================

# Set encoding agar emoji muncul benar di terminal (guard: EXE GUI tanpa console tidak punya handle).
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# Konfigurasi (guard: host EXE ps2exe tidak punya MyCommand.Path — jangan timpa BasePath milik GUI).
if ($MyInvocation.MyCommand.Path) {
    $Script:BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path
} elseif (-not $Script:BasePath) {
    $Script:BasePath = (Get-Location).Path
}
$Script:DokterName = "drg. Danny"
$Script:DokterNameFull = "DRG. DANNY"

# Vault opsional (sidecar; di EXE merged sudah inline sehingga dilewati).
# NB: sengaja via .NET Combine (bukan Join-Path) agar lolos penjagaan merge EXE-safe.
try {
    if ($PSScriptRoot) {
        $vsSidecar = [System.IO.Path]::Combine($PSScriptRoot, 'ProthesaDataVault.ps1')
        if (Test-Path -LiteralPath $vsSidecar) { . $vsSidecar }
    }
} catch { }

$Script:BulanNames = @{
    1  = "JANUARI"
    2  = "FEBRUARI"
    3  = "MARET"
    4  = "APRIL"
    5  = "MEI"
    6  = "JUNI"
    7  = "JULI"
    8  = "AGUSTUS"
    9  = "SEPTEMBER"
    10 = "OKTOBER"
    11 = "NOVEMBER"
    12 = "DESEMBER"
}

$Script:YearLetters = @{
    2024 = "A"
    2025 = "B"
    2026 = "C"
    2027 = "D"
    2028 = "E"
    2029 = "F"
    2030 = "G"
}

$Script:BerkasUmumList = @(
    "1. BAST"
    "2. BAKB"
    "3. BAHV"
    "4. SPTJM"
    "5. PERNYATAAN TIDAK ADA KLAIM TERCECER"
    "6. FPK"
    "7. REKAP PROTHESA"
    "8. KWITANSI"
    "9. SPKTPK"
)

$Script:RomawiNames = @{
    1 = "I"; 2 = "II"; 3 = "III"; 4 = "IV"; 5 = "V"; 6 = "VI"
    7 = "VII"; 8 = "VIII"; 9 = "IX"; 10 = "X"; 11 = "XI"; 12 = "XII"
}

$Script:BulanNamesLower = @{
    1 = "Januari"; 2 = "Februari"; 3 = "Maret"; 4 = "April"
    5 = "Mei"; 6 = "Juni"; 7 = "Juli"; 8 = "Agustus"
    9 = "September"; 10 = "Oktober"; 11 = "November"; 12 = "Desember"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-YearFolderName {
    param([int]$Year)
    if ($Year -ge 24 -and $Year -le 99) { $Year += 2000 }
    $letter = $Script:YearLetters[$Year]
    if (-not $letter) {
        # Jika tahun belum didefinisikan, generate otomatis (2024 -> A, 2025 -> B, dst)
        $idx = [Math]::Max(0, $Year - 2024)
        $letter = [char]([int][char]'A' + $idx)
    }
    return "$letter=PROTHESA $Year"
}

function Get-MonthFolderName {
    param([int]$Year, [int]$Month)
    if ($Year -ge 24 -and $Year -le 99) { $Year += 2000 }
    $bulanUpper = $Script:BulanNames[$Month]
    $bulan = $Script:BulanNamesLower[$Month]
    $yy = $Year.ToString().Substring(2)
    
    $yearFolder = Join-Path $Script:BasePath (Get-YearFolderName -Year $Year)
    if (Test-Path -LiteralPath $yearFolder) {
        $dirs = Get-ChildItem -LiteralPath $yearFolder -Directory -ErrorAction SilentlyContinue
        # 1. Prioritaskan kecocokan prefix angka bulan: ^$Month=PROTHESA
        $existingFolder = $dirs | Where-Object { $_.Name -match "^$Month=PROTHESA" } | Select-Object -First 1
        if (-not $existingFolder) {
            $existingFolder = $dirs | Where-Object { $_.Name -match "PROTHESA\s+($bulanUpper|$bulan)\b" } | Select-Object -First 1
        }
        if ($existingFolder) {
            return $existingFolder.Name
        }
    }
    
    return "$Month=PROTHESA $bulan $yy"
}

function Get-MonthPath {
    param([int]$Year, [int]$Month)
    if ($Year -ge 24 -and $Year -le 99) { $Year += 2000 }
    $yearFolderName = Get-YearFolderName -Year $Year
    $yearPath = Join-Path $Script:BasePath $yearFolderName
    
    if (-not (Test-Path -LiteralPath $yearPath)) {
        return $null
    }
    
    $bulanUpper = $Script:BulanNames[$Month]
    $bulan = $Script:BulanNamesLower[$Month]
    $dirs = Get-ChildItem -LiteralPath $yearPath -Directory -ErrorAction SilentlyContinue
    
    # 1. Prioritaskan kecocokan prefix angka bulan: ^$Month=PROTHESA
    $monthFolder = $dirs | Where-Object { $_.Name -match "^$Month=PROTHESA" } | Select-Object -First 1
    if (-not $monthFolder) {
        $monthFolder = $dirs | Where-Object { $_.Name -match "PROTHESA\s+($bulanUpper|$bulan)\b" } | Select-Object -First 1
    }
    
    if ($monthFolder) {
        return $monthFolder.FullName
    }
    return $null
}

function Get-AppScriptRoot {
    <#
    .SYNOPSIS
    Lokasi folder aplikasi yang aman di semua host: script .ps1, ISE, maupun EXE ps2exe
    (di EXE, $PSScriptRoot dan $MyInvocation kosong — fallback ke folder EXE).
    #>
    if ($PSScriptRoot) { return $PSScriptRoot }
    try {
        $ea = [System.Reflection.Assembly]::GetEntryAssembly().Location
        if ($ea -and $ea -match '\.exe$') { return (Split-Path -Parent $ea) }
    } catch { }
    if ($Script:BasePath) { return $Script:BasePath }
    return (Get-Location).Path
}

function Get-TemplateSourceDir {
    <#
    .SYNOPSIS
    Mencari direktori template contoh. Prioritas utama: folder _TEMPLATES di samping skrip.
    Mendukung repo publik kosong: fallback ke _TEMPLATES-private (submodule privat).
    #>
    $appRoot = Get-AppScriptRoot
    $bp = if ($Script:BasePath) { $Script:BasePath } else { $appRoot }
    $candidates = @(
        (Join-Path $appRoot "_TEMPLATES"),
        (Join-Path $bp "_TEMPLATES"),
        (Join-Path $appRoot "_TEMPLATES-private"),
        (Join-Path $bp "_TEMPLATES-private"),
        (Join-Path $appRoot "templates"),
        (Join-Path $bp "templates")
    )
    foreach ($cand in $candidates) {
        if (Test-Path -LiteralPath $cand) {
            $files = Get-ChildItem -LiteralPath $cand -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(doc|xlsx)$' }
            if ($files.Count -ge 4) {
                return $cand
            }
        }
    }
    return $null
}

function Write-ColorText {
    param(
        [string]$Text,
        [ConsoleColor]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-ColorText "  ╔══════════════════════════════════════════════════════════╗" Cyan
    Write-ColorText "  ║   🦷  PROTHESA MANAGER — drg. Danny Hanggono            ║" Cyan
    Write-ColorText "  ║       Tools Otomasi Arsip Klaim BPJS                     ║" Cyan
    Write-ColorText "  ╚══════════════════════════════════════════════════════════╝" Cyan
    Write-Host ""
}

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

function New-MonthFolder {
    <#
    .SYNOPSIS
    Membuat seluruh struktur folder untuk bulan baru.
    #>
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][int]$Month,
        [switch]$Force,
        [switch]$NoPromptCopy
    )
    
    if ($Year -ge 24 -and $Year -le 99) { $Year += 2000 }
    $bulanUpper = $Script:BulanNames[$Month]
    $bulan = $Script:BulanNamesLower[$Month]
    $yy = $Year.ToString().Substring(2)
    $yyyy = $Year.ToString()
    
    if (-not $bulan) {
        Write-ColorText "  Bulan tidak valid: $Month" Red
        return $false
    }
    
    Write-Host ""
    Write-ColorText "  Membuat struktur folder: PROTHESA $bulan $yy" Yellow
    Write-Host "  ───────────────────────────────────────────────" 
    
    # 1. Buat folder tahun jika belum ada
    $yearFolderName = Get-YearFolderName -Year $Year
    $yearPath = Join-Path $Script:BasePath $yearFolderName
    if (-not (Test-Path $yearPath)) {
        New-Item -Path $yearPath -ItemType Directory -Force | Out-Null
        Write-ColorText "  Folder tahun dibuat: $yearFolderName" Green
    }
    
    # 2. Buat folder bulan
    $monthFolderName = Get-MonthFolderName -Year $Year -Month $Month
    $monthPath = Join-Path $yearPath $monthFolderName
    
    if (Test-Path $monthPath) {
        Write-ColorText "  Folder bulan sudah ada: $monthFolderName" Yellow
        if (-not $Force) {
            $confirm = (Read-Host "  Lanjutkan dan buat subfolder yang kurang? (y/n)").Trim()
            if ($confirm -ne 'y') { return $false }
        }
    } else {
        New-Item -Path $monthPath -ItemType Directory -Force | Out-Null
        Write-ColorText "  Folder bulan dibuat: $monthFolderName" Green
    }
    
    # 3. Buat subfolder KLAIM
    $klaimFolderName = "KLAIM PROTHESA GIGI $($Script:DokterNameFull) $bulan $yyyy"
    $klaimPath = Join-Path $monthPath $klaimFolderName
    if (-not (Test-Path $klaimPath)) {
        New-Item -Path $klaimPath -ItemType Directory -Force | Out-Null
        Write-ColorText "  Subfolder KLAIM dibuat" Green
    }
    
    # 4. Buat BERKAS UMUM
    $berkasUmumName = "BERKAS UMUM $bulan $yy"
    $berkasUmumPath = Join-Path $klaimPath $berkasUmumName
    if (-not (Test-Path $berkasUmumPath)) {
        New-Item -Path $berkasUmumPath -ItemType Directory -Force | Out-Null
        Write-ColorText "  Subfolder BERKAS UMUM dibuat" Green
    }
    
    # 5. Buat RJTP
    $rjtpName = "RJTP-PROTHESA GIGI $bulan $yy"
    $rjtpPath = Join-Path $klaimPath $rjtpName
    if (-not (Test-Path $rjtpPath)) {
        New-Item -Path $rjtpPath -ItemType Directory -Force | Out-Null
        Write-ColorText "  Subfolder RJTP dibuat" Green
    }
    
    Write-Host ""
    Write-ColorText "  Struktur folder selesai dibuat!" Green
    Write-Host "  Path: $monthPath"
    Write-Host ""
    
    # Tanya apakah mau copy template
    if (-not $NoPromptCopy) {
        $copyTemplate = (Read-Host "  Mau copy template dari bulan sebelumnya? (y/n)").Trim()
        if ($copyTemplate -eq 'y') {
            Copy-TemplatesFromPrevious -Year $Year -Month $Month | Out-Null
        }
    }
    
    return $true
}

function Copy-TemplatesFromPrevious {
    <#
    .SYNOPSIS
    Copy dan rename template dokumen (.doc, .xlsx) dari folder _TEMPLATES (prioritas utama) atau dari bulan sebelumnya.
    Bisa berjalan mandiri tanpa memerlukan folder root arsip historis.
    #>
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][int]$Month,
        [switch]$NoPromptAutoFill
    )
    
    $bulanUpper = $Script:BulanNames[$Month]
    $bulan = $Script:BulanNamesLower[$Month]
    $yy = $Year.ToString().Substring(2)
    
    $currentPath = Get-MonthPath -Year $Year -Month $Month
    if (-not $currentPath) {
        Write-ColorText "  Folder bulan tujuan tidak ditemukan. Buat dulu!" Red
        return
    }
    
    # 5 Dokumen target administrasi standar klaim BPJS
    $targetTemplates = @(
        @{ Keyword = "Administrasi Klaim"; TargetName = "Administrasi Klaim $($Script:DokterName) $bulan $yy.xlsx"; Ext = ".xlsx" },
        @{ Keyword = "REKAP PROTHESA";     TargetName = "REKAP PROTHESA danny $bulan $yy.doc";             Ext = ".doc" },
        @{ Keyword = "SURAT Pengantar";    TargetName = "SURAT Pengantar ke BPJS klaim $bulan $yy.doc";    Ext = ".doc" },
        @{ Keyword = "surat pernyataan KLAIM"; TargetName = "surat pernyataan KLAIM TAGIHAN $bulan $yy.doc"; Ext = ".doc" },
        @{ Keyword = "surat pernyataan tidak"; TargetName = "surat pernyataan tidak ada tercecer $bulan $yy.doc"; Ext = ".doc" }
    )
    
    $sourceDir = Get-TemplateSourceDir
    $sourceFiles = @()
    
    if ($sourceDir) {
        Write-ColorText "  [STANDALONE] Mengcopy template dari: $(Split-Path -Leaf $sourceDir)/" Cyan
        $sourceFiles = Get-ChildItem -LiteralPath $sourceDir -File -ErrorAction SilentlyContinue
    } else {
        # Fallback: cari bulan sebelumnya di arsip jika ada
        $prevPath = $null
        for ($i = 1; $i -le 12; $i++) {
            $m = $Month - $i
            $y = $Year
            while ($m -lt 1) { $m += 12; $y -= 1 }
            $p = Get-MonthPath -Year $y -Month $m
            if ($p) {
                $prevPath = $p
                break
            }
        }
        if ($prevPath) {
            Write-ColorText "  Mengcopy template dari bulan arsip sebelumnya: $(Split-Path -Leaf $prevPath)" Cyan
            $sourceFiles = Get-ChildItem -LiteralPath $prevPath -File -ErrorAction SilentlyContinue
        } else {
            Write-ColorText "  Template tidak ditemukan! Letakkan berkas contoh di folder '_TEMPLATES/' agar bisa dipakai tanpa root arsip." Red
            return
        }
    }
    
    $copied = 0
    foreach ($tmpl in $targetTemplates) {
        $destFile = Join-Path $currentPath $tmpl.TargetName
        if (Test-Path -LiteralPath $destFile) {
            Write-ColorText "    Sudah ada: $($tmpl.TargetName)" DarkGray
            continue
        }
        
        $match = $sourceFiles | Where-Object { 
            ($_.Name -like "*$($tmpl.Keyword)*$($tmpl.Ext)") -or 
            ($_.Name -like "*$($tmpl.Keyword)*" -and $_.Extension -eq $tmpl.Ext)
        } | Select-Object -First 1
        
        if ($match) {
            Copy-Item -LiteralPath $match.FullName -Destination $destFile -Force
            Write-ColorText "    + $($tmpl.TargetName)" Green
            $copied++
        } else {
            Write-ColorText "    ! File contoh tidak ditemukan untuk: $($tmpl.Keyword)" Yellow
        }
    }
    
    Write-Host ""
    Write-ColorText "  $copied file template berhasil disiapkan!" Green
    Write-Host ""
    
    if (-not $NoPromptAutoFill) {
        $autoFill = (Read-Host "  Mau otomatis update isi file Word/Excel? (y/n)").Trim()
        if ($autoFill -eq 'y') {
            Update-AllTemplates -Year $Year -Month $Month | Out-Null
        }
    }
}

function New-PatientFolder {
    <#
    .SYNOPSIS
    Membuat subfolder pasien di dalam RJTP.
    #>
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][int]$Month,
        [Parameter(Mandatory)][string]$PatientName,
        [int]$Number = 0
    )
    
    $bulanUpper = $Script:BulanNames[$Month]
    $bulan = $Script:BulanNamesLower[$Month]
    $yy = $Year.ToString().Substring(2)
    $yyyy = $Year.ToString()
    
    $monthPath = Get-MonthPath -Year $Year -Month $Month
    if (-not $monthPath) {
        Write-ColorText "  Folder bulan tidak ditemukan. Buat dulu!" Red
        return $false
    }
    
    # Cari folder RJTP
    $klaimFolderName = "KLAIM PROTHESA GIGI $($Script:DokterNameFull) $bulan $yyyy"
    $rjtpName = "RJTP-PROTHESA GIGI $bulan $yy"
    $rjtpPath = Join-Path (Join-Path $monthPath $klaimFolderName) $rjtpName
    
    # Fallback: cari folder RJTP dengan pattern matching
    if (-not (Test-Path $rjtpPath)) {
        $klaimFolder = Get-ChildItem -Path $monthPath -Directory | Where-Object { $_.Name -match "^KLAIM" } | Select-Object -First 1
        if ($klaimFolder) {
            $rjtpFolder = Get-ChildItem -Path $klaimFolder.FullName -Directory | Where-Object { $_.Name -match "^RJTP" } | Select-Object -First 1
            if ($rjtpFolder) {
                $rjtpPath = $rjtpFolder.FullName
            }
        }
    }
    
    if (-not (Test-Path $rjtpPath)) {
        Write-ColorText "  Folder RJTP tidak ditemukan" Red
        return $false
    }
    
    # Tentukan nomor folder
    if ($Number -eq 0) {
        $existingNums = Get-ChildItem -Path $rjtpPath -Directory | ForEach-Object {
            if ($_.Name -match '^\d+$') { [int]$_.Name }
        } | Sort-Object
        $Number = $(if ($existingNums.Count -gt 0) { ($existingNums | Measure-Object -Maximum).Maximum + 1 } else { 1 })
    }
    
    $patientPath = Join-Path $rjtpPath $Number.ToString()
    # Sanitize: trim whitespace and remove illegal filename chars
    $nameUpper = $PatientName.Trim().ToUpper() -replace '[\\/:*?\x22<>|\x00-\x1F]', ''
    if ([string]::IsNullOrWhiteSpace($nameUpper)) {
        Write-ColorText "  Nama pasien tidak valid" Red
        return $false
    }
    
    if (Test-Path $patientPath) {
        Write-ColorText "  Folder pasien #$Number sudah ada" Yellow
        return $false
    }
    
    New-Item -Path $patientPath -ItemType Directory -Force | Out-Null
    
    # Buat 3 file placeholder PDF (file kosong sebagai reminder)
    $files = @(
        "BUKTI LAYANAN $nameUpper.pdf"
        "FKPP $nameUpper.pdf"
        "RESEP PROTHESA $nameUpper.pdf"
    )
    
    foreach ($f in $files) {
        $filePath = Join-Path $patientPath $f
        # Buat file kosong sebagai placeholder
        New-Item -Path $filePath -ItemType File -Force | Out-Null
    }
    
    Write-ColorText "  Pasien #${Number}: $nameUpper (3 file placeholder dibuat)" Green
    return $true
}

function New-BatchPatients {
    <#
    .SYNOPSIS
    Batch membuat folder pasien dari daftar nama.
    #>
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][int]$Month,
        [string[]]$Names
    )
    
    $bulan = $Script:BulanNamesLower[$Month]
    $yy = $Year.ToString().Substring(2)

    Write-Host ""
    Write-ColorText "  Batch Buat Folder Pasien: $bulan $yy" Yellow
    Write-Host "  ───────────────────────────────────────────────"
    
    if (-not $Names -or $Names.Count -eq 0) {
        Write-ColorText "  Masukkan nama pasien satu per satu." Cyan
        Write-ColorText "  Ketik 'done' jika sudah selesai." DarkGray
        Write-Host ""
        
        $Names = @()
        $num = 1
        while ($true) {
            $name = (Read-Host "  Pasien #$num").Trim()
            if ($name -eq 'done' -or $name -eq '') { break }
            $Names += $name
            $num++
        }
    }
    
    if ($Names.Count -eq 0) {
        Write-ColorText "  Tidak ada nama yang dimasukkan" Red
        return
    }
    
    Write-Host ""
    $success = 0
    foreach ($name in $Names) {
        $result = New-PatientFolder -Year $Year -Month $Month -PatientName $name
        if ($result) { $success++ }
    }
    
    Write-Host ""
    Write-ColorText "  $success dari $($Names.Count) folder pasien berhasil dibuat!" Green
    Write-Host ""
}

function Compress-MonthToZip {
    <#
    .SYNOPSIS
    Kompresi folder bulan menjadi file ZIP.
    #>
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][int]$Month,
        [switch]$Force
    )
    
    $monthPath = Get-MonthPath -Year $Year -Month $Month
    if (-not $monthPath) {
        Write-ColorText "  Folder bulan tidak ditemukan" Red
        return
    }
    
    $monthFolderName = Split-Path -Leaf $monthPath
    $yearPath = Split-Path -Parent $monthPath
    $zipPath = Join-Path $yearPath "$monthFolderName.zip"
    
    Write-Host ""
    Write-ColorText "  Mengkompresi: $monthFolderName" Yellow
    
    if (Test-Path $zipPath) {
        if (-not $Force) {
            $confirm = (Read-Host "  File ZIP sudah ada. Timpa? (y/n)").Trim()
            if ($confirm -ne 'y') { return }
        }
        Remove-Item $zipPath -Force
    }
    
    try {
        Compress-Archive -Path $monthPath -DestinationPath $zipPath -CompressionLevel Optimal
        $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
        Write-ColorText "  ZIP berhasil dibuat: $zipPath" Green
        Write-ColorText "  Ukuran: $sizeMB MB" Cyan
    } catch {
        Write-ColorText "  Gagal membuat ZIP: $($_.Exception.Message)" Red
    }
    
    Write-Host ""
}

function Test-ProthesaMonthValidation {
    <#
    .SYNOPSIS
    Single source of truth untuk validasi kelengkapan berkas arsip prothesa per bulan.
    Memeriksa 5 berkas administrasi root, 9 berkas umum PDF non-zero byte, berkas pasien RJTP (3 PDF), dan file ZIP.
    #>
    param(
        [string]$MonthPath = '',
        [int]$Year = 0,
        [int]$Month = 0
    )
    
    if (-not $MonthPath -and $Year -gt 0 -and $Month -gt 0) {
        $MonthPath = Get-MonthPath -Year $Year -Month $Month
    }
    
    if (-not $MonthPath -or -not (Test-Path -LiteralPath $MonthPath)) {
        return $null
    }
    
    $monthDir = Get-Item -LiteralPath $MonthPath
    $yearDir = Split-Path -Parent $MonthPath
    $monthName = $monthDir.Name

    # 1. Validasi 5 Dokumen Administrasi Klaim (Root Bulan)
    $expectedAdmin = @(
        @{ Key = "admin_klaim"; Label = "Administrasi Klaim (.xlsx)"; Match = "Administrasi.*Klaim" }
        @{ Key = "rekap_doc"; Label = "REKAP PROTHESA (.doc)"; Match = "REKAP.*PROTHESA" }
        @{ Key = "pengantar"; Label = "Surat Pengantar ke BPJS (.doc)"; Match = "SURAT.*Pengantar" }
        @{ Key = "pernyataan_klaim"; Label = "Surat Pernyataan Klaim Tagihan (.doc)"; Match = "surat.*pernyataan.*KLAIM" }
        @{ Key = "pernyataan_tercecer"; Label = "Surat Pernyataan Tidak Ada Tercecer (.doc)"; Match = "surat.*pernyataan.*tercecer" }
    )

    $adminFiles = Get-ChildItem -LiteralPath $MonthPath -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' }
    $adminResults = @()
    $adminValidCount = 0

    foreach ($exp in $expectedAdmin) {
        $found = $adminFiles | Where-Object { $_.Name -match $exp.Match } | Select-Object -First 1
        $isValid = ($null -ne $found -and $found.Length -gt 0)
        if ($isValid) { $adminValidCount++ }
        $adminResults += [pscustomobject]@{
            Key = $exp.Key
            Label = $exp.Label
            Found = ($null -ne $found)
            Valid = $isValid
            FileName = $(if ($found) { $found.Name } else { $null })
            Size = $(if ($found) { $found.Length } else { 0 })
        }
    }
    $isAdminComplete = ($adminValidCount -eq $expectedAdmin.Count)

    # 2. Validasi 9 Dokumen BERKAS UMUM
    $expectedBerkasUmum = @(
        'BAST', 'BAKB', 'BAHV', 'SPTJM',
        'PERNYATAAN TIDAK ADA KLAIM TERCECER',
        'FPK', 'REKAP PROTHESA', 'KWITANSI', 'SPKTPK'
    )

    $klaimFolder = Get-ChildItem -LiteralPath $MonthPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^KLAIM" } | Select-Object -First 1
    $berkasUmumResults = @()
    $berkasValidCount = 0
    $berkasFiles = @()

    if ($klaimFolder) {
        $berkasFolder = Get-ChildItem -LiteralPath $klaimFolder.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^BERKAS UMUM" } | Select-Object -First 1
        if ($berkasFolder) {
            $berkasFiles = Get-ChildItem -LiteralPath $berkasFolder.FullName -File -ErrorAction SilentlyContinue
        }
    }

    foreach ($buName in $expectedBerkasUmum) {
        $found = $berkasFiles | Where-Object { $_.Name -match [regex]::Escape($buName) } | Select-Object -First 1
        $isValid = ($null -ne $found -and $found.Length -gt 0)
        if ($isValid) { $berkasValidCount++ }
        $berkasUmumResults += [pscustomobject]@{
            Name = $buName
            Found = ($null -ne $found)
            Valid = $isValid
            FileName = $(if ($found) { $found.Name } else { $null })
            Size = $(if ($found) { $found.Length } else { 0 })
        }
    }
    $isBerkasUmumComplete = ($berkasValidCount -eq $expectedBerkasUmum.Count)

    # 3. Validasi Pasien RJTP
    $patientList = @()
    $patientValidCount = 0
    $patientCount = 0

    if ($klaimFolder) {
        $rjtpFolder = Get-ChildItem -LiteralPath $klaimFolder.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^RJTP" } | Select-Object -First 1
        if ($rjtpFolder) {
            $patientFolders = Get-ChildItem -LiteralPath $rjtpFolder.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object { [int]$_.Name }
            $patientCount = $patientFolders.Count

            foreach ($pf in $patientFolders) {
                $pFiles = Get-ChildItem -LiteralPath $pf.FullName -File -ErrorAction SilentlyContinue
                
                $fBukti = $pFiles | Where-Object { $_.Name -match "^BUKTI LAYANAN" } | Select-Object -First 1
                $fFkpp = $pFiles | Where-Object { $_.Name -match "^FKPP" } | Select-Object -First 1
                $fResep = $pFiles | Where-Object { $_.Name -match "^RESEP PROTHESA" } | Select-Object -First 1

                $hasBukti = ($null -ne $fBukti -and $fBukti.Length -gt 0)
                $hasFkpp = ($null -ne $fFkpp -and $fFkpp.Length -gt 0)
                $hasResep = ($null -ne $fResep -and $fResep.Length -gt 0)
                $isPatientComplete = ($hasBukti -and $hasFkpp -and $hasResep)
                if ($isPatientComplete) { $patientValidCount++ }

                $pName = ""
                if ($fBukti) { $pName = $fBukti.BaseName -replace '^BUKTI LAYANAN\s*', '' }
                elseif ($fFkpp) { $pName = $fFkpp.BaseName -replace '^FKPP\s*', '' }

                $patientList += [pscustomobject]@{
                    Number = [int]$pf.Name
                    Name = $pName
                    FolderName = $pf.Name
                    FilesCount = $pFiles.Count
                    HasBukti = $hasBukti
                    HasFkpp = $hasFkpp
                    HasResep = $hasResep
                    Complete = $isPatientComplete
                }
            }
        }
    }

    $isPatientsComplete = ($patientCount -gt 0 -and $patientValidCount -eq $patientCount)

    # 4. Validasi ZIP
    $zipFile = Get-ChildItem -LiteralPath $yearDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "$monthName.zip" } | Select-Object -First 1
    $hasZip = ($null -ne $zipFile -and $zipFile.Length -gt 0)
    $zipSize = $(if ($hasZip) { $zipFile.Length } else { 0 })

    # 5. Hitung Skor & Status Komprehensif
    $score = 0
    $maxScore = 4

    if ($isAdminComplete) { $score++ }
    if ($isBerkasUmumComplete) { $score++ }
    if ($isPatientsComplete) { $score++ }
    if ($hasZip) { $score++ }

    $statusText = "Kosong"
    $statusCode = "empty"

    if ($isAdminComplete -and $isBerkasUmumComplete -and $isPatientsComplete -and $hasZip) {
        $statusText = "Lengkap"
        $statusCode = "complete"
    } elseif ($isAdminComplete -and $isBerkasUmumComplete -and $isPatientsComplete) {
        $statusText = "Siap ZIP"
        $statusCode = "ready_to_zip"
    } elseif ($adminFiles.Count -gt 0 -or $berkasFiles.Count -gt 0 -or $patientCount -gt 0) {
        $statusText = "Belum Lengkap"
        $statusCode = "in_progress"
    } else {
        $statusText = "Kosong"
        $statusCode = "empty"
    }

    return [pscustomobject]@{
        MonthName = $monthName
        MonthPath = $MonthPath
        StatusText = $statusText
        StatusCode = $statusCode
        Score = $score
        MaxScore = $maxScore
        ProgressPct = [int][Math]::Round(($score / $maxScore) * 100)
        Admin = [pscustomobject]@{
            Complete = $isAdminComplete
            ValidCount = $adminValidCount
            TotalExpected = $expectedAdmin.Count
            Items = $adminResults
        }
        BerkasUmum = [pscustomobject]@{
            Complete = $isBerkasUmumComplete
            ValidCount = $berkasValidCount
            TotalExpected = $expectedBerkasUmum.Count
            Items = $berkasUmumResults
        }
        Patients = [pscustomobject]@{
            Complete = $isPatientsComplete
            Count = $patientCount
            ValidCount = $patientValidCount
            Items = $patientList
        }
        Zip = [pscustomobject]@{
            Exists = $hasZip
            Size = $zipSize
            Path = $(if ($zipFile) { $zipFile.FullName } else { $null })
        }
    }
}

function Export-StatusJson {
    <#
    .SYNOPSIS
    Scan seluruh arsip dengan Single-Source Validation dan simpan data status ke JSON.
    #>
    
    Write-Host ""
    Write-ColorText "  Scanning seluruh arsip dengan Single-Source Validation..." Yellow
    
    $status = @{
        generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        base_path = $Script:BasePath
        years = @()
    }
    
    # Scan setiap folder tahun
    $yearFolders = Get-ChildItem -LiteralPath $Script:BasePath -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '^\w=PROTHESA \d{4}$' } | 
        Sort-Object Name
    
    foreach ($yearFolder in $yearFolders) {
        $yearMatch = [regex]::Match($yearFolder.Name, '(\d{4})')
        $year = [int]$yearMatch.Value
        
        $yearData = @{
            year = $year
            folder_name = $yearFolder.Name
            months = @()
        }
        
        $monthFolders = Get-ChildItem -LiteralPath $yearFolder.FullName -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match '^\d+=PROTHESA' } |
            Sort-Object { [int]($_.Name -replace '=.*', '') }
        
        foreach ($monthFolder in $monthFolders) {
            $monthNum = [int]($monthFolder.Name -replace '=.*', '')
            
            # Detect bulan name (store capitalized form)
            $bulanDetected = ""
            foreach ($key in $Script:BulanNames.Keys) {
                if ($monthFolder.Name -match "\b$($Script:BulanNames[$key])\b" -or $monthFolder.Name -match "\b$($Script:BulanNamesLower[$key])\b") {
                    $bulanDetected = $Script:BulanNamesLower[$key]
                    break
                }
            }
            if (-not $bulanDetected -and $monthNum -ge 1 -and $monthNum -le 12) {
                $bulanDetected = $Script:BulanNamesLower[$monthNum]
            }
            
            # Validasi terpusat
            $val = Test-ProthesaMonthValidation -MonthPath $monthFolder.FullName
            
            $monthData = @{
                number = $monthNum
                folder_name = $monthFolder.Name
                bulan = $bulanDetected
                path = $monthFolder.FullName
                has_zip = if ($val) { [bool]$val.Zip.Exists } else { $false }
                complete = if ($val) { [bool]($val.StatusCode -eq 'complete') } else { $false }
                status_text = if ($val) { $val.StatusText } else { 'Kosong' }
                status_code = if ($val) { $val.StatusCode } else { 'empty' }
                score = if ($val) { $val.Score } else { 0 }
                max_score = if ($val) { $val.MaxScore } else { 4 }
                progress_pct = if ($val) { $val.ProgressPct } else { 0 }
                admin_files = @(Get-ChildItem -LiteralPath $monthFolder.FullName -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object { @{ name = $_.Name; size = $_.Length; extension = $_.Extension } })
                berkas_umum = if ($val) { @($val.BerkasUmum.Items | Where-Object { $_.Found } | ForEach-Object { @{ name = $_.FileName; size = $_.Size } }) } else { @() }
                patient_count = if ($val) { $val.Patients.Count } else { 0 }
                patients = if ($val) { @($val.Patients.Items | ForEach-Object { @{ number = $_.Number; name = $_.Name; files_count = $_.FilesCount; has_bukti_layanan = $_.HasBukti; has_fkpp = $_.HasFkpp; has_resep = $_.HasResep; complete = $_.Complete } }) } else { @() }
                validation = $val
            }
            
            $yearData.months += $monthData
        }
        
        $status.years += $yearData
    }
    
    # Export ke JSON data
    $jsonPath = Join-Path $Script:BasePath "prothesa-status.json"
    $jsonContent = $status | ConvertTo-Json -Depth 10
    $jsonContent | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    # Salin ke folder aplikasi jika BasePath berbeda (mis. data di drive lain).
    $appRoot = Get-AppScriptRoot
    if ($Script:BasePath -ne $appRoot -and (Test-Path -LiteralPath $appRoot)) {
        Copy-Item -LiteralPath $jsonPath -Destination (Join-Path $appRoot "prothesa-status.json") -Force -ErrorAction SilentlyContinue
    }
    
    Write-ColorText "  Status arsip berhasil disimpan ke: prothesa-status.json" Green
    Write-Host ""
    
    # Summary
    $totalMonths = 0
    $totalPatients = 0
    $totalComplete = 0
    foreach ($y in $status.years) {
        $totalMonths += $y.months.Count
        foreach ($m in $y.months) {
            $totalPatients += $m.patient_count
            if ($m.complete) { $totalComplete++ }
        }
    }
    
    Write-ColorText "  Ringkasan Validasi:" Cyan
    Write-Host "     Tahun aktif    : $($status.years.Count)"
    Write-Host "     Total bulan    : $totalMonths"
    Write-Host "     Total pasien   : $totalPatients"
    Write-Host "     Bulan lengkap  : $totalComplete"
    Write-Host ""
}

# ============================================================================
# WORD & EXCEL AUTO-FILL FUNCTIONS
# ============================================================================

function Release-ComRef {
    param([Parameter(Mandatory=$false)][object]$ComObject)
    if ($null -ne $ComObject) {
        try {
            [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($ComObject) | Out-Null
        } catch { }
    }
}

function Update-WordTemplates {
    <#
    .SYNOPSIS
    Update isi file Word (.doc) — ganti bulan, tanggal TTD, kosongkan tabel REKAP.
    #>
    param(
        [string]$MonthPath,
        [string]$OldBulan,       # JANUARI
        [string]$NewBulan,       # FEBRUARI
        [string]$OldBulanLower,  # Januari
        [string]$NewBulanLower,  # Februari
        [int]$OldYear,
        [int]$NewYear,
        [string]$TanggalTTD,     # "6 Maret 2026"
        [string]$OldRomawi,      # "II"
        [string]$NewRomawi,      # "III"
        [int]$JumlahKasus
    )
    
    $word = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0  # wdAlertsNone
        
        $docFiles = Get-ChildItem -Path $MonthPath -Filter "*.doc" -ErrorAction SilentlyContinue
        
        foreach ($docFile in $docFiles) {
            Write-ColorText "  [DOC] Processing: $($docFile.Name)" Cyan
            $doc = $null
            try {
                $doc = $word.Documents.Open($docFile.FullName)
                
                # === Fungsi Helper untuk Replace di semua StoryRange (Body, Header, Footer, Textbox, dll) ===
                $replaceInStory = {
                    param($range, $old, $new)
                    $f = $range.Find
                    $f.ClearFormatting()
                    $f.Replacement.ClearFormatting()
                    $f.Execute($old, $false, $true, $false, $false, $false, $true, 1, $false, $new, 2) | Out-Null
                }
                
                # Loop melalui semua StoryRanges (Main content, Headers, Footers, dll)
                foreach ($story in $doc.StoryRanges) {
                    $currStory = $story
                    do {
                        # 1. Replace bulan pelayanan
                        & $replaceInStory $currStory $OldBulan $NewBulanLower
                        & $replaceInStory $currStory $OldBulanLower $NewBulanLower
                        
                        # 2. Replace tahun jika berubah
                        if ($OldYear -ne $NewYear) {
                            & $replaceInStory $currStory "tahun $OldYear" "tahun $NewYear"
                            $oldYY = $OldYear.ToString().Substring(2)
                            $newYY = $NewYear.ToString().Substring(2)
                            & $replaceInStory $currStory "$OldBulanLower $oldYY" "$NewBulanLower $newYY"
                        }
                        
                        # 3. Replace Romawi (khusus Surat Pengantar)
                        if ($docFile.Name -match "SURAT Pengantar" -and $OldRomawi -ne $NewRomawi) {
                            & $replaceInStory $currStory "/DH/$OldRomawi/" "/DH/$NewRomawi/"
                        }
                        
                        $currStory = $currStory.NextStoryRange
                    } while ($null -ne $currStory)
                }
                
                # === SURAT Pengantar / Pernyataan: Update Tanggal TTD ===
                if ($docFile.Name -match "SURAT Pengantar|surat pernyataan") {
                    for ($pi = 1; $pi -le $doc.Paragraphs.Count; $pi++) {
                        try {
                            $pText = $doc.Paragraphs.Item($pi).Range.Text.Trim()
                            if ($pText -match '^Rembang,') {
                                $doc.Paragraphs.Item($pi).Range.Text = "Rembang, $TanggalTTD`r"
                            }
                        } catch {}
                    }
                    
                    # Khusus Surat Pengantar: update jumlah kasus
                    if ($docFile.Name -match "SURAT Pengantar" -and $JumlahKasus -gt 0) {
                        for ($pi = 1; $pi -le $doc.Paragraphs.Count; $pi++) {
                            try {
                                $pText = $doc.Paragraphs.Item($pi).Range.Text.Trim()
                                if ($pText -match 'kasus$') {
                                    $doc.Paragraphs.Item($pi).Range.Text = ": $JumlahKasus kasus`r"
                                }
                            } catch {}
                        }
                    }
                }
                
                # === REKAP PROTHESA: kosongkan tabel pasien ===
                if ($docFile.Name -match "REKAP PROTHESA") {
                    if ($doc.Tables.Count -gt 0) {
                        $table = $doc.Tables.Item(1)
                        while ($table.Rows.Count -gt 1) {
                            $table.Rows.Item($table.Rows.Count).Delete()
                        }
                        $table.Rows.Add() | Out-Null
                        Write-ColorText "    Tabel pasien dikosongkan" Green
                    }
                }
                
                $doc.Save()
                $doc.Close()
                $doc = $null
                Write-ColorText "    Berhasil di-update" Green
            } catch {
                Write-ColorText "    Gagal update $($docFile.Name): $($_.Exception.Message)" Red
            } finally {
                if ($null -ne $doc) {
                    try { $doc.Close([ref]0) } catch {}
                    Release-ComRef $doc
                    $doc = $null
                }
            }
        }
    } catch {
        Write-ColorText "  Error Word: $($_.Exception.Message)" Red
    } finally {
        if ($null -ne $word) {
            try { $word.Quit([ref]0) } catch {}
            Release-ComRef $word
            $word = $null
        }
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
    }
}

function Update-ExcelTemplate {
    <#
    .SYNOPSIS
    Update isi file Excel (.xlsx) — nomor romawi, bulan pelayanan, FPK, kasus, biaya.
    #>
    param(
        [string]$MonthPath,
        [string]$OldBulanLower,  # Januari
        [string]$NewBulanLower,  # Februari
        [int]$OldYear,
        [int]$NewYear,
        [string]$OldRomawi,
        [string]$NewRomawi,
        [string]$NoFPK,
        [int]$JumlahKasus,
        [decimal]$Biaya
    )
    
    $excel = $null
    $wb = $null
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        
        $xlsFile = Get-ChildItem -Path $MonthPath -Filter "*.xlsx" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $xlsFile) {
            Write-ColorText "               File Excel tidak ditemukan" Yellow
            return
        }
        
        Write-ColorText "  Processing: $($xlsFile.Name)" Cyan
        $wb = $excel.Workbooks.Open($xlsFile.FullName)
        
        $newBulanPelayanan = "$NewBulanLower $NewYear"
        $escapedOld = [regex]::Escape("/ $OldRomawi / $OldYear")
        $replaceNew = "/ $NewRomawi / $NewYear"
        
        # === Sheet 1: BAST (MASTER — tulis nilai langsung) ===
        $ws1 = $wb.Worksheets.Item(1)
        Write-ColorText "    Sheet: $($ws1.Name)" DarkGray
        # Nomor surat R5,C5
        $formula1 = $ws1.Cells.Item(5, 5).Formula
        if ($formula1 -match $escapedOld) {
            try { $ws1.Cells.Item(5, 5).Formula = $formula1 -replace $escapedOld, $replaceNew } catch {}
        }
        # Prothesa Gigi R30: tulis langsung via .Formula
        try { $ws1.Cells.Item(30, 5).Formula = $newBulanPelayanan } catch {}
        if ($NoFPK) {
            try { $ws1.Cells.Item(30, 6).Formula = " $NoFPK " } catch {}
        }
        try { $ws1.Cells.Item(30, 7).Formula = "$JumlahKasus" } catch {}
        try { $ws1.Cells.Item(30, 8).Formula = "$Biaya" } catch {}
        Write-ColorText "    BAST updated" Green
        Release-ComRef $ws1
        $ws1 = $null
        
        # === Sheet 2: BAKB (R30 = formulas referencing BAST) ===
        $ws2 = $wb.Worksheets.Item(2)
        Write-ColorText "    Sheet: $($ws2.Name)" DarkGray
        $formula2 = $ws2.Cells.Item(5, 5).Formula
        if ($formula2 -match $escapedOld) {
            try { $ws2.Cells.Item(5, 5).Formula = $formula2 -replace $escapedOld, $replaceNew } catch {}
        }
        Write-ColorText "    BAKB updated (data auto-sync dari BAST)" Green
        Release-ComRef $ws2
        $ws2 = $null
        
        # === Sheet 3: BAHV (R30 = formulas referencing BAST) ===
        $ws3 = $wb.Worksheets.Item(3)
        Write-ColorText "    Sheet: $($ws3.Name)" DarkGray
        $formula3 = $ws3.Cells.Item(5, 6).Formula
        if ($formula3 -match $escapedOld) {
            try { $ws3.Cells.Item(5, 6).Formula = $formula3 -replace $escapedOld, $replaceNew } catch {}
        }
        Write-ColorText "    BAHV updated (data auto-sync dari BAST)" Green
        Release-ComRef $ws3
        $ws3 = $null
        
        # === Sheet 4: SPTJM ===
        $ws4 = $wb.Worksheets.Item(4)
        Write-ColorText "    Sheet: $($ws4.Name)" DarkGray
        Write-ColorText "    SPTJM updated (semua data auto-sync dari BAST)" Green
        Release-ComRef $ws4
        $ws4 = $null
        
        $wb.Save()
        $wb.Close()
        Release-ComRef $wb
        $wb = $null
        Write-ColorText "  Excel berhasil di-update" Green
    } catch {
        Write-ColorText "  Error Excel: $($_.Exception.Message)" Red
    } finally {
        if ($null -ne $wb) {
            try { $wb.Close($false) } catch {}
            Release-ComRef $wb
            $wb = $null
        }
        if ($null -ne $excel) {
            try { $excel.Quit() } catch {}
            Release-ComRef $excel
            $excel = $null
        }
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
    }
}

function Update-AllTemplates {
    <#
    .SYNOPSIS
    Orchestrator: tanya input user lalu update semua Word & Excel.
    #>
    param(
        [Parameter(Mandatory)][int]$Year,
        [Parameter(Mandatory)][int]$Month
    )
    
    $bulan = $Script:BulanNames[$Month]
    $bulanLower = $Script:BulanNamesLower[$Month]
    $yy = $Year.ToString().Substring(2)
    
    $monthPath = Get-MonthPath -Year $Year -Month $Month
    if (-not $monthPath) {
        Write-ColorText "         Folder bulan tidak ditemukan" Red
        return
    }
    
    # Tentukan bulan sebelumnya (data source) secara cerdas
    # Cari bulan terakhir yang benar-benar ada di folder
    $prevMonth = $Month - 1
    $prevYear = $Year
    if ($prevMonth -lt 1) { $prevMonth = 12; $prevYear = $Year - 1 }
    
    # Cek apakah folder $prevMonth ada, jika tidak cari yang terbaru
    $actualPrevPath = Get-MonthPath -Year $prevYear -Month $prevMonth
    if (-not $actualPrevPath) {
        # Cari mundur 12 bulan
        $found = $false
        for ($i = 1; $i -le 12; $i++) {
            $m = $Month - $i
            $y = $Year
            while ($m -lt 1) { $m += 12; $y -= 1 }
            $p = Get-MonthPath -Year $y -Month $m
            if ($p) {
                $prevMonth = $m
                $prevYear = $y
                $found = $true
                break
            }
        }
    }
    
    $oldBulan = $Script:BulanNames[$prevMonth]
    $oldBulanLower = $Script:BulanNamesLower[$prevMonth]
    
    # Bulan pengajuan = bulan setelah bulan pelayanan (untuk nomor surat romawi)
    $submitMonth = $Month + 1
    $submitYear = $Year
    if ($submitMonth -gt 12) { $submitMonth = 1; $submitYear = $Year + 1 }
    $newRomawi = $Script:RomawiNames[$submitMonth]
    
    $oldSubmitMonth = $Month
    $oldRomawi = $Script:RomawiNames[$oldSubmitMonth]
    
    Write-Host ""
    Write-ColorText "  UPDATE ISI TEMPLATE - $bulanLower $yy" Yellow
    Write-Host "  ───────────────────────────────────────────────"
    Write-ColorText "  Bulan pelayanan: $oldBulanLower -> $bulanLower" Cyan
    Write-ColorText "  Romawi surat  : $oldRomawi -> $newRomawi" Cyan
    Write-Host ""
    
    # Input tanggal TTD
    Write-ColorText "  Tanggal tanda tangan surat:" White
    $tglTTD = (Read-Host "  Contoh: 6 Maret 2026").Trim()
    if ([string]::IsNullOrWhiteSpace($tglTTD)) {
        $tglTTD = "......"
        Write-ColorText "  Menggunakan placeholder '......'" DarkGray
    }
    
    # Input FPK
    $noFPK = (Read-Host "  No FPK (contoh: P2601000026282, kosongkan jika belum tau)").Trim()
    if ([string]::IsNullOrWhiteSpace($noFPK)) {
        $noFPK = ""
        Write-ColorText "  -> FPK tidak diisi, akan dikosongkan" DarkGray
    }
    
    # Input kasus
    $kasusInput = (Read-Host "  Jumlah kasus (angka, contoh: 6)").Trim()
    $jumlahKasus = 0
    if ($kasusInput -match '^\d+$') { $jumlahKasus = [int]$kasusInput }
    
    # Input biaya
    $biayaInput = (Read-Host "  Biaya total Rp (tanpa titik, contoh: 4500000)").Trim()
    $biaya = [decimal]0
    if ($biayaInput -match '^\d+$') { $biaya = [decimal]$biayaInput }
    
    Write-Host ""
    Write-ColorText "  Memproses Word files..." Yellow
    Update-WordTemplates `
        -MonthPath $monthPath `
        -OldBulan $oldBulan `
        -NewBulan $bulan `
        -OldBulanLower $oldBulanLower `
        -NewBulanLower $bulanLower `
        -OldYear $prevYear `
        -NewYear $Year `
        -TanggalTTD $tglTTD `
        -OldRomawi $oldRomawi `
        -NewRomawi $newRomawi `
        -JumlahKasus $jumlahKasus
    
    Write-Host ""
    Write-ColorText "  Memproses Excel file..." Yellow
    Update-ExcelTemplate `
        -MonthPath $monthPath `
        -OldBulanLower $oldBulanLower `
        -NewBulanLower $bulanLower `
        -OldYear $prevYear `
        -NewYear $Year `
        -OldRomawi $oldRomawi `
        -NewRomawi $newRomawi `
        -NoFPK $noFPK `
        -JumlahKasus $jumlahKasus `
        -Biaya $biaya
    
    Write-Host ""
    Write-ColorText "  Semua template berhasil di-update!" Green
    Write-Host ""
}

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

function Show-Menu {
    Write-Banner
    Write-ColorText "  MENU UTAMA" White
    Write-Host "  -----------------------------------------------"
    Write-Host ""
    Write-ColorText "  [1] Buat Folder Bulan Baru" White
    Write-ColorText "  [2] Copy Template dari Bulan Sebelumnya" White
    Write-ColorText "  [3] Buat Folder Pasien" White
    Write-ColorText "  [4] Batch Buat Folder Pasien" White
    Write-ColorText "  [5] ZIP Folder Bulan" White
    Write-ColorText "  [6] Scan Seluruh Arsip & Simpan Data" White
    Write-ColorText "  [7] Lihat Ringkasan Cepat" White
    Write-ColorText "  [8] Update Isi Template (Word/Excel)" White
    Write-Host ""
    Write-ColorText "  [0] Keluar" DarkGray
    Write-Host ""
}

function Read-YearMonth {
    $yearInput = (Read-Host "  Tahun (contoh: 2026)").Trim()
    $year = [int]$yearInput
    if ($year -ge 24 -and $year -le 99) { $year += 2000 }
    $month = [int]((Read-Host "  Bulan (1-12)").Trim())
    return @($year, $month)
}

function Show-QuickSummary {
    Write-Host ""
    Write-ColorText "  RINGKASAN CEPAT ARSIP (Single-Source Validation)" Yellow
    Write-Host "  ------------------------------------------------------------------"
    
    $yearFolders = Get-ChildItem -LiteralPath $Script:BasePath -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '^\w=PROTHESA \d{4}$' } | 
        Sort-Object Name
    
    foreach ($yf in $yearFolders) {
        Write-Host ""
        Write-ColorText "  $($yf.Name)" Cyan
        
        $monthFolders = Get-ChildItem -LiteralPath $yf.FullName -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match '^\d+=PROTHESA' } |
            Sort-Object { [int]($_.Name -replace '=.*', '') }
        
        foreach ($mf in $monthFolders) {
            $val = Test-ProthesaMonthValidation -MonthPath $mf.FullName
            
            $zipIcon = if ($val -and $val.Zip.Exists) { " [ZIP]" } else { "      " }
            $statusText = if ($val) { $val.StatusText } else { "Unknown" }
            $adminCount = if ($val) { "$($val.Admin.ValidCount)/5" } else { "0/5" }
            $berkasCount = if ($val) { "$($val.BerkasUmum.ValidCount)/9" } else { "0/9" }
            $patientCount = if ($val) { $val.Patients.Count } else { 0 }
            
            $statusColor = "DarkGray"
            if ($val) {
                switch ($val.StatusCode) {
                    "complete"     { $statusColor = "Green" }
                    "ready_to_zip" { $statusColor = "Cyan" }
                    "in_progress"  { $statusColor = "Yellow" }
                    default        { $statusColor = "DarkGray" }
                }
            }
            
            $statusLine = "     $zipIcon $($mf.Name) | Status: {0,-13} | Admin: {1,-3} | Berkas: {2,-3} | Pasien: {3}" -f $statusText, $adminCount, $berkasCount, $patientCount
            Write-ColorText $statusLine $statusColor
        }
    }
    Write-Host ""
}

function Test-ArchiveEmpty {
    <#
    .SYNOPSIS
    True jika belum ada folder arsip tahun (fresh clone GitHub).
    #>
    $yearFolders = Get-ChildItem -LiteralPath $Script:BasePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\w=PROTHESA \d{4}$' }
    return ($null -eq $yearFolders -or @($yearFolders).Count -eq 0)
}

function Start-FirstRunSetup {
    <#
    .SYNOPSIS
    Wizard setup awal untuk CLI (fresh clone): tawarkan buat bulan berjalan / pilih folder / lanjut kosong.
    Aman dipanggil berulang; no-op jika arsip sudah ada.
    #>
    if (-not (Test-ArchiveEmpty)) { return }
    $sample = $null
    if (Get-Command Find-ProthesaBundle -ErrorAction SilentlyContinue) {
        try { $sample = Find-ProthesaBundle } catch { $sample = $null }
    }
    Write-Host ""
    Write-ColorText "  SELAMAT DATANG — arsip belum ditemukan (fresh clone)." Cyan
    Write-ColorText "  Base path: $Script:BasePath" DarkGray
    Write-ColorText "  [1] Buat bulan berjalan sebagai awal (disarankan untuk coba-coba)" White
    Write-ColorText "  [2] Lanjut dengan arsip kosong (nanti buat via menu [1])" White
    if ($sample) { Write-ColorText "  [3] Pasang data contoh terenkripsi ($($sample.Name))" White }
    Write-Host ""
    $c = (Read-Host $(if ($sample) { "  Pilihan [1/2/3]" } else { "  Pilihan [1/2]" })).Trim()
    if ($c -eq '1') {
        $now = Get-Date
        New-MonthFolder -Year $now.Year -Month $now.Month -Force -NoPromptCopy | Out-Null
        Write-ColorText "  Contoh bulan awal dibuat. Lihat ringkasan via menu [7]." Green
    } elseif ($c -eq '3' -and $sample) {
        try {
            $r = Install-ProthesaSample -BundleFile $sample.FullName -BasePath $Script:BasePath
            Write-ColorText "  Sampel dipasang: $($r.Path) ($($r.Files) file)." Green
        } catch { Write-ColorText "  Gagal pasang sampel: $($_.Exception.Message)" Red }
    } else {
        Write-ColorText "  Mode arsip kosong. Panduan template privat: _TEMPLATES/README.md" DarkGray
    }
    if (-not (Get-TemplateSourceDir)) {
        Write-ColorText "  Template belum ada (repo publik kosong). Copy template akan memberi panduan." Yellow
    }
}

function Start-ProthesaManager {
    Start-FirstRunSetup
    while ($true) {
        Show-Menu
        $choice = (Read-Host "  Pilihan").Trim()
        
        switch ($choice) {
            "1" {
                Write-Host ""
                Write-ColorText "  BUAT FOLDER BULAN BARU" Yellow
                $ym = Read-YearMonth
                New-MonthFolder -Year $ym[0] -Month $ym[1] | Out-Null
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "2" {
                Write-Host ""
                Write-ColorText "  COPY TEMPLATE" Yellow
                $ym = Read-YearMonth
                Copy-TemplatesFromPrevious -Year $ym[0] -Month $ym[1] | Out-Null
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "3" {
                Write-Host ""
                Write-ColorText "  BUAT FOLDER PASIEN" Yellow
                $ym = Read-YearMonth
                $name = (Read-Host "  Nama pasien").Trim()
                if ([string]::IsNullOrWhiteSpace($name)) {
                    Write-ColorText "  Nama pasien tidak boleh kosong" Red
                } else {
                    New-PatientFolder -Year $ym[0] -Month $ym[1] -PatientName $name | Out-Null
                }
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "4" {
                Write-Host ""
                Write-ColorText "  BATCH BUAT FOLDER PASIEN" Yellow
                $ym = Read-YearMonth
                New-BatchPatients -Year $ym[0] -Month $ym[1]
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "5" {
                Write-Host ""
                Write-ColorText "  ZIP FOLDER BULAN" Yellow
                $ym = Read-YearMonth
                Compress-MonthToZip -Year $ym[0] -Month $ym[1] | Out-Null
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "6" {
                Export-StatusJson
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "7" {
                Show-QuickSummary
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "8" {
                Write-Host ""
                Write-ColorText "  UPDATE ISI TEMPLATE (WORD/EXCEL)" Yellow
                $ym = Read-YearMonth
                Update-AllTemplates -Year $ym[0] -Month $ym[1] | Out-Null
                Read-Host "  Tekan Enter untuk lanjut..."
            }
            "0" {
                Write-Host ""
                Write-ColorText "  Sampai jumpa!" Cyan
                Write-Host ""
                return
            }
            default {
                Write-ColorText "  Pilihan tidak valid" Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ============================================================================
# JALANKAN
# ============================================================================
# Bila environment variable `PROTHESA_SKIP_MENU` diset, jangan jalankan menu interaktif.
if (-not $env:PROTHESA_SKIP_MENU) {
    Start-ProthesaManager
}


