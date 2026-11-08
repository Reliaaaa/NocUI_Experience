# notch-windows — Design

Referensi: `01-features.md`, `02-architecture.md`. Tiga window terpisah (Notch, Dock, Settings) — lihat §7 arsitektur. Semua desain di bawah untuk **MVP (Rilis 1)**; komponen Rilis 2 (Control Center, Calendar, Todo, dst.) ditandai *(R2)* dan hanya diberi kerangka ringkas.

> **Alat desain**: plugin Canva tidak tersambung di sesi ini. Dokumen ini memakai wireframe teks/ASCII sebagai pengganti, sesuai fallback yang diizinkan skill fullstack-app-team ("Bila Canva tidak tersambung, buat wireframe teks dan beri tahu pengguna").

> **Aset**: semua bentuk, warna, dan ikon di bawah adalah rancangan original. Tidak ada logo/ikon/aset bermerek pihak ketiga ("Gili", "Poni") yang dirujuk atau disalin — hanya pola desain generik genre "notch utility" (pill shape, glass blur, rounded dock) yang dipakai banyak aplikasi sejenis.

---

## 1. Peta Navigasi & State — Notch Window

```
                    ┌───────────────┐
      (boot)  ───▶  │   COLLAPSED   │◀───────────────┐
                    └───────┬───────┘                │
                            │ hover pill / klik /     │ timeout tanpa interaksi
                            │ Alt+N (F-006)            │ (tidak hover + tidak pinned)
                            ▼                          │
                    ┌───────────────┐                 │
                    │  EXPANDING    │  (anim <200ms)   │
                    └───────┬───────┘                 │
                            ▼                          │
                    ┌───────────────┐   klik luar /   │
                    │   EXPANDED    │──Esc/Alt+N──────┘
                    └───────┬───────┘
                            │ drag file dari Explorer masuk area notch
                            ▼
                    ┌───────────────┐
                    │  DRAG-OVER    │  highlight ring + shelf sementara (F-005a)
                    └───────┬───────┘
                            │ drop / drag leave
                            ▼
                      (kembali ke EXPANDED)

   Dari state manapun (kecuali DRAG-OVER) ──▶ app lain fullscreen terdeteksi ──▶ HIDDEN
   HIDDEN ──▶ mouse mendekat top-edge (±4px, dwell 150ms) ──▶ COLLAPSED (slide-down)
```

State tambahan lintas-transisi:
- **Loading**: service belum punya data pertama (mis. SMTC belum ada sesi aktif, sensor pertama kali baca). Tidak memblokir notch tetap collapsed; slot info yang loading tampil skeleton shimmer.
- **Error**: service gagal permanen (mis. LibreHardwareMonitor butuh admin dan ditolak). Slot terkait tampil ikon "—" netral, bukan crash atau teks error mentah.

---

## 2. Komponen / Layar

### 2.1 Closed Notch (bagian dari Notch Window, state COLLAPSED/HIDDEN)

**Tujuan**: ringkasan sekilas tanpa mengganggu — info kiri/kanan pilihan user + jam tengah (F-004, F-005).

```
┌──────────────────────────────────────────────────┐
│  ⚡78%   🌙 21°C        12:47        ▶ Dua Lipa ♪  │   ← pill, radius penuh (999px)
└──────────────────────────────────────────────────┘
        slot kiri        jam tengah      slot kanan
      (user-pilih)      (selalu ada)   (now-playing jika
                                          musik main,
                                        else user-pilih)
```

Komponen: `ClosedNotchView` → `PillContainer` (Mica/Acrylic brush) → `InfoSlotLeft`, `ClockCenter`, `InfoSlotRight`.

State:
| State | Tampilan |
|---|---|
| Sukses | Ikon + nilai metrik (mis. `⚡78%`), teks jam HH:mm, now-playing marquee bila judul lagu panjang |
| Loading (metrik belum ada data) | Ikon abu-abu + shimmer bar pendek menggantikan angka |
| Error (sensor gagal permanen) | Ikon metrik + `—`, tidak ada retry visible (retry otomatis background) |
| Kosong (user pilih "none" di slot) | Slot disembunyikan, pill menyusut mengikuti lebar konten aktif |
| Drag-over | Pill melebar halus, ring highlight 2px warna aksen, label "Lepas untuk buka" muncul di tengah |

