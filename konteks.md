# Konteks Proyek — `aW5mcmFzdHJ1Y3R1cmVfY2FjaGU`

- **Repository:** `https://github.com/Afifsuda/aW5mcmFzdHJ1Y3R1cmVfY2FjaGU.git`
- **Branch:** `main` (commit terakhir: `d0c1435`)
- **Package / App ID:** `com.afifsuda.canvas` (Flutter Android `arm64-v8a`)

## Arsitektur & File Utama
1. **Relay Server (`relay_cf/` + `.github/workflows/deploy-relay.yml`)**
   - Cloudflare Workers + Durable Object WebSocket relay.
   - Endpoint aktif: `wss://aw5mcmfzdhj1y3r1cmvfy2fjagu.sudaapip.workers.dev`
2. **Aplikasi Flutter (`lib/main.dart`, `android/app/src/main/kotlin/com/afifsuda/canvas/`)**
   - **HT Suara (Walkie-Talkie):** `AudioRecord` + `AudioTrack` (16kHz PCM mono, `NoiseSuppressor` + `AcousticEchoCanceler`) via WebSocket, dengan resolusi DoH IPv4 (`1.1.1.1` / `8.8.8.8`) untuk bypass DNS hijacking ISP seluler, room tersimpan (`SharedPreferences`), dan foreground `KeepAliveService`.
   - **Video Call:** `flutter_webrtc` (`^1.6.2+hotfix.4`) memakai Cloudflare Worker yang sama untuk WebRTC signaling (`offer`, `answer`, `ice`, `hangup`) + STUN gratis (`stun.l.google.com:19302`, `stun1.l.google.com:19302`, `stun.cloudflare.com:3478`).
3. **CI/CD Build & Release (`.github/workflows/ci.yml`)**
   - Build `--target-platform android-arm64` dengan R8/ProGuard (`android/app/proguard-rules.pro`, `compileSdk 36`, `minSdkVersion 24`, `targetSdkVersion 35`).
   - Signing konsisten memakai GitHub Secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) dan publish `app-release.apk` ke GitHub Releases.

## Status Terakhir
- **HT Suara:** Berjalan normal (WiFi & Data Seluler).
- **Video Call:** Sebelumnya status menunjukkan tersambung tapi video remote belum muncul.
- **Perbaikan terbaru (`d0c1435` / Release `v1.0.0-build37`):**
  - Menangani `event.streams` kosong pada `pc.onTrack` (`unified-plan`) dengan membuat `MediaStream` manual (`createLocalMediaStream('remote_stream')`), menambah fallback `pc.onAddStream`, dan mengaktifkan `Helper.setSpeakerphoneOn(true)`.
  - **Belum sempat dites di HP** — langkah berikutnya: install `app-release.apk` dari release `v1.0.0-build37` di kedua HP dan tes Video Call; jika video masih belum muncul, lanjutkan debug dari `lib/main.dart`.
