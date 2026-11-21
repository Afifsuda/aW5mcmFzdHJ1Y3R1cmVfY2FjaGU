use android_activity::input::{InputEvent, MotionAction};
use android_activity::{AndroidApp, InputStatus, MainEvent, PollEvent};
use std::ffi::{c_void, CString};
use std::ptr;
use std::time::{Duration, Instant};

#[allow(dead_code)]
pub const RELAY_BASE_WS_URL: &str =
    "wss://aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev";

// --- Minimal EGL & GLESv3 FFI ---
type EGLDisplay = *mut c_void;
type EGLConfig = *mut c_void;
type EGLContext = *mut c_void;
type EGLSurface = *mut c_void;
type EGLNativeWindowType = *mut c_void;

const EGL_DEFAULT_DISPLAY: *mut c_void = ptr::null_mut();
const EGL_NO_CONTEXT: EGLContext = ptr::null_mut();
const EGL_NO_SURFACE: EGLSurface = ptr::null_mut();
const EGL_NONE: i32 = 0x3038;
const EGL_RED_SIZE: i32 = 0x3024;
const EGL_GREEN_SIZE: i32 = 0x3023;
const EGL_BLUE_SIZE: i32 = 0x3022;
const EGL_ALPHA_SIZE: i32 = 0x3021;
const EGL_RENDERABLE_TYPE: i32 = 0x3040;
const EGL_OPENGL_ES3_BIT: i32 = 0x0040;
const EGL_SURFACE_TYPE: i32 = 0x3033;
const EGL_WINDOW_BIT: i32 = 0x0004;
const EGL_CONTEXT_CLIENT_VERSION: i32 = 0x3098;

const GL_FRAGMENT_SHADER: u32 = 0x8B30;
const GL_VERTEX_SHADER: u32 = 0x8B31;
const GL_COMPILE_STATUS: u32 = 0x8B81;
const GL_LINK_STATUS: u32 = 0x8B82;
const GL_TRIANGLES: u32 = 0x0004;

extern "C" {
    fn eglGetDisplay(display_id: *mut c_void) -> EGLDisplay;
    fn eglInitialize(dpy: EGLDisplay, major: *mut i32, minor: *mut i32) -> u32;
    fn eglChooseConfig(
        dpy: EGLDisplay,
        attrib_list: *const i32,
        configs: *mut EGLConfig,
        config_size: i32,
        num_config: *mut i32,
    ) -> u32;
    fn eglCreateContext(
        dpy: EGLDisplay,
        config: EGLConfig,
        share_context: EGLContext,
        attrib_list: *const i32,
    ) -> EGLContext;
    fn eglCreateWindowSurface(
        dpy: EGLDisplay,
        config: EGLConfig,
        win: EGLNativeWindowType,
        attrib_list: *const i32,
    ) -> EGLSurface;
    fn eglMakeCurrent(
        dpy: EGLDisplay,
        draw: EGLSurface,
        read: EGLSurface,
        ctx: EGLContext,
    ) -> u32;
    fn eglSwapInterval(dpy: EGLDisplay, interval: i32) -> u32;
    fn eglSwapBuffers(dpy: EGLDisplay, surface: EGLSurface) -> u32;
    fn eglDestroySurface(dpy: EGLDisplay, surface: EGLSurface) -> u32;
    fn eglDestroyContext(dpy: EGLDisplay, ctx: EGLContext) -> u32;
    fn eglTerminate(dpy: EGLDisplay) -> u32;

    fn glViewport(x: i32, y: i32, width: i32, height: i32);
    fn glCreateShader(shader_type: u32) -> u32;
    fn glShaderSource(
        shader: u32,
        count: i32,
        string: *const *const u8,
        length: *const i32,
    );
    fn glCompileShader(shader: u32);
    fn glGetShaderiv(shader: u32, pname: u32, params: *mut i32);
    fn glCreateProgram() -> u32;
    fn glAttachShader(program: u32, shader: u32);
    fn glLinkProgram(program: u32);
    fn glGetProgramiv(program: u32, pname: u32, params: *mut i32);
    fn glDeleteShader(shader: u32);
    fn glUseProgram(program: u32);
    fn glGetUniformLocation(program: u32, name: *const u8) -> i32;
    fn glUniform1f(location: i32, v0: f32);
    fn glUniform1i(location: i32, v0: i32);
    fn glUniform2f(location: i32, v0: f32, v1: f32);
    fn glGenVertexArrays(n: i32, arrays: *mut u32);
    fn glBindVertexArray(array: u32);
    fn glDrawArrays(mode: u32, first: i32, count: i32);
    fn glDeleteProgram(program: u32);
    fn glDeleteVertexArrays(n: i32, arrays: *const u32);
}

