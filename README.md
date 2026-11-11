# Google Antigravity Native Android

Repositori resmi untuk pembangunan aplikasi native Android **Google Antigravity IDE** berbasis arsitektur ARM64 standalone.

---

## 🎯 Gambaran Umum

Proyek ini menghadirkan pengalaman penuh **Google Antigravity AI Code Editor** langsung di perangkat Android tanpa ketergantungan pada browser desktop eksternal:
- **Native Host:** Aplikasi Android Native Kotlin dengan akselerasi perangkat keras GPU dan memory scavenging.
- **Standalone AI Core:** Binary engine Go (`language_server`) 64-bit yang dipatch untuk kompatibilitas arsitektur bionic/glibc Android ARM64.
- **Local Environment:** Menjalankan runtime mandiri di `127.0.0.1` dengan penanganan DNS resolver publik (`8.8.8.8`, `1.1.1.1`) dan auto-cd ke direktori kerja internal (`/storage/emulated/0`).

---

## 🛠️ Pipeline CI/CD Multi-Stage

Pipeline GitHub Actions dirancang modular dengan standar otomatisasi modern:

1. **Stage 1: Lint & Validation (`validate`)**
   - Verifikasi sintaks skrip dan integritas berkas repositori.
2. **Stage 2: Runtime Integrity & Patching (`prepare-runtime`)**
   - Menyiapkan binary engine ARM64, patch LSE ARMv8.0-A bypass, crash suppressor, dan penataan direktori runtime.
3. **Stage 3: Android Release Build (`build-apk`)**
   - Kompilasi native APK menggunakan Gradle & OpenJDK 17.
4. **Stage 4: Checksum & Verification (`checksums`)**
   - Pembuatan hash SHA-256 berkas rilis untuk verifikasi integritas data.
5. **Stage 5: Automated Release (`publish-release`)**
   - Distribusi otomatis binary APK dan runtime saat tag versi dipublikasikan atau di-trigger secara manual.

---

## 📂 Struktur Proyek

```text
├── .github/
│   └── workflows/
│       └── ci.yml          # Pipeline CI/CD Multi-Stage
├── .gitignore              # Konfigurasi pengabaian berkas build
└── README.md               # Dokumentasi utama proyek
```

---

## 📄 Lisensi & Hak Cipta
Hak cipta kode host dilisensikan untuk pengembangan komunitas. Google Antigravity adalah merek dagang dan properti dari Google LLC / DeepMind.
