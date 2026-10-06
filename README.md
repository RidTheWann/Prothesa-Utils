# Prothesa Util

**Tools otomasi dan manajemen arsip klaim prothesa gigi BPJS — drg. Danny Hanggono, Praktek Waru.**
100% PowerShell native (WinForms + CLI), tanpa server dan tanpa dependensi eksternal.

*Developer: Ridwan Gatro (RidTheWann)*
*Versi: 2.1.0*

---

## Cara Pakai (Pengguna Akhir)

Aplikasi **wajib diinstall** — file EXE tidak bisa dijalankan langsung (double-click tanpa install akan menampilkan peringatan).

### Opsi A — Setup.exe (disarankan)

1. Jalankan `ProthesaUtil-Setup-2.1.0.exe` (dari halaman Releases).
2. Jika muncul SmartScreen ("Windows protected your PC") karena file belum ditandatangani digital: pilih *More info* → *Run anyway*.
3. Ikuti wizard (Next → Install → Finish). Tidak butuh hak admin.
4. Centang "Pasang data contoh terenkripsi" bila tersedia — sampel bulan terakhir akan di-decrypt otomatis ke folder data.

Menjalankan Setup saat aplikasi sudah terinstall akan ditolak dengan peringatan (uninstall dulu versi lama).

### Opsi B — Installer PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Prothesa.ps1
```

Menginstall ke `%LocalAppData%\ProthesaUtil` (EXE + data contoh + shortcut + entri Uninstall).
Install ulang tanpa `-Force` akan ditolak bila sudah terinstall.

### Mode developer (tanpa install)

Jalankan langsung dari source untuk pengembangan:

```powershell
# GUI
powershell -ExecutionPolicy Bypass -STA -File .\ProthesaWinUtil.ps1