// Single full-screen triangle without VBO (3 vertices generated via gl_VertexID)
const VERT_SRC: &str = "#version 300 es
void main() {
    vec2 pos = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
}
\0";

// Optimized SDF UI Button Shader:
// - Analytic anti-aliasing (1px)
// - Dynamic soft elevation shadow
// - Hairline inner border + specular highlight
// - Smooth press scale & touch-point radial ripple
const FRAG_SRC: &str = "#version 300 es
precision highp float;

uniform vec2 uRes;
uniform vec2 uTouch;
uniform float uPress;
uniform float uToggle;
uniform float uRipple;
uniform int uFps;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

float sdDigit(vec2 p, int d, vec2 sz, float thick) {
    int masks[10] = int[10](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
    int m = masks[clamp(d, 0, 9)];
    float hw = sz.x * 0.5;
    float hh = sz.y * 0.5;
    float gap = thick * 1.15;
    float dist = 1e5;

    if ((m & 1) != 0)  dist = min(dist, sdSegment(p, vec2(-hw + gap, -hh), vec2(hw - gap, -hh))); // top
    if ((m & 2) != 0)  dist = min(dist, sdSegment(p, vec2(hw, -hh + gap), vec2(hw, -gap)));       // top-right
    if ((m & 4) != 0)  dist = min(dist, sdSegment(p, vec2(hw, gap), vec2(hw, hh - gap)));         // bot-right
    if ((m & 8) != 0)  dist = min(dist, sdSegment(p, vec2(-hw + gap, hh), vec2(hw - gap, hh)));   // bottom
    if ((m & 16) != 0) dist = min(dist, sdSegment(p, vec2(-hw, gap), vec2(-hw, hh - gap)));       // bot-left
    if ((m & 32) != 0) dist = min(dist, sdSegment(p, vec2(-hw, -hh + gap), vec2(-hw, -gap)));     // top-left
    if ((m & 64) != 0) dist = min(dist, sdSegment(p, vec2(-hw + gap, 0.0), vec2(hw - gap, 0.0))); // mid

    return dist - thick;
}

void main() {
    // Screen coordinates in pixels, origin at center (Y down)
    vec2 px = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y);
    vec2 center = uRes * 0.5;
    vec2 p = px - center;

    float minDim = min(uRes.x, uRes.y);
    vec2 btnHalf = vec2(min(minDim * 0.34, 300.0), min(minDim * 0.11, 105.0));
    float radius = btnHalf.y * 0.52;

    // Subtle press scale (1.0 -> 0.96)
    float scale = mix(1.0, 0.96, uPress);
    vec2 sp = p / scale;

    float d = sdRoundBox(sp, btnHalf, radius) * scale;

    // Background canvas (#F7F7F5)
    vec3 bg = vec3(0.9686, 0.9686, 0.9608);

    // Dynamic soft shadow beneath button
    float shadowOffset = mix(14.0, 4.0, uPress);
    float shadowBlur = mix(36.0, 14.0, uPress);
    float dShadow = sdRoundBox(p - vec2(0.0, shadowOffset), btnHalf, radius);
    float shadowAlpha = exp(-max(dShadow, 0.0) / shadowBlur) * mix(0.18, 0.10, uPress);
    vec3 col = mix(bg, vec3(0.094, 0.094, 0.086), shadowAlpha);

    // Button fill color: Idle (#181816) -> Active/Toggled (#E54826)
    vec3 idleCol = vec3(0.0941, 0.0941, 0.0863);
    vec3 activeCol = vec3(0.8980, 0.2824, 0.1490);
    vec3 btnCol = mix(idleCol, activeCol, clamp(uToggle * 0.85 + uPress * 0.35, 0.0, 1.0));

    // Top subtle highlight + touch ripple inside button
    float topGrad = smoothstep(btnHalf.y, -btnHalf.y, sp.y) * 0.08;
    btnCol += vec3(topGrad);

    if (uRipple > 0.001) {
        float touchDist = length(px - uTouch);
        float maxR = length(btnHalf) * 1.4;
        float rMask = 1.0 - smoothstep(0.0, maxR * uRipple, touchDist);
        btnCol += vec3(0.16) * rMask * (1.0 - uRipple * 0.65) * uPress;
    }

    // Crisp 1px inner border
    float borderMask = 1.0 - smoothstep(0.0, 1.5, abs(d + 0.75));
    btnCol = mix(btnCol, btnCol + vec3(0.12), borderMask * 0.5);

    // Center power/status ring icon drawn purely with SDF!
    float ringR = btnHalf.y * 0.36;
    float dRing = abs(length(sp) - ringR) - (btnHalf.y * 0.065);
    float iconAlpha = 1.0 - smoothstep(-0.75, 0.75, dRing);
    vec3 iconCol = mix(vec3(1.0), vec3(1.0, 0.96, 0.92), uToggle);
    btnCol = mix(btnCol, iconCol, iconAlpha * 0.92);

    // Analytic 1px AA composite for button body
    float btnAlpha = 1.0 - smoothstep(-0.75, 0.75, d);
    col = mix(col, btnCol, btnAlpha);

    // --- Minimalist Top FPS Pill ---
    float unit = clamp(minDim * 0.032, 22.0, 38.0);
    vec2 pillCenter = vec2(uRes.x * 0.5, max(uRes.y * 0.08, 120.0));
    vec2 pp = px - pillCenter;
    vec2 pillHalf = vec2(unit * 2.55, unit * 0.72);
    float dPill = sdRoundBox(pp, pillHalf, pillHalf.y);

    if (dPill < 8.0) {
        vec3 pillBg = vec3(0.9255, 0.9255, 0.9098); // #ECECE8
        float pillAlpha = 1.0 - smoothstep(-0.75, 0.75, dPill);
        float pillBorder = 1.0 - smoothstep(0.0, 1.4, abs(dPill));
        vec3 pillCol = mix(pillBg, vec3(0.094, 0.094, 0.086), pillBorder * 0.10);

        // Status dot (green >=55, amber 30-54, red <30)
        vec2 dotPos = vec2(-pillHalf.x + pillHalf.y * 0.85, 0.0);
        float dDot = length(pp - dotPos) - (unit * 0.14);
        vec3 dotCol = (uFps >= 55) ? vec3(0.13, 0.72, 0.38)
                    : (uFps >= 30) ? vec3(0.92, 0.65, 0.12)
                                   : vec3(0.90, 0.28, 0.15);
        pillCol = mix(pillCol, dotCol, 1.0 - smoothstep(-0.75, 0.75, dDot));

        // 7-segment FPS digits (up to 3 digits)
        int fpsClamped = clamp(uFps, 0, 999);
        int d0 = (fpsClamped / 100) % 10;
        int d1 = (fpsClamped / 10) % 10;
        int d2 = fpsClamped % 10;

        vec2 digSz = vec2(unit * 0.42, unit * 0.76);
        float thick = unit * 0.068;
        float stepX = unit * 0.66;
        float startX = -unit * 0.15;

        float dText = 1e5;
        if (fpsClamped >= 100) {
            dText = min(dText, sdDigit(pp - vec2(startX, 0.0), d0, digSz, thick));
        }
        if (fpsClamped >= 10) {
            dText = min(dText, sdDigit(pp - vec2(startX + stepX, 0.0), d1, digSz, thick));
        }
        dText = min(dText, sdDigit(pp - vec2(startX + stepX * 2.0, 0.0), d2, digSz, thick));

        float textAlpha = 1.0 - smoothstep(-0.75, 0.75, dText);
        pillCol = mix(pillCol, idleCol, textAlpha * 0.90);

        col = mix(col, pillCol, pillAlpha);
    }

    fragColor = vec4(col, 1.0);
}
\0";

