# Penyimpanan lokal NotchUI

Tidak ada server database, SQLite, akun, atau sinkronisasi. Implementasi F16 memakai `Windows.Storage.ApplicationData.Current.LocalSettings` sesuai arsitektur packaged WinUI 3. Windows mengelola lokasi per pengguna/per identitas paket di Local App Data; aplikasi tidak membangun path manual. Tidak ada dependency baru: JSON memakai `System.Text.Json` dari .NET 8.

## Model dan schema

Satu key `NotchUI.Settings` menyimpan satu string JSON UTF-16 kecil, batas baca 4096 karakter (jauh di bawah batas value LocalSettings 8 KB untuk payload aktual). Contoh versi 1:

```json
{"SchemaVersion":1,"Settings":{"Width":320,"Height":34,"CornerRadius":16,"BackgroundColor":"#000000","ClockEnabled":true,"BatteryEnabled":true,"MediaEnabled":true}}
```

`Models/NotchSettings.cs` adalah sumber tunggal default dan batas. Ukuran memakai DIP, lebar 200–520, tinggi 28–64, radius 0–32 dan tidak lebih dari setengah dimensi terkecil. `Normalize(availableWidth, availableHeight)` juga menjepit ukuran ke ruang monitor, termasuk monitor lebih kecil dari batas minimum. Pemanggil memasok ruang monitor aktual dalam DIP sebelum menerapkan geometri. NaN/infinity kembali ke default lalu dijepit. Warna wajib `#RRGGBB`, dinormalisasi uppercase dan opak; warna tidak valid kembali ke hitam. Tiga boolean default aktif. Field yang hilang pada schema yang dikenal memakai default; tipe JSON salah membatalkan snapshot. Jam, baterai, metadata/sesi media, HWND, state hover dan posisi jendela tidak disimpan.

## Kontrak integrasi

`ISettingsService.Load()` memulihkan snapshot tervalidasi; `Save(snapshot)` mengembalikan bool dan `LastError` untuk InfoBar nonmodal. Satu service dipakai bersama dalam proses. UI menerapkan snapshot segera, menjadwalkan simpan tertunda singkat setelah perubahan slider (sekitar 250–500 ms), dan melakukan flush perubahan tertunda sebelum Exit. Service sendiri tidak membuat timer/thread UI; penundaan adalah tanggung jawab pemilik state agar callback tidak menulis snapshot lama setelah snapshot baru. Kegagalan simpan tidak membatalkan preferensi di memori. Retry memanggil Save pada snapshot terakhir.

## Versioning dan migrasi

`SchemaVersion=1` adalah schema awal; tidak ada data lama yang perlu dimigrasikan. Parser menolak dokumen tanpa versi, versi tidak dikenal, root/type salah, atau melebihi batas. Penambahan field opsional pada versi yang sama wajib mempunyai default yang kompatibel. Perubahan arti/struktur menaikkan versi serta menambahkan migrasi eksplisit yang diuji sebelum menyimpan format baru. Saat versi lebih baru ditemukan, aplikasi menggunakan default untuk sesi dan menolak simpan agar downgrade tidak menimpa data masa depan. Tidak ada migrasi destruktif otomatis.

## Konsistensi dan pemulihan

Seluruh field diserialisasi dahulu, lalu disimpan lewat satu assignment value LocalSettings; tidak ada rangkaian update per field yang dapat meninggalkan campuran ukuran/warna. Lock lokal mengurutkan Load/Save dalam satu service. Sebelum mengganti snapshot valid, salinan sebelumnya disimpan pada `NotchUI.Settings.LastGood`. Jika snapshot utama rusak, loader mencoba cadangan tervalidasi, lalu default aman; file/key tidak dihapus otomatis. Data hilang langsung memakai default. Kegagalan akses storage ditangkap dan diubah menjadi status, bukan crash aplikasi.

LocalSettings mengelola persistensi sistem; aplikasi tidak mengklaim transaksi lintas dua key, jaminan fsync saat kehilangan daya, atau backup penuh. Kegagalan di antara assignment backup dan primary masih meninggalkan primary lama yang valid. Crash setelah assignment primary dapat dipulihkan dari versi tersimpan Windows/cadangan. Tidak diperlukan temporary file/rename karena bukan storage file JSON mandiri. Satu-instance aplikasi wajib dijaga pada bootstrap; lock bukan mutex lintas proses.

## Perlindungan data dan verifikasi

Hanya preferensi nonrahasia disimpan dalam sandbox profil Windows pengguna. Jangan menaruh token, metadata media, log aktivitas, atau data pribadi di schema ini. Tidak ada enkripsi aplikasi karena bukan data rahasia; batas perlindungan adalah akun Windows dan akses storage paket. Uninstall/reset aplikasi dapat menghapus preferensi; ini bukan backup pengguna. Pesan error tidak menampilkan isi JSON atau path profil.

Jalankan `dotnet run --project tests/NotchUI.Settings.SelfCheck` pada mesin dengan .NET 8. Self-check tanpa paket NuGet menguji roundtrip seluruh field, JSON/type/version/ukuran tidak valid, field hilang, angka tidak valid, radius dan ruang monitor. Uji Windows tambahan wajib: ubah semua preferensi lalu Exit/start, rusakkan key utama (cadangan/default), gagalkan akses tulis (InfoBar/retry), dan pastikan exit mem-flush debounce. Self-check codec bukan bukti integrasi storage WinRT.
