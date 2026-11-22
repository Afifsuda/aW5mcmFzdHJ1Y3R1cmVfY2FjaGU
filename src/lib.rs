use android_activity::input::{InputEvent, MotionAction};
use android_activity::{AndroidApp, InputStatus, MainEvent, PollEvent};
use jni::objects::{JByteArray, JClass, JObject, JValue};
use jni::sys::{jboolean, jfloat, jint};
use jni::{JNIEnv, JavaVM};
use std::ffi::{c_void, CString};
use std::ptr;
use std::sync::atomic::{AtomicBool, AtomicI32, AtomicU32, Ordering};
use std::sync::Mutex;
use std::time::{Duration, Instant};

#[allow(dead_code)]
pub const RELAY_BASE_WS_URL: &str =
    "wss://aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev";

// --- Shared JNI State ---
struct PendingWallpaper {
    rgba: Vec<u8>,
    w: i32,
    h: i32,
}

static PENDING_WALLPAPER: Mutex<Option<PendingWallpaper>> = Mutex::new(None);
static TARGET_CAP_HEIGHT_DP: AtomicU32 = AtomicU32::new(0x42500000); // 52.0f32.to_bits()
static IS_FOCUSED: AtomicBool = AtomicBool::new(false);
static KEYBOARD_INSET_PX: AtomicI32 = AtomicI32::new(0);

#[no_mangle]
pub extern "system" fn Java_com_afifsuda_canvas_MainActivity_nativeOnWallpaperLoaded(
    env: JNIEnv,
    _class: JClass,
    rgba: JByteArray,
    width: jint,
    height: jint,
) {
    if let Ok(bytes) = env.convert_byte_array(rgba) {
        if let Ok(mut guard) = PENDING_WALLPAPER.lock() {
            *guard = Some(PendingWallpaper {
                rgba: bytes,
                w: width,
                h: height,
            });
        }
    }
}

#[no_mangle]
pub extern "system" fn Java_com_afifsuda_canvas_MainActivity_nativeSetTargetCapHeight(
    _env: JNIEnv,
    _class: JClass,
    height_dp: jfloat,
) {
    TARGET_CAP_HEIGHT_DP.store(height_dp.to_bits(), Ordering::Relaxed);
}

#[no_mangle]
pub extern "system" fn Java_com_afifsuda_canvas_MainActivity_nativeSetFocused(
    _env: JNIEnv,
    _class: JClass,
    focused: jboolean,
) {
    IS_FOCUSED.store(focused != 0, Ordering::Relaxed);
}

#[no_mangle]
pub extern "system" fn Java_com_afifsuda_canvas_MainActivity_nativeSetKeyboardInset(
    _env: JNIEnv,
    _class: JClass,
    inset_px: jint,
) {
    KEYBOARD_INSET_PX.store(inset_px, Ordering::Relaxed);
}

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
const GL_TEXTURE_2D: u32 = 0x0DE1;
const GL_TEXTURE0: u32 = 0x84C0;
const GL_RGBA: u32 = 0x1908;
const GL_UNSIGNED_BYTE: u32 = 0x1401;
const GL_TEXTURE_MIN_FILTER: u32 = 0x2801;
const GL_TEXTURE_MAG_FILTER: u32 = 0x2800;
const GL_TEXTURE_WRAP_S: u32 = 0x2802;
const GL_TEXTURE_WRAP_T: u32 = 0x2803;
const GL_LINEAR: i32 = 0x2601;
const GL_CLAMP_TO_EDGE: i32 = 0x812F;

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
    fn glGetShaderInfoLog(shader: u32, buf_size: i32, length: *mut i32, info_log: *mut u8);
    fn glCreateProgram() -> u32;
    fn glAttachShader(program: u32, shader: u32);
    fn glLinkProgram(program: u32);
    fn glGetProgramiv(program: u32, pname: u32, params: *mut i32);
    fn glGetProgramInfoLog(program: u32, buf_size: i32, length: *mut i32, info_log: *mut u8);
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

    fn glGenTextures(n: i32, textures: *mut u32);
    fn glActiveTexture(texture: u32);
    fn glBindTexture(target: u32, texture: u32);
    fn glTexParameteri(target: u32, pname: u32, param: i32);
    fn glTexImage2D(
        target: u32,
        level: i32,
        internalformat: i32,
        width: i32,
        height: i32,
        border: i32,
        format: u32,
        type_: u32,
        pixels: *const c_void,
    );
    fn glDeleteTextures(n: i32, textures: *const u32);
}

const VERT_SRC: &str = "#version 300 es
void main() {
    vec2 pos = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
}
\0";

// Ported 3D Sculpted Matte Ceramic Shader (OpenGL ES 3.0) + SDF FPS Digits
const FRAG_SRC: &str = "#version 300 es
precision highp float;

uniform vec2 res;
uniform vec2 imgRes;
uniform sampler2D uBgTex;
uniform float imgFade;
uniform float dpr;

uniform vec2 plusCenter;
uniform float plusRadius;
uniform vec2 capCenter;
uniform vec2 capHalf;
uniform float capRadius;
uniform vec2 btnCenter;
uniform float btnRadius;