struct GlState {
    display: EGLDisplay,
    config: EGLConfig,
    context: EGLContext,
    surface: EGLSurface,
    program: u32,
    vao: u32,
    u_res: i32,
    u_touch: i32,
    u_press: i32,
    u_toggle: i32,
    u_ripple: i32,
    u_fps: i32,
    width: i32,
    height: i32,
}

impl GlState {
    unsafe fn init(window: *mut c_void, width: i32, height: i32) -> Option<Self> {
        let display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        if display.is_null() || eglInitialize(display, ptr::null_mut(), ptr::null_mut()) == 0 {
            return None;
        }

        let attribs = [
            EGL_RENDERABLE_TYPE,
            EGL_OPENGL_ES3_BIT,
            EGL_SURFACE_TYPE,
            EGL_WINDOW_BIT,
            EGL_RED_SIZE,
            8,
            EGL_GREEN_SIZE,
            8,
            EGL_BLUE_SIZE,
            8,
            EGL_ALPHA_SIZE,
            8,
            EGL_NONE,
        ];
        let mut config: EGLConfig = ptr::null_mut();
        let mut num_configs = 0;
        if eglChooseConfig(display, attribs.as_ptr(), &mut config, 1, &mut num_configs) == 0
            || num_configs == 0
        {
            return None;
        }

        let ctx_attribs = [EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE];
        let context = eglCreateContext(display, config, EGL_NO_CONTEXT, ctx_attribs.as_ptr());
        if context.is_null() {
            return None;
        }

        let surface = eglCreateWindowSurface(display, config, window, ptr::null());
        if surface.is_null() {
            eglDestroyContext(display, context);
            return None;
        }

        if eglMakeCurrent(display, surface, surface, context) == 0 {
            eglDestroySurface(display, surface);
            eglDestroyContext(display, context);
            return None;
        }
        eglSwapInterval(display, 1);
        glViewport(0, 0, width, height);

        let vs = compile_shader(GL_VERTEX_SHADER, VERT_SRC)?;
        let fs = compile_shader(GL_FRAGMENT_SHADER, FRAG_SRC)?;
        let program = glCreateProgram();
        glAttachShader(program, vs);
        glAttachShader(program, fs);
        glLinkProgram(program);
        glDeleteShader(vs);
        glDeleteShader(fs);

        let mut linked = 0;
        glGetProgramiv(program, GL_LINK_STATUS, &mut linked);
        if linked == 0 {
            glDeleteProgram(program);
            return None;
        }

        let mut vao = 0;
        glGenVertexArrays(1, &mut vao);
        glBindVertexArray(vao);
        glUseProgram(program);

        let loc = |name: &str| {
            let c = CString::new(name).unwrap();
            glGetUniformLocation(program, c.as_ptr() as *const u8)
        };

        Some(Self {
            display,
            config,
            context,
            surface,
            program,
            vao,
            u_res: loc("uRes"),
            u_touch: loc("uTouch"),
            u_press: loc("uPress"),
            u_toggle: loc("uToggle"),
            u_ripple: loc("uRipple"),
            u_fps: loc("uFps"),
            width,
            height,
        })
    }

