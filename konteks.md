# Konteks Proyek — `aW5mcmFzdHJ1Y3R1cmVfY2FjaGU`

- **Repository:** `https://github.com/Afifsuda/aW5mcmFzdHJ1Y3R1cmVfY2FjaGU.git`
- **Branch:** `main`
- **Package / App ID:** `com.afifsuda.canvas` (Flutter Android `arm64-v8a`)

## Arsitektur & File Utama
1. **Relay Server (`relay_cf/` + `.github/workflows/deploy-relay.yml`)** — **TETAP AKTIF & DIAMANKAN**
   - Cloudflare Workers + Durable Object WebSocket relay.
   - Endpoint aktif: `wss://aw5mcmfzdhj1y3r1cmvfy2fjagu.sudaapip.workers.dev`
2. **Aplikasi Flutter (`lib/main.dart`, `android/app/src/main/kotlin/com/afifsuda/canvas/MainActivity.kt`)**
   - Dikosongkan kembali menjadi kanvas bersih (`CanvasHomeScreen`), sambil tetap menyimpan URL relay Cloudflare (`AppTokens.relayBaseWsUrl`) untuk pengembangan fitur berikutnya (misal IoT / Smart Home / Audio).
3. **CI/CD Build & Release (`.github/workflows/ci.yml`)**
   - Build `--target-platform android-arm64` dengan R8/ProGuard (`compileSdk 36`, `minSdkVersion 24`, `targetSdkVersion 35`).
   - Signing konsisten memakai GitHub Secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) dan publish `app-release.apk` ke GitHub Releases.

## Status Terakhir
- Aplikasi dikosongkan ke kanvas bersih (`Antigravity Canvas`).
- Cloudflare Worker (`relay_cf/`) dan workflow CI/CD tetap aman dan tidak dihapus.