uniform float plusPress;
uniform float plusPulse;
uniform float capPress;
uniform float btnPress;
uniform float isFocused;
uniform float sendPulse;
uniform vec2 tilt;
uniform float fpsBoxHalfW;
uniform int uFps;

out vec4 fragColor;

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - (b - r);
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

    if ((m & 1) != 0)  dist = min(dist, sdSegment(p, vec2(-hw + gap, -hh), vec2(hw - gap, -hh)));
    if ((m & 2) != 0)  dist = min(dist, sdSegment(p, vec2(hw, -hh + gap), vec2(hw, -gap)));
    if ((m & 4) != 0)  dist = min(dist, sdSegment(p, vec2(hw, gap), vec2(hw, hh - gap)));
    if ((m & 8) != 0)  dist = min(dist, sdSegment(p, vec2(-hw + gap, hh), vec2(hw - gap, hh)));
    if ((m & 16) != 0) dist = min(dist, sdSegment(p, vec2(-hw, gap), vec2(-hw, hh - gap)));
    if ((m & 32) != 0) dist = min(dist, sdSegment(p, vec2(-hw, -hh + gap), vec2(-hw, -gap)));
    if ((m & 64) != 0) dist = min(dist, sdSegment(p, vec2(-hw + gap, 0.0), vec2(hw - gap, 0.0)));

    return dist - thick;
}

float samplePlusIcon(vec2 p, float scale) {
    float s = 7.4 * dpr * scale;
    float dHoriz = sdSegment(p, vec2(-s, 0.0), vec2(s, 0.0));
    float dVert  = sdSegment(p, vec2(0.0, -s), vec2(0.0, s));
    float dPlus  = min(dHoriz, dVert);
    float strokeRadius = 1.35 * dpr * scale;
    return smoothstep(strokeRadius + 0.85, strokeRadius - 0.45, dPlus);
}

float sampleArrowUpIcon(vec2 p, float scale) {
    float s = 7.6 * dpr * scale;
    float dShaft = sdSegment(p, vec2(0.0, s), vec2(0.0, -s));
    float dLeft  = sdSegment(p, vec2(-s * 0.78, -s * 0.15), vec2(0.0, -s));
    float dRight = sdSegment(p, vec2( s * 0.78, -s * 0.15), vec2(0.0, -s));
    float dArrow = min(dShaft, min(dLeft, dRight));
    float strokeRadius = 1.35 * dpr * scale;
    return smoothstep(strokeRadius + 0.85, strokeRadius - 0.45, dArrow);
}

vec3 sampleScene(vec2 px) {
    vec3 baseCol = vec3(0.93, 0.945, 0.965);
    if (imgFade <= 0.001) return baseCol;

    vec2 uv = px / res;
    float screenAspect = res.x / max(res.y, 1.0);
    float imgAspect = imgRes.x / max(imgRes.y, 1.0);
    vec2 coverUv = uv;

    if (screenAspect > imgAspect) {
        float s = imgAspect / screenAspect;
        coverUv.y = coverUv.y * s + (1.0 - s) * 0.5;
    } else {
        float s = screenAspect / imgAspect;
        coverUv.x = coverUv.x * s + (1.0 - s) * 0.5;
    }

    vec3 photo = texture(uBgTex, clamp(coverUv, 0.001, 0.999)).rgb;
    return mix(baseCol, photo, imgFade);
}

