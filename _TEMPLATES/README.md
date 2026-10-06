# _TEMPLATES — Master Template Privat (TIDAK di-commit ke repo publik)

Folder ini **sengaja kosong** di repo publik GitHub.

File asli (`*.doc`, `*.xlsx`) berisi kop surat, format klaim, dan data praktek
sehingga disimpan di **repo privat** dan dipasang sebagai submodule / copy manual.

## Cara pakai (pilih salah satu)

### Opsi A — Submodule privat (disarankan)
```powershell
# Contoh (ganti URL dengan repo privat kamu):
git submodule add https://github.com/USERNAME/prothesa-templates-private.git _TEMPLATES-private
# Lalu copy 5 file template ke _TEMPLATES/, atau arahkan BasePath ke folder tersebut.
```

Lihat contoh konfigurasi di `../.gitmodules.example`.

### Opsi B — Copy manual
1. Siapkan 5 file master (nama bebas, yang penting keyword-nya cocok):
   - `*Administrasi Klaim*.xlsx`
   - `*REKAP PROTHESA*.doc`
   - `*SURAT Pengantar*.doc`
   - `*surat pernyataan KLAIM*.doc`
   - `*surat pernyataan tidak*.doc`
2. Letakkan di folder `_TEMPLATES/` ini.
3. Aplikasi otomatis mendeteksinya (prioritas utama di `Get-TemplateSourceDir`).

Tanpa template pun aplikasi **tetap jalan**: kamu bisa buat folder bulan & pasien,
hanya fitur "Copy Template" akan memberi pesan panduan.
