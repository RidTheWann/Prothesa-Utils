# 🦷 Prothesa Manager

**Tools Otomasi & Manajemen Arsip Klaim Prothesa Gigi BPJS — drg. Danny Hanggono, Praktek Waru**  
*100% Pure PowerShell Native Ecosystem — Tanpa Server & Tanpa Dependensi Eksternal.*  
*Developer: Ridwan Gatro (RidTheWann)*

---

## 🌟 Ringkasan Arsitektur Proyek

Project ini dibangun sepenuhnya menggunakan **PowerShell** dengan antarmuka grafis native Windows Forms (WinForms) bertema gelap modern ala Chris Titus WinUtil, dipadukan dengan CLI interaktif untuk terminal:

| Komponen | File / Launcher | Kegunaan |
|---|---|---|
| 🖥️ **Modern Desktop GUI** | `JALANKAN PROTHESA UTIL.bat`<br>`ProthesaWinUtil.ps1` | Antarmuka grafis bergaya WinUtil modern, kartu navigasi, ringkasan real-time, monitoring pohon status arsip interaktif |
| ⚙️ **Terminal CLI Interaktif** | `JALANKAN MANAGER.bat`<br>`ProthesaManager.ps1` | CLI menu interaktif di terminal PowerShell untuk buat folder bulan, copy template, update dokumen, kompresi ZIP |
| 📁 **Master Template Mandiri** | `_TEMPLATES/`<br>`PACK-PROTHESA/_TEMPLATES/` | 5 berkas template bersih (.xlsx & .doc) yang dapat langsung dipakai di komputer/folder baru **tanpa memerlukan arsip tahun lama** |
| 🔍 **Single-Source Validation** | `Test-ProthesaMonthValidation` *(dalam `ProthesaManager.ps1`)* | Satu-satunya sumber kebenaran validasi kelengkapan berkas: 5 berkas admin, 9 berkas umum PDF non-zero byte, dan berkas pasien RJTP |

---

## ⚡ Quick Start (Mulai Cepat)

### 1. Jalankan via Launcher Desktop (.bat)
Cukup double-click file launcher di folder ini:
* **`JALANKAN PROTHESA UTIL.bat`** : Membuka antarmuka grafis Desktop Modern (Rekomendasi Utama).
* **`JALANKAN MANAGER.bat`** : Membuka terminal interaktif CLI.

### 2. Atau Jalankan Langsung via PowerShell
Buka PowerShell di folder project (`D:\Project prothesa utils`), lalu jalankan:
```powershell
# Jalankan GUI Modern
powershell -ExecutionPolicy Bypass -STA -File .\ProthesaWinUtil.ps1

# Atau jalankan Terminal CLI
powershell -ExecutionPolicy Bypass -File .\ProthesaManager.ps1
```

### 3. Buat / Perbarui Shortcut Desktop
Untuk memasang shortcut praktis di Desktop:
```powershell
powershell -ExecutionPolicy Bypass -File .\UPDATE-SHORTCUT.ps1
```

---

## 📁 Mekanisme Template Mandiri (`_TEMPLATES/`)

Script dirancang agar **dapat digunakan secara mandiri tanpa memerlukan folder root arsip historis** (`A=PROTHESA 2024`, `B=PROTHESA 2025`, atau `C=PROTHESA 2026`).

### Berkas Master Template:
1. `Administrasi Klaim TEMPLATE.xlsx` *(Excel formulir klaim & tanda terima)*
2. `REKAP PROTHESA TEMPLATE.doc` *(Word rekapitulasi pelayanan)*
3. `SURAT Pengantar ke BPJS klaim TEMPLATE.doc` *(Word surat pengantar)*
4. `surat pernyataan KLAIM TAGIHAN TEMPLATE.doc` *(Word surat pernyataan tagihan)*
5. `surat pernyataan tidak ada tercecer TEMPLATE.doc` *(Word surat pernyataan anti tercecer)*

### Prioritas Pengambilan Template:
1. **Folder `_TEMPLATES/` lokal** (Prioritas Utama — Standalone Mode)
2. Folder `PACK-PROTHESA\_TEMPLATES/` (Fallback portabel)
3. Folder arsip bulan sebelumnya (Fallback dinamis)