### 2.2 Expanded Panel (Notch Window, state EXPANDED)

**Tujuan**: hub cepat — tab Dashboard & Music untuk MVP; Control Center/Calendar jadi tab tambahan di R2.

```
┌────────────────────────────────────────────────────────────┐
│  ● ● ●                                              ⚙ ⤬    │  ← tab dots / close
├────────────────────────────────────────────────────────────┤
│  [ Dashboard ]   [ Music ]                                  │  ← segmented control
├────────────────────────────────────────────────────────────┤
│                                                               │
│   (konten tab aktif — lihat 2.3 / 2.4)                       │
│                                                               │
└────────────────────────────────────────────────────────────┘
```

State: Loading (skeleton card saat panel baru expand), Error (toast kecil di dalam panel, tidak menutup panel), Sukses (konten penuh), Kosong (tab Dashboard belum ada toggle dikonfigurasi → tampilkan CTA "Atur di Settings").

### 2.3 Dashboard Tab (dalam Expanded Panel)

**Tujuan**: quick toggle + info ringkas (F-020, F-021, F-022).

```
┌─────────────────────────────┬─────────────────────────────┐
│  Wi-Fi      [●──]  ON        │  Bluetooth  [──○]  OFF       │
│  Dark Mode  [●──]  ON        │  Mute Mic   [──○]  OFF       │
├─────────────────────────────┴─────────────────────────────┤
│  🔒 Lock PC                                                 │
├──────────────────────────────────────────────────────────┤
│  🌤  21°C  Cerah berawan — Surabaya        (placeholder/MVP)│
│  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░  Hari berjalan 52%                │
└──────────────────────────────────────────────────────────┘
```

State: Loading (toggle disabled + spinner kecil saat baca state OS pertama kali), Error (toggle gagal apply → otomatis revert + inline text merah singkat "Gagal, coba lagi"), Sukses, Kosong (tidak berlaku — toggle selalu P0 minimal 4 sesuai kriteria F-020).

### 2.4 Music / Now-Playing Tab

**Tujuan**: now-playing SMTC + kontrol (F-010, F-011, F-012).

```
┌──────────────────────────────────────────────────────────┐
│   ┌────────┐   Dua Lipa — Houdini                          │
│   │ album  │   Future Nostalgia                            │
│   │ art    │   ⏮   ⏸   ⏭                                  │
│   └────────┘   ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  1:42 / 3:30           │
└──────────────────────────────────────────────────────────┘
```

State:
- **Kosong** (tidak ada sesi SMTC aktif): placeholder ikon nada musik abu-abu + teks "Tidak ada musik yang diputar", kontrol disabled.
- **Loading**: album art shimmer, judul/artis shimmer bar.
- **Error** (sesi SMTC error / app sumber crash): fallback ke state Kosong (graceful, tidak tampil pesan teknis).
- **Sukses**: seperti wireframe di atas, marquee bila teks judul terlalu panjang untuk lebar panel.

### 2.5 Dock Bar (window terpisah, F-040/F-041)

**Tujuan**: akses cepat app berjalan + pinned, posisi bottom-center.

```
   ╭───────────────────────────────────────────────────╮
   │  [🗂]  [🌐]  [💬]  |  [▲ running app, magnified]    │
   ╰───────────────────────────────────────────────────╯
```

State: Sukses (ikon normal + magnify scale 1.0→1.4 halus saat hover, indikator titik kecil di bawah ikon utk app running), Kosong (belum ada pinned app → dock tampil minimal dengan 1 ikon "+ Tambah" saja), Loading (saat `RunningAppsService` enumerasi pertama kali, ikon placeholder abu-abu), Error (ikon gagal diekstrak `ExtractIconEx` → fallback ikon generik "app persegi" bawaan).

