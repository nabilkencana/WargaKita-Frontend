# WargaKita Mobile App (Frontend)

<p align="center">
  <img src="https://flutter.dev/assets/images/shared/brand/flutter/logo/flutter-lockup.png" width="160" alt="Flutter Logo" />
</p>

<p align="center">
  <b>Aplikasi Mobile WargaKita</b><br/>
  Aplikasi mobile untuk warga dalam mengakses layanan lingkungan secara digital.
</p>

---

## 📌 Deskripsi

**WargaKita Mobile App** adalah aplikasi berbasis **Flutter** yang digunakan oleh warga untuk mengakses berbagai layanan lingkungan secara digital, seperti:
- Melihat pengumuman RT/RW
- Mengirim laporan keluhan
- Tombol SOS darurat
- Pembayaran dana warga
- Manajemen profil warga

Aplikasi ini terhubung langsung dengan **WargaKita Backend API**.

---

## 🧠 Teknologi

- **Framework**: Flutter
- **Bahasa**: Dart
- **State Management**: Provider / Riverpod
- **HTTP Client**: Dio
- **Local Storage**: SharedPreferences
- **Push Notification**: Firebase Cloud Messaging (Opsional)
- **Maps**: Google Maps API (SOS)

---

## 📂 Struktur Folder

```bash
lib/
├── core/              # Config, constants, helpers
├── data/              # API service & models
├── modules/           # Feature-based modules
│   ├── auth/
│   ├── home/
│   ├── pengumuman/
│   ├── laporan/
│   ├── sos/
│   ├── dana/
│   └── profile/
├── widgets/           # Reusable widgets
├── routes/            # App routing
└── main.dart          # Entry point
```

---

### ⚙️ Environment Configuration

Buat file berikut:
```bash
lib/core/config/app_env.dart
```
Contoh app_env.dart
```dart
class AppEnv {
  static const String baseUrl = "http://localhost:3000";
  static const bool demoMode = true;
}
```


⚠️ Pastikan baseUrl sesuai dengan server backend.

---

### ▶️ Menjalankan Aplikasi
flutter pub get
flutter run


Untuk release:

flutter build apk --release

### 📦 Build APK (Untuk Submit Lomba)

File hasil build:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

### 🔐 Keamanan

Token disimpan secara lokal (SharedPreferences)

- HTTPS (disarankan saat production)

- Validasi input user

- Session logout otomatis

---

# 👨‍💻 Developer

- Nama: Mohammad Kencana
- Project: WargaKita

---

# 📄 Lisensi

Aplikasi ini dibuat untuk keperluan edukasi dan lomba inovasi digital.
Hak cipta © 2025 – WargaKita.

---