vec3 render3DMatteSurface(
    vec3 bgCol,
    vec3 envBounce,
    vec2 pLocal,
    float d,
    float dPenumbra,
    float dCrevice,
    float press,
    float activeGlow,
    bool isCapsule,
    bool isAccent,
    int tier
) {
    float lift = 1.0 - press * 0.60;

    float sigma = (tier == 1) ? (8.5 * dpr * lift) : (18.0 * dpr * lift);
    float distPos = max(dPenumbra, 0.0);
    float gaussPenumbra = exp(-(distPos * distPos) / (2.0 * sigma * sigma));
    float penumbraStrength = (tier == 1) ? (0.14 * lift) : (0.24 * lift);

    float creviceWidth = (tier == 1) ? (2.8 * dpr) : (4.0 * dpr);
    float creviceAO = smoothstep(creviceWidth, -0.5 * dpr, dCrevice);
    creviceAO = creviceAO * creviceAO * ((tier == 1) ? (0.18 - press * 0.04) : (0.22 - press * 0.06));

    vec3 shadowFilter = mix(vec3(1.0), vec3(0.42, 0.47, 0.58), clamp(gaussPenumbra * penumbraStrength + creviceAO, 0.0, 0.48));
    bgCol *= shadowFilter;

    float mask = smoothstep(1.15, -0.65, d);
    if (mask <= 0.001) return bgCol;

    vec2 grad2D = normalize(pLocal + 0.0001);
    float maxThick = capRadius;
    if (isCapsule) {
        vec2 innerBox = max(vec2(0.0), capHalf - capRadius);
        vec2 spinePt = clamp(pLocal, -innerBox, innerBox);
        vec2 delta = pLocal - spinePt;
        if (length(delta) > 0.001) {
            grad2D = normalize(delta);
        } else {
            grad2D = vec2(0.0, pLocal.y / max(capHalf.y, 1.0));
        }
    } else {
        maxThick = (tier == 1) ? plusRadius : 14.0 * dpr;
    }

    float depthNorm = clamp(-d / max(maxThick, 1.0), 0.0, 1.0);
    float bevelCurve = pow(1.0 - depthNorm, 2.4);
    float domeSlope = bevelCurve * (0.72 - press * 0.16);

    vec3 N = normalize(vec3(grad2D * domeSlope, sqrt(max(0.08, 1.0 - domeSlope * domeSlope))));

    vec3 L = normalize(vec3(-0.24 + tilt.x * 0.55, -0.82 + tilt.y * 0.45, 0.52));
    float wrappedDiffuse = clamp((dot(N, L) + 0.45) / 1.45, 0.0, 1.0);
    float skyFactor = 0.5 + 0.5 * (-N.y);
    float lightTerm = mix(0.84, 1.0, wrappedDiffuse * 0.72 + skyFactor * 0.28);

    vec3 surface;
    if (isAccent) {
        vec3 topBlue = vec3(0.18, 0.53, 0.99);
        vec3 deepBlue = vec3(0.08, 0.36, 0.85);
        surface = mix(deepBlue, topBlue, lightTerm);
        surface += envBounce * 0.04;
    } else {
        vec3 baseTop = (tier == 1) ? vec3(0.995, 0.997, 1.0) : vec3(0.975, 0.980, 0.990);
        vec3 baseBot = (tier == 1) ? vec3(0.905, 0.922, 0.952) : vec3(0.880, 0.900, 0.935);
        if (activeGlow > 0.01) {
            baseTop = mix(baseTop, vec3(1.0), activeGlow * 0.5);
            baseBot = mix(baseBot, vec3(0.915, 0.932, 0.965), activeGlow * 0.45);
        }
        surface = mix(baseBot, baseTop, lightTerm);
        float bounceMask = (1.0 - skyFactor) * 0.045;
        surface = mix(surface, envBounce, bounceMask);
    }

    float edgeZone = smoothstep(-4.0 * dpr, -0.35 * dpr, d);
    float topRim = clamp(dot(grad2D, normalize(vec2(-0.22, -0.97))), 0.0, 1.0);
    float botRim = pow(clamp(dot(grad2D, vec2(0.0, 1.0)), 0.0, 1.0), 1.35);

    if (isAccent) {
        surface = mix(surface, vec3(0.42, 0.71, 1.0), edgeZone * topRim * (0.55 - press * 0.20));
        surface = mix(surface, vec3(0.05, 0.24, 0.64), edgeZone * botRim * 0.42);
    } else {
        surface = mix(surface, vec3(1.0), edgeZone * topRim * (0.78 - press * 0.28));
        vec3 rimShade = (tier == 1) ? vec3(0.82, 0.85, 0.905) : vec3(0.79, 0.825, 0.885);
        surface = mix(surface, rimShade, edgeZone * botRim * 0.48);
    }

    if (press > 0.001) {
        vec3 pressTint = isAccent ? vec3(0.06, 0.30, 0.74) : vec3(0.88, 0.905, 0.945);
        surface = mix(surface, pressTint, press * 0.32);
    }

    return mix(bgCol, clamp(surface, 0.0, 1.0), mask);
}