### 2.6 Settings Window (F-050)

**Tujuan**: konfigurasi posisi, slot info, shortcut, tema dasar.

```
┌───────────────────────────────────────────┐
│ Settings                                   │
├───────────────────────────────────────────┤
│ Posisi Notch     (•) Menempel  ( ) Mengambang│
│ Slot Kiri        [ Baterai       ▾ ]        │
│ Slot Kanan       [ Now Playing   ▾ ]        │
│ Shortcut Toggle  [ Alt+N  ] [Ubah]          │
│ Tema             (•) Gelap  ( ) Terang       │
├───────────────────────────────────────────┤
│                              [Simpan otomatis]│
└───────────────────────────────────────────┘
```

State: Sukses (semua kontrol tersinkron `ISettingsStore`, tersimpan tanpa tombol submit eksplisit — auto-save per F-050), Error (konflik shortcut dengan OS → inline warning di bawah field, tidak menyimpan sampai diganti), Loading (field disabled sesaat saat pertama load dari disk, <100ms umumnya tidak terlihat).

### 2.7 *(R2) Control Center, Calendar, Todo/Notes/Pomodoro, Notification Mirror*
Kerangka saja untuk Rilis 2 — detail state penuh dikerjakan ulang oleh Designer saat Rilis 2 dimulai, mengikuti pola tab tambahan di §2.2 (`[ Dashboard ] [ Music ] [ Control ] [ Calendar ]`) dan window notifikasi mirror sebagai overlay di bawah Closed Notch (mengikuti pola Drag-over §2.1 untuk animasi muncul/hilang).

---

## 3. Design Tokens

### 3.1 Warna (dark mode = default)

| Token | Dark (default) | Terang | Catatan |
|---|---|---|---|
| `Surface.Pill` | `#1C1C1EB3` (rgba blur base) + Mica Alt | `#FFFFFFCC` + Mica | blur lewat `SystemBackdrop`, bukan solid |
| `Surface.Panel` | `#161618E0` | `#FAFAFAE6` | panel expanded, elevasi lebih tinggi dari pill |
| `Text.Primary` | `#F5F5F7` | `#1C1C1E` | kontras ≥ 7:1 di atas Surface.Panel |
| `Text.Secondary` | `#A9A9AE` | `#5B5B60` | kontras ≥ 4.5:1 (AA) |
| `Accent` | `#6E5BFF` (ungu-biru, netral — bisa diganti user di R2/F-110) | sama | dipakai ring drag-over, toggle ON, progress bar |
| `State.Success` | `#3DDC97` | `#1E9E6A` | indikator running/ON |
| `State.Error` | `#FF6B6B` | `#D83B3B` | dipakai minimal (fallback graceful lebih diutamakan dari teks error merah) |
| `Divider` | `#FFFFFF1A` | `#0000001A` | 10% opacity garis pemisah |

Varian tema opsional (F-110, R2): **Warna kustom** (ganti token `Accent`), **Glass** (blur tinggi, opacity surface diturunkan ~15%), **Frosted** (blur tinggi + noise texture halus, opacity surface dinaikkan ~85% untuk legibility). MVP hanya mengirim token Dark/Terang di atas.

### 3.2 Tipografi

- Font: **Segoe UI Variable** (default WinUI3, Display untuk angka jam, Text untuk label).
- Skala: `Caption` 12px/16px (label slot info kecil), `Body` 14px/20px (teks umum panel), `BodyStrong` 14px/20px semibold (judul lagu, nama toggle), `Title` 20px/28px (jam tengah closed-notch, header Settings), `Display` 28px/36px (opsional jam saat notch dalam mode "floating besar" — tidak dipakai MVP default).

### 3.3 Spacing & Radius

