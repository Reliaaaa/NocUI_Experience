# NocUI Experience

NocUI Experience adalah aplikasi desktop Windows dengan notch interaktif, berbasis Flutter dan integrasi native Windows. Implementasi utama berada di [`flutter_app/`](flutter_app/).

## Build dan pengujian

Pada Windows dengan Flutter SDK dan Visual Studio Desktop development with C++:

```powershell
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

Workflow Windows membangun bundle Flutter dan installer Inno Setup. Build dan tes otomatis tidak membuktikan perilaku runtime atau kesiapan rilis. Installer belum ditandatangani dan instalasi, overlay, input, media, DPI, serta migrasi pengaturan masih memerlukan pengujian Windows.

Kode WinUI sebelumnya dipertahankan di `src/` sebagai referensi dan pemulihan, bukan aplikasi yang dikemas oleh jalur build utama. Rincian dan batas migrasi ada di [catatan migrasi](docs/flutter-migration.md).