Jika project ini dipindahkan ke komputer baru yang belum memiliki riwayat tahun sebelumnya, sistem tetap **100% berfungsi normal** membuat bulan baru dan menyiapkan template.

---

## 🔍 Single-Source of Truth Validation (`Test-ProthesaMonthValidation`)

Seluruh pemeriksaan kelengkapan berkas dihitung secara eksklusif oleh fungsi PowerShell `Test-ProthesaMonthValidation` di `ProthesaManager.ps1`, sehingga hasil validasi di GUI WinUtil maupun CLI selalu 100% konsisten.

### Kriteria Validasi Komprehensif:
1. **5 Berkas Dokumen Administrasi Klaim (Root Bulan)**
   * `Administrasi Klaim *.xlsx` (Ukuran > 0 byte)
   * `REKAP PROTHESA *.doc` (Ukuran > 0 byte)
   * `SURAT Pengantar *.doc` (Ukuran > 0 byte)
   * `surat pernyataan KLAIM TAGIHAN *.doc` (Ukuran > 0 byte)
   * `surat pernyataan tidak ada tercecer *.doc` (Ukuran > 0 byte)
2. **9 Berkas Dokumen Umum (Folder `BERKAS UMUM`)**
   * BAST, BAKB, BAHV, SPTJM, PERNYATAAN TIDAK ADA KLAIM TERCECER, FPK, REKAP PROTHESA, KWITANSI, SPKTPK
   * Seluruh 9 berkas harus berupa PDF valid dengan ukuran **> 0 byte** (tidak corrupt / bukan placeholder kosong).
3. **Berkas Pasien Rawat Jalan Tingkat Pertama (RJTP)**
   * Setiap subfolder pasien (1, 2, 3...) wajib memiliki 3 berkas PDF non-zero byte:
     * `BUKTI LAYANAN [NAMA].pdf`
     * `FKPP [NAMA].pdf`
     * `RESEP PROTHESA [NAMA].pdf`
4. **Berkas Arsip ZIP**
   * File `<NamaBulan>.zip` wajib ada di folder induk tahun dengan ukuran > 0 byte.

### Klasifikasi Status Otomatis:
* 🟢 **Lengkap (`complete`)** : Admin 5/5, Berkas Umum 9/9, Pasien 100% lengkap, dan ZIP sudah dibuat.
* 🔷 **Siap ZIP (`ready_to_zip`)** : Admin 5/5, Berkas Umum 9/9, Pasien 100% lengkap, tinggal dikompresi ke ZIP.
* 🟡 **Belum Lengkap (`in_progress`)** : Masih ada berkas yang kurang atau masih berukuran 0 byte.
* ⚫ **Kosong (`empty`)** : Folder bulan baru dibuat, belum ada pengisian berkas.

---

## 🖥️ Panduan Antarmuka Desktop (Prothesa WinUtil GUI)

Antarmuka GUI menyediakan 7 tab navigasi cepat:

1. **🏠 Beranda** : Kartu ringkasan total tahun, bulan, pasien, dan bulan lengkap, pengaturan folder data arsip, serta tombol scan dan shortcut Explorer.
2. **🗓️ Buat Bulan** : Buat struktur folder bulan baru lengkap dengan subfolder KLAIM, BERKAS UMUM, dan RJTP dalam 1 klik.
3. **📋 Copy Template** : Salin dan otomatis sesuaikan nama 5 template master dari `_TEMPLATES/`.
4. **👥 Pasien** : Tambah pasien baru secara satuan atau batch (multi-nama sekaligus) dengan placeholder standar.
5. **✍️ Isi Dokumen** : Otomasi COM Interop untuk Word (.doc) dan Excel (.xlsx) — memperbarui nomor FPK, jumlah kasus, total biaya, dan tanggal TTD secara otomatis tanpa merusak formula Excel atau tata letak dokumen Word. Dilengkapi pembersihan memori aman (`FinalReleaseComObject`) untuk mencegah resource leak.
6. **🗜️ Zip Bulan** : Kompresi folder bulan menjadi arsip `.zip` siap kirim BPJS.
7. **📊 Monitoring** : Pohon status arsip interaktif (*TreeView*) dengan kode warna real-time. Double-click folder pada pohon untuk langsung membuka lokasinya di Windows Explorer.

---

## ⚙️ Panduan Menu Terminal CLI (`ProthesaManager.ps1`)