- Spacing scale (4px base): `4, 8, 12, 16, 24, 32`.
- Padding pill closed-notch: `8px` vertikal, `16px` horizontal per slot.
- Padding panel expanded: `16px` semua sisi, gap antar card `12px`.
- Radius: `Pill` = `9999px` (full capsule) untuk closed-notch dan dock; `Panel` = `24px` untuk expanded panel (rounded besar, konsisten "melebur" dari pill saat animasi expand); `Card` dalam panel = `16px`; `Control` (toggle, button kecil) = `12px`.

### 3.4 Elevasi / Blur

- Closed Notch & Dock: `SystemBackdrop = MicaBackdrop (Kind=BaseAlt)` — blur ringan, hemat GPU karena selalu on-screen.
- Expanded Panel: `DesktopAcrylicBackdrop` — blur lebih kuat untuk kontras saat overlay di atas app lain (acrylic lebih tepat untuk transient surface daripada Mica).
- Shadow: drop-shadow halus `0 8px 24px rgba(0,0,0,0.35)` di bawah pill/panel/dock agar terasa "mengambang", konsisten dengan opsi posisi "Mengambang" di Settings.

---

## 4. Aksesibilitas

- **Kontras**: semua pasangan Text/Surface di §3.1 divalidasi ≥ WCAG AA (4.5:1 teks normal, 3:1 teks besar/ikon). `Text.Primary` di atas `Surface.Panel` mencapai ~13:1 (dark) dan ~15:1 (terang) — jauh di atas AA.
- **Target sentuh/klik**: semua elemen interaktif (toggle, tombol kontrol musik, ikon dock, tab segmented) minimal **48×48px hit-area** meski visual ikon lebih kecil (pakai padding transparan di sekitar ikon) — mendukung F-touchscreen (disebut di README fitur referensi sebagai pola umum genre ini) dan juga mouse precision rendah.
- **Keyboard navigation**:
  - `Alt+N` expand/collapse (F-006), `Esc` collapse dari state manapun.
  - `Tab`/`Shift+Tab` berpindah antar kontrol dalam Expanded Panel mengikuti urutan visual (toggle → slider → tombol musik).
  - `Space`/`Enter` mengaktifkan toggle/tombol yang sedang fokus.
  - Dock: `Tab` masuk ke dock, panah kiri/kanan pindah antar ikon, `Enter` activate.
- **Narrator/screen reader**: semua `ToggleSwitch`, `Button`, `Slider` custom di Closed Notch dan Dock (yang dirender manual, bukan kontrol WinUI stok) wajib diberi `AutomationProperties.Name` deskriptif (mis. "Toggle Wi-Fi, aktif") dan `LiveSetting=Polite` pada slot info yang berubah otomatis (jam, now-playing) agar tidak spam narrator tiap detik — update nilai jam **tidak** di-announce, hanya perubahan lagu/toggle yang di-announce.
- **Fokus visual**: focus ring 2px `Accent` dengan offset 2px pada semua kontrol interaktif saat navigasi keyboard (berbeda dari hover state agar jelas dibedakan mouse vs keyboard — `:focus-visible` equivalent via `FocusVisualKind` WinUI).
- **Motion**: animasi expand/collapse dan magnify dock menghormati setting Windows "Show animations" (`SystemParametersInfo(SPI_GETCLIENTAREAANIMATION)`) — jika user mematikan animasi di OS, transisi state langsung tanpa easing panjang.

---

## 5. Catatan untuk Agent Berikutnya

- Services dev: Dashboard toggle (§2.3) butuh state optimistic-update + revert-on-error sesuai baris Error di tabel §2.3 — pastikan `IWifiBluetoothService`, dsb. (dari `02-architecture.md`) mengembalikan hasil sukses/gagal yang jelas, bukan fire-and-forget.
- QA: uji kontras token §3.1 di kedua tema, uji keyboard-only flow penuh (tanpa mouse) untuk expand notch → toggle Wi-Fi → collapse, dan uji Narrator pada Closed Notch slot saat lagu berganti (harus announce, jam tidak).
- Security: §2.6 Settings tidak menyimpan credential apa pun di MVP (F-050 hanya preferensi UI) — tidak ada permukaan serangan baru dari layar ini.
