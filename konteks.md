# Konteks Proyek — `aW5mcmFzdHJ1Y3R1cmVfY2FjaGU`

- **Repository:** `https://github.com/Afifsuda/aW5mcmFzdHJ1Y3R1cmVfY2FjaGU.git`
- **Branch:** `main`
- **Package / App ID:** `com.afifsuda.canvas` (Rust Native Android `arm64-v8a`)

## Arsitektur & File Utama
1. **Relay Server (`relay_cf/` + `.github/workflows/deploy-relay.yml`)** — **TETAP AKTIF & DIAMANKAN**
   - Cloudflare Workers + Durable Object WebSocket relay.
   - Endpoint aktif: `wss://aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev`
2. **Aplikasi Rust Native (`Cargo.toml`, `src/lib.rs`, `android/`)**
   - Kanvas kosong bersih berbasis Rust (`android-activity` + `ndk-sys`, `NativeActivity`, warna `#F7F7F5`).
   - Tetap menyimpan konstanta `RELAY_BASE_WS_URL` di `src/lib.rs`.
3. **CI/CD Build & Release (`.github/workflows/ci.yml`)**
   - Build `cargo ndk -t arm64-v8a -p 24 -o android/app/src/main/jniLibs build --release` + `gradle -p android assembleRelease` (`compileSdk 36`, `minSdk 24`, `targetSdk 35`).
   - Signing konsisten memakai GitHub Secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) dan publish `app-release.apk` ke GitHub Releases.

## Status Terakhir
- Proyek bermigrasi dari Flutter ke **Rust Native Android** (kanvas kosong `#F7F7F5`).
- Cloudflare Worker (`relay_cf/`) tetap aman dan aktif.