void main() {
    vec2 px = vec2(gl_FragCoord.x, res.y - gl_FragCoord.y);
    vec3 col = sampleScene(px);

    // --- FPS 3D MATTE PILL DI TENGAH ATAS ---
    float fpsCenterY = 44.0 * dpr;
    if (px.y < 84.0 * dpr && abs(px.x - res.x * 0.5) < (fpsBoxHalfW + 30.0 * dpr)) {
        vec3 envBounce = sampleScene(vec2(res.x * 0.5, fpsCenterY));
        vec2 pFps = px - vec2(res.x * 0.5, fpsCenterY);
        float dPill = sdRoundBox(pFps, vec2(fpsBoxHalfW, 14.0 * dpr), 14.0 * dpr);
        float dPillPenumbra = sdRoundBox(pFps - vec2(0.0, 4.5 * dpr), vec2(fpsBoxHalfW, 14.0 * dpr), 14.0 * dpr);
        float dPillCrevice = sdRoundBox(pFps - vec2(0.0, 1.4 * dpr), vec2(fpsBoxHalfW, 14.0 * dpr), 14.0 * dpr);

        col = render3DMatteSurface(col, envBounce, pFps, dPill, dPillPenumbra, dPillCrevice, 0.0, 0.0, true, false, 1);

        if (dPill < -1.0 * dpr) {
            // Dot + SDF FPS digits inside pill
            vec2 dotPos = vec2(-fpsBoxHalfW + 14.0 * dpr, 0.0);
            float dDot = length(pFps - dotPos) - (2.6 * dpr);
            vec3 dotCol = (uFps >= 55) ? vec3(0.13, 0.72, 0.38)
                        : (uFps >= 30) ? vec3(0.92, 0.65, 0.12)
                                       : vec3(0.90, 0.28, 0.15);
            col = mix(col, dotCol, 1.0 - smoothstep(-0.75, 0.75, dDot));

            int fpsClamped = clamp(uFps, 0, 999);
            int d0 = (fpsClamped / 100) % 10;
            int d1 = (fpsClamped / 10) % 10;
            int d2 = fpsClamped % 10;

            vec2 digSz = vec2(6.5 * dpr, 11.0 * dpr);
            float thick = 1.05 * dpr;
            float stepX = 9.5 * dpr;
            float startX = -3.0 * dpr;

            float dText = 1e5;
            if (fpsClamped >= 100) {
                dText = min(dText, sdDigit(pFps - vec2(startX, 0.0), d0, digSz, thick));
            }
            if (fpsClamped >= 10) {
                dText = min(dText, sdDigit(pFps - vec2(startX + stepX, 0.0), d1, digSz, thick));
            }
            dText = min(dText, sdDigit(pFps - vec2(startX + stepX * 2.0, 0.0), d2, digSz, thick));

            float textAlpha = 1.0 - smoothstep(-0.75, 0.75, dText);
            col = mix(col, vec3(0.078, 0.098, 0.137), textAlpha * 0.92);
        }

        fragColor = vec4(col, 1.0);
        return;
    }

    float barTopBound = capCenter.y - capHalf.y - 46.0 * dpr;
    if (px.y < barTopBound) {
        fragColor = vec4(col, 1.0);
        return;
    }

    vec3 barEnvBounce = sampleScene(vec2(px.x, capCenter.y - capHalf.y - 10.0 * dpr));

    // --- LAYER 1: EXPANDING CAPSULE INPUT FIELD ---
    vec2 pCap = px - capCenter;
    float capDrop = capPress * 1.4 * dpr;
    vec2 pCapPhys = pCap - vec2(0.0, capDrop);

    if (abs(pCap.x) < capHalf.x + 48.0 * dpr) {
        vec2 bCap = capHalf * (1.0 - capPress * 0.008);
        float rCap = capRadius * (1.0 - capPress * 0.008);
        float dCap = sdRoundBox(pCapPhys, bCap, rCap);
        float dCapPenumbra = sdRoundBox(pCap - vec2(0.0, 7.0 * dpr) * (1.0 - capPress * 0.5), bCap, rCap);
        float dCapCrevice = sdRoundBox(pCap - vec2(0.0, 1.8 * dpr) * (1.0 - capPress * 0.5), bCap, rCap);

        col = render3DMatteSurface(col, barEnvBounce, pCapPhys, dCap, dCapPenumbra, dCapCrevice, capPress, isFocused, true, false, 0);
    }

    // --- LAYER 2: TOMBOL + DI SISI KIRI ---
    vec2 pPlus = px - (plusCenter + vec2(0.0, capDrop));
    if (abs(pPlus.x) < plusRadius + 28.0 * dpr && abs(pPlus.y) < plusRadius + 28.0 * dpr) {
        float pressDrop = plusPress * 1.5 * dpr;
        vec2 pPlusPhys = pPlus - vec2(0.0, pressDrop);
        float rPlus = plusRadius * (1.0 - plusPress * 0.045 + plusPulse * 0.06);
        float dPlus = length(pPlusPhys) - rPlus;
        float dPlusPenumbra = length(pPlus - vec2(0.0, 3.2 * dpr) * (1.0 - plusPress * 0.6)) - rPlus;
        float dPlusCrevice = length(pPlus - vec2(0.0, 1.0 * dpr) * (1.0 - plusPress * 0.6)) - rPlus;

        col = render3DMatteSurface(col, barEnvBounce, pPlusPhys, dPlus, dPlusPenumbra, dPlusCrevice, plusPress, plusPulse, false, false, 1);

        if (dPlus < -1.0 * dpr) {
            float angle = plusPulse * 1.5707963;
            float ca = cos(angle), sa = sin(angle);
            vec2 pRot = vec2(pPlusPhys.x * ca - pPlusPhys.y * sa, pPlusPhys.x * sa + pPlusPhys.y * ca);
            float plusAlpha = samplePlusIcon(pRot, 1.0 - plusPress * 0.045);
            if (plusAlpha > 0.001) col = mix(col, vec3(0.08, 0.10, 0.15), plusAlpha * 0.96);
        }
    }

    // --- LAYER 2: TOMBOL KIRIM DI SISI KANAN ---
    vec2 pBtn = px - (btnCenter + vec2(0.0, capDrop));
    if (abs(pBtn.x) < btnRadius + 28.0 * dpr && abs(pBtn.y) < btnRadius + 28.0 * dpr) {
        float btnDrop = btnPress * 1.5 * dpr;
        vec2 pBtnPhys = pBtn - vec2(0.0, btnDrop);
        float rBtn = btnRadius * (1.0 - btnPress * 0.045 + sendPulse * 0.06);
        float dBtn = length(pBtnPhys) - rBtn;
        float dBtnPenumbra = length(pBtn - vec2(0.0, 3.2 * dpr) * (1.0 - btnPress * 0.6)) - rBtn;
        float dBtnCrevice = length(pBtn - vec2(0.0, 1.0 * dpr) * (1.0 - btnPress * 0.6)) - rBtn;

        col = render3DMatteSurface(col, barEnvBounce, pBtnPhys, dBtn, dBtnPenumbra, dBtnCrevice, btnPress, sendPulse, false, true, 1);

        if (dBtn < -1.0 * dpr) {
            vec2 pIcon = pBtnPhys + vec2(0.0, sendPulse * 4.0 * dpr);
            float iconAlpha = sampleArrowUpIcon(pIcon, 1.0 - btnPress * 0.045);
            if (iconAlpha > 0.001) col = mix(col, vec3(1.0), iconAlpha * 0.98);
        }
    }

    fragColor = vec4(col, 1.0);
}
\0";