# CLI
powershell -ExecutionPolicy Bypass -File .\ProthesaManager.ps1
```

---

## Komponen

| Komponen | File | Kegunaan |
|---|---|---|
| GUI Desktop | `ProthesaWinUtil.ps1` / `ProthesaUtil.exe` | Antarmuka WinForms: ringkasan, buat bulan, copy template, kelola pasien, isi dokumen, ZIP, monitoring pohon status |
| CLI Terminal | `ProthesaManager.ps1` | Menu interaktif terminal + fungsi validasi terpusat (`Test-ProthesaMonthValidation`) |
| Vault Data | `ProthesaDataVault.ps1` | Kompres ZIP + enkripsi DPAPI untuk data penting (format `.prothesa`) |
| Installer PS | `Install-Prothesa.ps1` / `Uninstall-Prothesa.ps1` | Install/uninstall per-user tanpa admin |
| Installer Setup | `installer/ProthesaUtil.iss` + `Build-Setup.ps1` | Membangun `Setup.exe` via Inno Setup |
| Build | `Build-Prothesa.ps1` / `Merge-Prothesa.ps1` | Merge single-file, ZIP portable, compile EXE |

---

## Data Penting Terenkripsi (Vault)

Data penting dibundel sebagai `.prothesa` (ZIP terkompres → dienkripsi DPAPI akun Windows lokal):

- Tanpa password, tetapi **hanya bisa dibuka di akun/mesin yang membuatnya** (prioritaskan lokal).
- Bundel bawaan berisi **sampel 1 bulan terakhir** dan dipasang otomatis saat install / via tombol wizard setup awal.
- File `.prothesa` tidak pernah di-commit ke repo publik (di-ignore).

Fungsi terkait: `New-ProthesaBundle`, `Test-ProthesaBundle`, `Expand-ProthesaBundle`, `New-ProthesaSampleBundle`, `Install-ProthesaSample`, `Find-ProthesaBundle` (lihat `ProthesaDataVault.ps1`).

---

## Template Master (`_TEMPLATES/`)

Repo publik sengaja **tidak menyertakan** file template asli (`.doc`/`.xlsx` berisi kop dan data praktek).
Template resmi disimpan di repo privat dan dipasang sebagai submodule — lihat `_TEMPLATES/README.md` dan `.gitmodules.example`.

Urutan pencarian template (`Get-TemplateSourceDir`):

1. Folder `_TEMPLATES/` lokal (standalone)
2. Folder `_TEMPLATES-private/` (submodule privat)
3. Folder arsip bulan sebelumnya (fallback dinamis)

Tanpa template pun aplikasi tetap berjalan (buat folder bulan/pasien); hanya fitur Copy Template yang memberi panduan.

---

## Validasi Single-Source (`Test-ProthesaMonthValidation`)

Satu-satunya sumber kebenaran status kelengkapan, dipakai GUI maupun CLI:

1. **5 berkas administrasi** (root bulan): Administrasi Klaim (xlsx), REKAP PROTHESA, Surat Pengantar, Pernyataan Klaim Tagihan, Pernyataan Tidak Ada Tercecer — ukuran > 0 byte.
2. **9 berkas umum** (folder BERKAS UMUM, PDF): BAST, BAKB, BAHV, SPTJM, Pernyataan Tidak Ada Klaim Tercecer, FPK, Rekap Prothesa, Kwitansi, SPKTPK.
3. **Berkas pasien RJTP**: tiap folder pasien wajib berisi BUKTI LAYANAN, FKPP, dan RESEP PROTHESA (PDF non-zero byte).
4. **File ZIP** bulan di folder tahun.

Status: `complete` (Lengkap) / `ready_to_zip` (Siap ZIP) / `in_progress` (Belum Lengkap) / `empty` (Kosong).

---

## Tab GUI

1. **Beranda** — ringkasan tahun/bulan/pasien/lengkap, lokasi arsip, scan + ringkasan teks.
2. **Buat Bulan** — struktur folder bulan + subfolder KLAIM, BERKAS UMUM, RJTP.
3. **Copy Template** — salin 5 template master.
4. **Kelola Pasien** — tambah satuan atau batch + placeholder standar.
5. **Isi Dokumen** — auto-fill Word/Excel via COM (FPK, kasus, biaya, tanggal TTD, romawi) dengan pelepasan memori aman.
6. **Kompresi ZIP** — arsip bulan siap kirim.
7. **Monitoring Arsip** — pohon status interaktif; double-click membuka folder di Explorer.

Menu CLI (`ProthesaManager.ps1`): buat bulan, copy template, pasien satuan/batch, ZIP, scan, ringkasan, update template, keluar.

---

## Struktur Repo (publik)

```
Prothesa-Utils/
├── ProthesaWinUtil.ps1 / ProthesaManager.ps1 / ProthesaDataVault.ps1
├── Merge-Prothesa.ps1 / Build-Prothesa.ps1 / Build-Setup.ps1
├── Install-Prothesa.ps1 / Uninstall-Prothesa.ps1
├── JALANKAN *.bat, BUAT/UPDATE-SHORTCUT, Prothesa.version.json
├── installer/ProthesaUtil.iss + installer/Seed-Sample.ps1
└── _TEMPLATES/README.md (+ .gitkeep)
```

Yang TIDAK masuk repo (di-ignore): folder arsip (`A=`, `B=`, `C=`, ...), `*.prothesa`, `dist/`, `installer/Output/`, `prothesa-status.json`, `ProthesaConfig.json`.

Binari rilis (`ProthesaUtil.exe`, `Setup.exe`, ZIP portable) didistribusikan via halaman **Releases**, bukan commit.

---

## Build dari Source

```powershell
# Merge single-file
powershell -ExecutionPolicy Bypass -File .\Merge-Prothesa.ps1

# Portable ZIP (butuh ps2exe bila pakai -MakeExe)
powershell -ExecutionPolicy Bypass -File .\Build-Prothesa.ps1 -MakeExe

# Setup.exe (butuh Inno Setup 6 / otomatis via winget bila belum ada)
powershell -ExecutionPolicy Bypass -File .\Build-Setup.ps1
```

Catatan: EXE dikompilasi x64 + STA. Untuk COM Word/Excel, samakan bitness EXE dengan instalasi Office.

---

## FAQ

**Apakah butuh Node.js / Python / server?**
Tidak. 100% PowerShell + .NET bawaan Windows.

**Word/Excel hang saat auto-fill?**
Script memakai `FinalReleaseComObject` + GC ganda; proses latar ditutup bersih bila error.

**Data lama tertimpa saat buat bulan baru?**
Tidak. File/folder yang sudah ada dilewati (skip), termasuk pemasangan sampel.

**Bundel `.prothesa` tidak bisa dibuka di PC lain?**
Benar, itu sifat DPAPI (terikat akun/mesin pembuat). Pack ulang sampel di PC tersebut.

---

*Dikembangkan oleh Ridwan Gatro (RidTheWann) untuk efisiensi arsip klaim prothesa gigi drg. Danny Hanggono.*
