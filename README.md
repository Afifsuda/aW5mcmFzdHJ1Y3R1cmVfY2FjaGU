# Antigravity Canvas (Flutter Android)

Proyek awal aplikasi Flutter Android (`com.afifsuda.canvas`) dengan pipeline CI/CD GitHub Actions yang mendukung Gradle cache dan Release Signing via GitHub Secrets.

## Fitur CI/CD
- **Gradle & Flutter Cache:** Mempercepat proses build dengan caching dependency Gradle (`gradle/actions/setup-gradle@v4`) dan Flutter SDK (`subosito/flutter-action@v2`).
- **Release Signing via Secrets:** Mendukung penandatanganan APK rilis menggunakan `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, dan `KEY_PASSWORD` di GitHub Secrets (dengan fallback aman jika secrets belum dikonfigurasi).
- **Auto GitHub Release:** Mempublikasikan `app-release.apk` secara otomatis ke GitHub Releases.