struct Layout {
    plus_x: f32,
    plus_y: f32,
    plus_r: f32,
    cap_x: f32,
    cap_y: f32,
    cap_half_w: f32,
    cap_half_h: f32,
    cap_radius: f32,
    btn_x: f32,
    btn_y: f32,
    btn_r: f32,
    input_left: f32,
    input_top: f32,
    input_width: f32,
    input_height: f32,
}

const BASE_CAP_HEIGHT: f32 = 52.0;
const CAP_CORNER_RADIUS: f32 = 26.0;

fn get_layout(sw_dp: f32, sh_dp: f32, cap_height_dp: f32, keyboard_dp: f32) -> Layout {
    let margin_side = 14.0;
    let margin_bottom = 22.0 + keyboard_dp;
    let inset = 6.0;
    let btn_radius = (BASE_CAP_HEIGHT * 0.5) - inset;

    let total_w = (sw_dp - margin_side * 2.0).min(540.0);
    let start_x = (sw_dp - total_w) * 0.5;
    let bottom_y = sh_dp - margin_bottom;
    let center_y = bottom_y - (cap_height_dp * 0.5);
    let btn_center_y = bottom_y - inset - btn_radius;
    let side_clearance = inset + (btn_radius * 2.0) + 12.0;

    Layout {
        plus_x: start_x + inset + btn_radius,
        plus_y: btn_center_y,
        plus_r: btn_radius,
        cap_x: sw_dp * 0.5,
        cap_y: center_y,
        cap_half_w: total_w * 0.5,
        cap_half_h: cap_height_dp * 0.5,
        cap_radius: CAP_CORNER_RADIUS,
        btn_x: start_x + total_w - inset - btn_radius,
        btn_y: btn_center_y,
        btn_r: btn_radius,
        input_left: start_x + side_clearance,
        input_top: bottom_y - cap_height_dp,
        input_width: (total_w - side_clearance * 2.0).max(60.0),
        input_height: cap_height_dp,
    }
}

struct Uniforms {
    res: i32,
    img_res: i32,
    u_bg_tex: i32,
    img_fade: i32,
    dpr: i32,
    plus_center: i32,
    plus_radius: i32,
    cap_center: i32,
    cap_half: i32,
    cap_radius: i32,
    btn_center: i32,
    btn_radius: i32,
    plus_press: i32,
    plus_pulse: i32,
    cap_press: i32,
    btn_press: i32,
    is_focused: i32,
    send_pulse: i32,
    tilt: i32,
    fps_box_half_w: i32,
    u_fps: i32,
}

struct GlState {
    display: EGLDisplay,
    config: EGLConfig,
    context: EGLContext,
    surface: EGLSurface,
    program: u32,
    vao: u32,
    bg_tex: u32,
    img_w: f32,
    img_h: f32,
    u: Uniforms,
    width: i32,
    height: i32,
}

impl GlState {
    unsafe fn init(window: *mut c_void, width: i32, height: i32) -> Result<Self, String> {
        let display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        if display.is_null() || eglInitialize(display, ptr::null_mut(), ptr::null_mut()) == 0 {
            return Err("EGL: eglGetDisplay/eglInitialize gagal".to_string());
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
            return Err("EGL: eglChooseConfig gagal (GLES3 tidak didukung)".to_string());
        }

        let ctx_attribs = [EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE];
        let context = eglCreateContext(display, config, EGL_NO_CONTEXT, ctx_attribs.as_ptr());
        if context.is_null() {
            return Err("EGL: eglCreateContext gagal".to_string());
        }

        let surface = eglCreateWindowSurface(display, config, window, ptr::null());
        if surface.is_null() {
            eglDestroyContext(display, context);
            return Err("EGL: eglCreateWindowSurface gagal".to_string());
        }

        if eglMakeCurrent(display, surface, surface, context) == 0 {
            eglDestroySurface(display, surface);
            eglDestroyContext(display, context);
            return Err("EGL: eglMakeCurrent gagal".to_string());
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
            let mut buf = [0u8; 512];
            let mut len = 0;
            glGetProgramInfoLog(program, 512, &mut len, buf.as_mut_ptr());
            let msg = String::from_utf8_lossy(&buf[..(len.max(0) as usize).min(512)]).to_string();
            glDeleteProgram(program);
            return Err(format!("Program link error: {msg}"));
        }

        let mut vao = 0;
        glGenVertexArrays(1, &mut vao);
        glBindVertexArray(vao);
        glUseProgram(program);

        let mut bg_tex = 0;
        glGenTextures(1, &mut bg_tex);
        glBindTexture(GL_TEXTURE_2D, bg_tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        let init_px: [u8; 4] = [238, 241, 246, 255];
        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RGBA as i32,
            1,
            1,
            0,
            GL_RGBA,
            GL_UNSIGNED_BYTE,
            init_px.as_ptr() as *const c_void,
        );

        let loc = |name: &str| {
            let c = CString::new(name).unwrap();
            glGetUniformLocation(program, c.as_ptr() as *const u8)
        };

        Ok(Self {
            display,
            config,
            context,
            surface,
            program,
            vao,
            bg_tex,
            img_w: 1.0,
            img_h: 1.0,
            u: Uniforms {
                res: loc("res"),
                img_res: loc("imgRes"),
                u_bg_tex: loc("uBgTex"),
                img_fade: loc("imgFade"),
                dpr: loc("dpr"),
                plus_center: loc("plusCenter"),
                plus_radius: loc("plusRadius"),
                cap_center: loc("capCenter"),
                cap_half: loc("capHalf"),
                cap_radius: loc("capRadius"),
                btn_center: loc("btnCenter"),
                btn_radius: loc("btnRadius"),
                plus_press: loc("plusPress"),
                plus_pulse: loc("plusPulse"),
                cap_press: loc("capPress"),
                btn_press: loc("btnPress"),
                is_focused: loc("isFocused"),
                send_pulse: loc("sendPulse"),
                tilt: loc("tilt"),
                fps_box_half_w: loc("fpsBoxHalfW"),
                u_fps: loc("uFps"),
            },
            width,
            height,
        })
    }