    unsafe fn recreate_surface(&mut self, window: *mut c_void, width: i32, height: i32) {
        if !self.surface.is_null() {
            eglMakeCurrent(self.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
            eglDestroySurface(self.display, self.surface);
        }
        self.surface = eglCreateWindowSurface(self.display, self.config, window, ptr::null());
        if !self.surface.is_null() {
            eglMakeCurrent(self.display, self.surface, self.surface, self.context);
            eglSwapInterval(self.display, 1);
            self.width = width;
            self.height = height;
            glViewport(0, 0, width, height);
        }
    }

    unsafe fn draw(&self, touch: [f32; 2], press: f32, toggle: f32, ripple: f32, fps: i32) {
        if self.surface.is_null() {
            return;
        }
        glViewport(0, 0, self.width, self.height);
        glUseProgram(self.program);
        glBindVertexArray(self.vao);
        glUniform2f(self.u_res, self.width as f32, self.height as f32);
        glUniform2f(self.u_touch, touch[0], touch[1]);
        glUniform1f(self.u_press, press);
        glUniform1f(self.u_toggle, toggle);
        glUniform1f(self.u_ripple, ripple);
        glUniform1i(self.u_fps, fps);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        eglSwapBuffers(self.display, self.surface);
    }

    unsafe fn destroy(&mut self) {
        eglMakeCurrent(self.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if self.vao != 0 {
            glDeleteVertexArrays(1, &self.vao);
        }
        if self.program != 0 {
            glDeleteProgram(self.program);
        }
        if !self.surface.is_null() {
            eglDestroySurface(self.display, self.surface);
        }
        if !self.context.is_null() {
            eglDestroyContext(self.display, self.context);
        }
        if !self.display.is_null() {
            eglTerminate(self.display);
        }
    }
}

unsafe fn compile_shader(ty: u32, src: &str) -> Option<u32> {
    let shader = glCreateShader(ty);
    let ptr = src.as_ptr();
    glShaderSource(shader, 1, &ptr, ptr::null());
    glCompileShader(shader);
    let mut ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &mut ok);
    if ok == 0 {
        glDeleteShader(shader);
        return None;
    }
    Some(shader)
}

fn hit_test_button(x: f32, y: f32, w: f32, h: f32) -> bool {
    let min_dim = w.min(h);
    let hw = (min_dim * 0.34).min(300.0);
    let hh = (min_dim * 0.11).min(105.0);
    (x - w * 0.5).abs() <= hw && (y - h * 0.5).abs() <= hh
}

#[no_mangle]
fn android_main(app: AndroidApp) {
    let mut gl: Option<GlState> = None;
    let mut running = true;
    let mut has_window = false;
    let mut needs_redraw = false;

    let mut is_pressed = false;
    let mut is_toggled = false;
    let mut press_anim: f32 = 0.0;
    let mut toggle_anim: f32 = 0.0;
    let mut ripple_anim: f32 = 0.0;
    let mut touch_pos: [f32; 2] = [0.0, 0.0];
    let mut last_tick = Instant::now();
    let mut fps_timer = Instant::now();
    let mut frame_count: u32 = 0;
    let mut current_fps: i32 = 60;

    while running {
        let timeout = if has_window {
            Some(Duration::ZERO)
        } else {
            None
        };

        app.poll_events(timeout, |event| match event {
            PollEvent::Main(main_event) => match main_event {
                MainEvent::InitWindow { .. } => {
                    if let Some(win) = app.native_window() {
                        let w = win.width().max(1);
                        let h = win.height().max(1);
                        unsafe {
                            if let Some(ref mut state) = gl {
                                state.recreate_surface(win.ptr().as_ptr() as *mut c_void, w, h);
                            } else {
                                gl = GlState::init(win.ptr().as_ptr() as *mut c_void, w, h);
                            }
                        }
                        has_window = true;
                        needs_redraw = true;
                    }
                }
                MainEvent::WindowResized { .. } | MainEvent::RedrawNeeded { .. } => {
                    if let (Some(ref mut state), Some(win)) = (&mut gl, app.native_window()) {
                        state.width = win.width().max(1);
                        state.height = win.height().max(1);
                        needs_redraw = true;
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

        // Process touch input events
        if let Ok(mut iter) = app.input_events_iter() {
            while iter.next(|event| match event {
                InputEvent::MotionEvent(motion) => {
                    let (w, h) = gl
                        .as_ref()
                        .map(|g| (g.width as f32, g.height as f32))
                        .unwrap_or((1080.0, 2400.0));

                    match motion.action() {
                        MotionAction::Down | MotionAction::PointerDown => {
                            let p = motion.pointer_at_index(motion.pointer_index());
                            if hit_test_button(p.x(), p.y(), w, h) {
                                is_pressed = true;
                                touch_pos = [p.x(), p.y()];
                                ripple_anim = 0.01;
                                needs_redraw = true;
                            }
                        }
                        MotionAction::Move => {
                            if is_pressed {
                                if let Some(p) = motion.pointers().next() {
                                    touch_pos = [p.x(), p.y()];
                                    if !hit_test_button(p.x(), p.y(), w, h) {
                                        is_pressed = false;
                                    }
                                    needs_redraw = true;
                                }
                            }
                        }
                        MotionAction::Up | MotionAction::PointerUp => {
                            let p = motion.pointer_at_index(motion.pointer_index());
                            if is_pressed && hit_test_button(p.x(), p.y(), w, h) {
                                is_toggled = !is_toggled;
                            }
                            is_pressed = false;
                            needs_redraw = true;
                        }
                        MotionAction::Cancel => {
                            is_pressed = false;
                            needs_redraw = true;
                        }
                        _ => {}
                    }
                    InputStatus::Handled
                }
                _ => InputStatus::Unhandled,
            }) {}
        }

        let now = Instant::now();
        let dt = now.duration_since(last_tick).as_secs_f32().min(0.05);
        last_tick = now;

        let target_press = if is_pressed { 1.0 } else { 0.0 };
        let target_toggle = if is_toggled { 1.0 } else { 0.0 };
        let target_ripple = if is_pressed { 1.0 } else { 0.0 };

        let speed = (dt * 18.0).min(1.0);
        press_anim += (target_press - press_anim) * speed;
        toggle_anim += (target_toggle - toggle_anim) * (dt * 12.0).min(1.0);
        ripple_anim += (target_ripple - ripple_anim) * (dt * 10.0).min(1.0);

        let still_animating = (press_anim - target_press).abs() > 0.002
            || (toggle_anim - target_toggle).abs() > 0.002
            || (ripple_anim - target_ripple).abs() > 0.002;

        if has_window {
            if let Some(ref state) = gl {
                unsafe {
                    state.draw(touch_pos, press_anim, toggle_anim, ripple_anim, current_fps);
                }
            }
            frame_count += 1;
            let fps_elapsed = now.duration_since(fps_timer).as_secs_f32();
            if fps_elapsed >= 0.35 {
                current_fps = (frame_count as f32 / fps_elapsed).round() as i32;
                frame_count = 0;
                fps_timer = now;
            }
            needs_redraw = false;
        }
        let _ = (needs_redraw, still_animating);
    }

    if let Some(ref mut state) = gl {
        unsafe {
            state.destroy();
        }
    }
}
