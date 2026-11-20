use android_activity::{AndroidApp, MainEvent, PollEvent};
use std::ptr;

/// Cloudflare Worker WebSocket relay (diamankan untuk fitur berikutnya).
#[allow(dead_code)]
pub const RELAY_BASE_WS_URL: &str =
    "wss://aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev";

#[no_mangle]
fn android_main(app: AndroidApp) {
    let mut running = true;
    let mut has_window = false;

    while running {
        app.poll_events(None, |event| match event {
            PollEvent::Main(main_event) => match main_event {
                MainEvent::InitWindow { .. } => {
                    has_window = true;
                    draw_empty_canvas(&app);
                }
                MainEvent::WindowResized { .. } | MainEvent::RedrawNeeded { .. } => {
                    if has_window {
                        draw_empty_canvas(&app);
                    }
                }
                MainEvent::TerminateWindow { .. } => {
                    has_window = false;
                }
                MainEvent::Destroy => {
                    running = false;
                }
                _ => {}
            },
            _ => {}
        });
    }
}

fn draw_empty_canvas(app: &AndroidApp) {
    let Some(window) = app.native_window() else {
        return;
    };

    unsafe {
        let win_ptr = window.ptr().as_ptr();
        // RGBA_8888 (format = 1)
        ndk_sys::ANativeWindow_setBuffersGeometry(win_ptr, 0, 0, 1);

        let mut buffer: ndk_sys::ANativeWindow_Buffer = std::mem::zeroed();
        if ndk_sys::ANativeWindow_lock(win_ptr, &mut buffer, ptr::null_mut()) != 0 {
            return;
        }

        if !buffer.bits.is_null() && buffer.width > 0 && buffer.height > 0 && buffer.stride > 0 {
            // Off-white canvas (#F7F7F5) dalam RGBA_8888 little-endian
            let color: u32 = u32::from_le_bytes([0xF7, 0xF7, 0xF5, 0xFF]);
            let pixels = std::slice::from_raw_parts_mut(
                buffer.bits as *mut u32,
                (buffer.stride * buffer.height) as usize,
            );
            for y in 0..buffer.height as usize {
                let row_start = y * buffer.stride as usize;
                let row_end = row_start + buffer.width as usize;
                pixels[row_start..row_end].fill(color);
            }
        }

        ndk_sys::ANativeWindow_unlockAndPost(win_ptr);
    }
}