    unsafe fn upload_wallpaper(&mut self, rgba: &[u8], w: i32, h: i32) {
        glBindTexture(GL_TEXTURE_2D, self.bg_tex);
        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RGBA as i32,
            w,
            h,
            0,
            GL_RGBA,
            GL_UNSIGNED_BYTE,
            rgba.as_ptr() as *const c_void,
        );
        self.img_w = w.max(1) as f32;
        self.img_h = h.max(1) as f32;
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

    #[allow(clippy::too_many_arguments)]
    unsafe fn draw(
        &self,
        l: &Layout,
        dpr: f32,
        img_fade: f32,
        plus_press: f32,
        plus_pulse: f32,
        cap_press: f32,
        btn_press: f32,
        focused: f32,
        send_pulse: f32,
        fps: i32,
    ) {
        if self.surface.is_null() {
            return;
        }
        glViewport(0, 0, self.width, self.height);
        glUseProgram(self.program);
        glBindVertexArray(self.vao);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, self.bg_tex);
        glUniform1i(self.u.u_bg_tex, 0);

        glUniform2f(self.u.res, self.width as f32, self.height as f32);
        glUniform2f(self.u.img_res, self.img_w, self.img_h);
        glUniform1f(self.u.img_fade, img_fade);
        glUniform1f(self.u.dpr, dpr);

        glUniform2f(self.u.plus_center, l.plus_x * dpr, l.plus_y * dpr);
        glUniform1f(self.u.plus_radius, l.plus_r * dpr);
        glUniform2f(self.u.cap_center, l.cap_x * dpr, l.cap_y * dpr);
        glUniform2f(self.u.cap_half, l.cap_half_w * dpr, l.cap_half_h * dpr);
        glUniform1f(self.u.cap_radius, l.cap_radius * dpr);
        glUniform2f(self.u.btn_center, l.btn_x * dpr, l.btn_y * dpr);
        glUniform1f(self.u.btn_radius, l.btn_r * dpr);

        glUniform1f(self.u.plus_press, plus_press);
        glUniform1f(self.u.plus_pulse, plus_pulse);
        glUniform1f(self.u.cap_press, cap_press);
        glUniform1f(self.u.btn_press, btn_press);
        glUniform1f(self.u.is_focused, focused);
        glUniform1f(self.u.send_pulse, send_pulse);
        glUniform2f(self.u.tilt, 0.0, 0.0);
        glUniform1f(self.u.fps_box_half_w, 34.0 * dpr);
        glUniform1i(self.u.u_fps, fps);