```
  ╔══════════════════════════════════════════════════════════╗
  ║   🦷  PROTHESA MANAGER — drg. Danny Hanggono            ║
  ║       Tools Otomasi Arsip Klaim BPJS                     ║
  ╚══════════════════════════════════════════════════════════╝

  [1] 📁 Buat Folder Bulan Baru
  [2] 📋 Copy Template dari Bulan Sebelumnya / _TEMPLATES
  [3] 👤 Buat Folder Pasien
  [4] 👥 Batch Buat Folder Pasien
  [5] 🗜️  ZIP Folder Bulan
  [6] 🔍 Scan Seluruh Arsip & Simpan Data
  [7] 📊 Lihat Ringkasan Cepat
  [8] 📝 Update Isi Template (Word/Excel)

  [0] ❌ Keluar
```

---

## 📁 Struktur Arsip Standar

```
PROTHESA PRAKTEK WARU/
├── _TEMPLATES/                         ← Master berkas template mandiri
│   ├── Administrasi Klaim TEMPLATE.xlsx
│   ├── REKAP PROTHESA TEMPLATE.doc
│   ├── SURAT Pengantar ke BPJS klaim TEMPLATE.doc
│   ├── surat pernyataan KLAIM TAGIHAN TEMPLATE.doc
│   └── surat pernyataan tidak ada tercecer TEMPLATE.doc
│
├── JALANKAN PROTHESA UTIL.bat          ← Launcher GUI WinUtil
├── JALANKAN MANAGER.bat                ← Launcher CLI Menu
├── ProthesaWinUtil.ps1                 ← Engine GUI Desktop Modern (WinForms)
├── ProthesaManager.ps1                 ← Engine CLI & Single-Source Validation
├── UPDATE-SHORTCUT.ps1                 ← Pembuat shortcut Desktop
├── README.md                           ← Dokumentasi panduan ini
│
├── A=PROTHESA 2024/
│   ├── 10=PROTHESA OKTOBER 2024/
│   └── ...
├── B=PROTHESA 2025/
│   ├── 1=PROTHESA JANUARI 25/
│   └── ...
└── C=PROTHESA 2026/
    ├── 1=PROTHESA JANUARI 26/
    │   ├── Administrasi Klaim drg. Danny JANUARI 26.xlsx
    │   ├── REKAP PROTHESA danny JANUARI 26.doc
    │   ├── SURAT Pengantar ke BPJS klaim JANUARI 26.doc
    │   ├── surat pernyataan KLAIM TAGIHAN JANUARI 26.doc
    │   ├── surat pernyataan tidak ada tercecer JANUARI 26.doc
    │   └── KLAIM PROTHESA GIGI DRG. DANNY JANUARI 2026/
    │       ├── BERKAS UMUM JANUARI 26/
    │       │   ├── 1. BAST JANUARI 25.pdf
    │       │   └── ... (9 PDF umum non-zero byte)
    │       └── RJTP-PROTHESA GIGI JANUARI 26/
    │           ├── 1/
    │           │   ├── BUKTI LAYANAN [NAMA].pdf
    │           │   ├── FKPP [NAMA].pdf
    │           │   └── RESEP PROTHESA [NAMA].pdf
    │           └── ... (folder pasien)
    ├── 1=PROTHESA JANUARI 26.zip
    └── ...
```

---

## ❓ FAQ & Troubleshooting

**Q: Apakah project ini memerlukan Node.js, Python, atau web server?**  
> **Tidak.** Project ini 100% native PowerShell (.NET WinForms) bawaan Windows. Tidak ada server background, tidak ada port yang dibuka, dan tidak ada file HTML eksternal.

**Q: Bagaimana jika Word atau Excel hang saat auto-update?**  
> Script telah dilengkapi dengan pembersihan COM Object aman (`FinalReleaseComObject` dan garbage collector ganda). Jika terjadi error tak terduga, proses Word/Excel di latar belakang ditutup secara bersih.

**Q: Apakah data lama akan tertimpa saat membuat bulan baru?**  
> Tidak. Script memiliki pengaman duplikasi: jika file atau folder sudah ada, script akan melewatinya (*skip*) dan tidak menimpa data yang telah dikerjakan.

---

*Dikembangkan untuk efisiensi dan otomasi arsip klaim prothesa gigi drg. Danny Hanggono.*