        glDrawArrays(GL_TRIANGLES, 0, 3);
        eglSwapBuffers(self.display, self.surface);
    }

    unsafe fn destroy(&mut self) {
        eglMakeCurrent(self.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if self.bg_tex != 0 {
            glDeleteTextures(1, &self.bg_tex);
        }
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

unsafe fn compile_shader(ty: u32, src: &str) -> Result<u32, String> {
    let shader = glCreateShader(ty);
    let ptr = src.as_ptr();
    glShaderSource(shader, 1, &ptr, ptr::null());
    glCompileShader(shader);
    let mut ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &mut ok);
    if ok == 0 {
        let mut buf = [0u8; 512];
        let mut len = 0;
        glGetShaderInfoLog(shader, 512, &mut len, buf.as_mut_ptr());
        let msg = String::from_utf8_lossy(&buf[..(len.max(0) as usize).min(512)]).to_string();
        glDeleteShader(shader);
        let kind = if ty == GL_VERTEX_SHADER { "Vertex" } else { "Fragment" };
        return Err(format!("{kind} shader compile error: {msg}"));
    }
    Ok(shader)
}

fn hit_plus(x_dp: f32, y_dp: f32, l: &Layout) -> bool {
    (x_dp - l.plus_x).hypot(y_dp - l.plus_y) <= (l.plus_r + 4.0)
}

fn hit_send(x_dp: f32, y_dp: f32, l: &Layout) -> bool {
    (x_dp - l.btn_x).hypot(y_dp - l.btn_y) <= (l.btn_r + 4.0)
}

fn hit_capsule(x_dp: f32, y_dp: f32, l: &Layout) -> bool {
    let px = x_dp - l.cap_x;
    let py = y_dp - l.cap_y;
    let r = l.cap_radius;
    let qx = px.abs() - (l.cap_half_w - r);
    let qy = py.abs() - (l.cap_half_h - r);
    let d = qx.max(0.0).hypot(qy.max(0.0)) + qx.max(qy).min(0.0) - r;
    d <= 4.0
}

fn call_java_void(vm: &JavaVM, activity: *mut c_void, method: &str, sig: &str, args: &[JValue]) {
    if let Ok(mut env) = vm.attach_current_thread() {
        let obj = unsafe { JObject::from_raw(activity as jni::sys::jobject) };
        let _ = env.call_method(&obj, method, sig, args);
        if env.exception_check().unwrap_or(false) {
            let _ = env.exception_describe();
            let _ = env.exception_clear();
        }
        std::mem::forget(obj);
    }
}

fn report_error_to_java(vm: &JavaVM, activity: *mut c_void, msg: &str) {
    if let Ok(mut env) = vm.attach_current_thread() {
        let obj = unsafe { JObject::from_raw(activity as jni::sys::jobject) };
        if let Ok(jstr) = env.new_string(msg) {
            let _ = env.call_method(
                &obj,
                "showErrorAndCopy",
                "(Ljava/lang/String;)V",
                &[JValue::Object(&jstr)],
            );
        }
        if env.exception_check().unwrap_or(false) {
            let _ = env.exception_clear();
        }
        std::mem::forget(obj);
    }
}

#[no_mangle]
fn android_main(app: AndroidApp) {
    let vm = unsafe { JavaVM::from_raw(app.vm_as_ptr() as *mut _) }.ok();
    let activity_ptr = app.activity_as_ptr();
    let activity_addr = activity_ptr as usize;
    let vm_addr = app.vm_as_ptr() as usize;

    std::panic::set_hook(Box::new(move |info| {
        let vm_ptr = vm_addr as *mut jni::sys::JavaVM;
        if let Ok(vm) = unsafe { JavaVM::from_raw(vm_ptr) } {
            report_error_to_java(&vm, activity_addr as *mut c_void, &format!("Rust Panic:\n{info}"));
        }
    }));

    let dpr = app
        .config()
        .density()
        .map(|d| (d as f32 / 160.0).max(1.0))
        .unwrap_or(2.5);

    if let Some(ref vm) = vm {
        call_java_void(vm, activity_ptr, "loadWallpaper", "(I)V", &[JValue::Int(0)]);
    }

    let mut gl: Option<GlState> = None;
    let mut running = true;
    let mut has_window = false;

    let mut current_cap_height = BASE_CAP_HEIGHT;
    let mut plus_pressed = false;
    let mut cap_pressed = false;
    let mut btn_pressed = false;
    let mut bg_pressed = false;

    let mut plus_press_val: f32 = 0.0;
    let mut cap_press_val: f32 = 0.0;
    let mut btn_press_val: f32 = 0.0;
    let mut plus_pulse_val: f32 = 0.0;
    let mut focus_val: f32 = 0.0;
    let mut send_pulse_val: f32 = 0.0;
    let mut img_fade: f32 = 0.0;
    let mut current_wall_idx: i32 = 0;

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
                                match GlState::init(win.ptr().as_ptr() as *mut c_void, w, h) {
                                    Ok(state) => gl = Some(state),
                                    Err(err) => {
                                        if let Some(ref vm) = vm {
                                            report_error_to_java(vm, activity_ptr, &err);
                                        }
                                    }
                                }
                            }
                        }
                        has_window = true;
                    }
                }
                MainEvent::WindowResized { .. } | MainEvent::RedrawNeeded { .. } => {
                    if let (Some(ref mut state), Some(win)) = (&mut gl, app.native_window()) {
                        state.width = win.width().max(1);
                        state.height = win.height().max(1);
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

        let (w_px, h_px) = gl
            .as_ref()
            .map(|g| (g.width as f32, g.height as f32))
            .unwrap_or((1080.0, 2400.0));
        let sw_dp = w_px / dpr;
        let sh_dp = h_px / dpr;
        let kb_dp = KEYBOARD_INSET_PX.load(Ordering::Relaxed) as f32 / dpr;
        let layout = get_layout(sw_dp, sh_dp, current_cap_height, kb_dp);

        if let Ok(mut iter) = app.input_events_iter() {
            while iter.next(|event| match event {
                InputEvent::MotionEvent(motion) => {
                    match motion.action() {
                        MotionAction::Down | MotionAction::PointerDown => {
                            let p = motion.pointer_at_index(motion.pointer_index());
                            let x_dp = p.x() / dpr;
                            let y_dp = p.y() / dpr;
                            if hit_plus(x_dp, y_dp, &layout) {
                                plus_pressed = true;
                            } else if hit_send(x_dp, y_dp, &layout) {
                                btn_pressed = true;
                            } else if hit_capsule(x_dp, y_dp, &layout) {
                                cap_pressed = true;
                            } else {
                                bg_pressed = true;
                                if let Some(ref vm) = vm {
                                    call_java_void(vm, activity_ptr, "blurInput", "()V", &[]);
                                }
                            }
                        }
                        MotionAction::Up | MotionAction::PointerUp => {
                            let p = motion.pointer_at_index(motion.pointer_index());
                            let x_dp = p.x() / dpr;
                            let y_dp = p.y() / dpr;
                            if plus_pressed {
                                plus_pressed = false;
                                if hit_plus(x_dp, y_dp, &layout) {
                                    plus_pulse_val = 1.0;
                                    if let Some(ref vm) = vm {
                                        call_java_void(vm, activity_ptr, "vibrateHaptic", "()V", &[]);
                                    }
                                }
                            } else if btn_pressed {
                                btn_pressed = false;
                                if hit_send(x_dp, y_dp, &layout) {
                                    send_pulse_val = 1.0;
                                    if let Some(ref vm) = vm {
                                        call_java_void(vm, activity_ptr, "vibrateHaptic", "()V", &[]);
                                        call_java_void(vm, activity_ptr, "clearInput", "()V", &[]);
                                    }
                                }
                            } else if cap_pressed {
                                cap_pressed = false;
                                if hit_capsule(x_dp, y_dp, &layout) {
                                    if let Some(ref vm) = vm {
                                        call_java_void(vm, activity_ptr, "vibrateHaptic", "()V", &[]);
                                        call_java_void(vm, activity_ptr, "focusInput", "()V", &[]);
                                    }
                                }
                            } else if bg_pressed {
                                bg_pressed = false;
                                current_wall_idx = (current_wall_idx + 1) % 28;
                                if let Some(ref vm) = vm {
                                    call_java_void(
                                        vm,
                                        activity_ptr,
                                        "loadWallpaper",
                                        "(I)V",
                                        &[JValue::Int(current_wall_idx)],
                                    );
                                }
                            }
                        }
                        MotionAction::Cancel => {
                            plus_pressed = false;
                            cap_pressed = false;
                            btn_pressed = false;
                            bg_pressed = false;
                        }
                        _ => {}
                    }
                    InputStatus::Handled
                }
                _ => InputStatus::Unhandled,
            }) {}
        }

        // Upload loaded wallpaper if ready
        if let Ok(mut guard) = PENDING_WALLPAPER.lock() {
            if let Some(wp) = guard.take() {
                if let Some(ref mut state) = gl {
                    unsafe { state.upload_wallpaper(&wp.rgba, wp.w, wp.h) };
                    img_fade = 0.05;
                }
            }
        }

        let now = Instant::now();
        let dt = now.duration_since(last_tick).as_secs_f32().min(0.05);
        last_tick = now;

        let target_cap_h = f32::from_bits(TARGET_CAP_HEIGHT_DP.load(Ordering::Relaxed));
        current_cap_height += (target_cap_h - current_cap_height) * (dt * 18.0).min(1.0);
        if (target_cap_h - current_cap_height).abs() < 0.15 {
            current_cap_height = target_cap_h;
        }

        if img_fade > 0.0 && img_fade < 1.0 {
            img_fade = (img_fade + dt * 3.0).min(1.0);
        }

        let focused = if IS_FOCUSED.load(Ordering::Relaxed) { 1.0 } else { 0.0 };
        plus_press_val += ((if plus_pressed { 1.0 } else { 0.0 }) - plus_press_val) * (dt * 18.0).min(1.0);
        cap_press_val += ((if cap_pressed { 1.0 } else { 0.0 }) - cap_press_val) * (dt * 18.0).min(1.0);
        btn_press_val += ((if btn_pressed { 1.0 } else { 0.0 }) - btn_press_val) * (dt * 18.0).min(1.0);
        focus_val += (focused - focus_val) * (dt * 12.0).min(1.0);
        plus_pulse_val *= (0.86_f32).powf(dt * 60.0);
        send_pulse_val *= (0.86_f32).powf(dt * 60.0);

        let updated_layout = get_layout(sw_dp, sh_dp, current_cap_height, kb_dp);
        if let Some(ref vm) = vm {
            call_java_void(
                vm,
                activity_ptr,
                "syncInputLayout",
                "(IIIIF)V",
                &[
                    JValue::Int((updated_layout.input_left * dpr).round() as i32),
                    JValue::Int((updated_layout.input_top * dpr).round() as i32),
                    JValue::Int((updated_layout.input_width * dpr).round() as i32),
                    JValue::Int((updated_layout.input_height * dpr).round() as i32),
                    JValue::Float(cap_press_val * 1.4 * dpr),
                ],
            );
        }

        if has_window {
            if let Some(ref state) = gl {
                unsafe {
                    state.draw(
                        &updated_layout,
                        dpr,
                        img_fade,
                        plus_press_val,
                        plus_pulse_val,
                        cap_press_val,
                        btn_press_val,
                        focus_val,
                        send_pulse_val,
                        current_fps,
                    );
                }
            }
            frame_count += 1;
            let fps_elapsed = now.duration_since(fps_timer).as_secs_f32();
            if fps_elapsed >= 0.35 {
                current_fps = (frame_count as f32 / fps_elapsed).round() as i32;
                frame_count = 0;
                fps_timer = now;
            }
        }
    }

    if let Some(ref mut state) = gl {
        unsafe {
            state.destroy();
        }
    }
}
