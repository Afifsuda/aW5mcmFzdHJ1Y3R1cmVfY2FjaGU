package com.afifsuda.canvas;

import android.app.AlertDialog;
import android.app.NativeActivity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.InputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends NativeActivity {
    static {
        System.loadLibrary("antigravity_canvas");
    }

    private static native void nativeOnWallpaperLoaded(byte[] rgba, int width, int height);
    private static native void nativeSetTargetCapHeight(float heightDp);
    private static native void nativeSetFocused(boolean focused);
    private static native void nativeSetKeyboardInset(int insetPx);

    private static final String[] WALLPAPERS = {
        "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1494500764479-0c8f2919a3d8?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1558591710-4b4a1ae0f04d?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1518837695005-2083093ee35b?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1505761671935-60b3a7427bad?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1557683316-973673baf926?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1504333638930-c8787321eee0?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1516912481808-3406841bd33c?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1531366936337-7c912a4589a7?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?auto=format&fit=crop&w=1080&q=85",
        "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=1080&q=85"
    };

    private final Handler uiHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private WindowManager windowManager;
    private EditText msgInput;
    private TextView fpsLabel;
    private WindowManager.LayoutParams fpsLp;
    private WindowManager.LayoutParams inputLp;
    private boolean overlaysAttached = false;
    private float density = 1.0f;
    private int lastLeft = -1, lastTop = -1, lastWidth = -1, lastHeight = -1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Thread.setDefaultUncaughtExceptionHandler((thread, throwable) -> {
            StringWriter sw = new StringWriter();
            throwable.printStackTrace(new PrintWriter(sw));
            showErrorAndCopy("Uncaught Exception (" + thread.getName() + "):\n" + sw.toString());
        });
        super.onCreate(savedInstanceState);
        density = getResources().getDisplayMetrics().density;
        windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);

        fpsLabel = new TextView(this);
        fpsLabel.setText("60fps");
        fpsLabel.setTextColor(Color.parseColor("#141923"));
        fpsLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        fpsLabel.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        fpsLabel.setIncludeFontPadding(false);
        fpsLabel.setGravity(Gravity.CENTER);
        fpsLabel.setBackgroundColor(Color.TRANSPARENT);

        msgInput = new EditText(this);
        msgInput.setBackgroundColor(Color.TRANSPARENT);
        msgInput.setHint("Tulis pesan...");
        msgInput.setHintTextColor(Color.parseColor("#768296"));
        msgInput.setTextColor(Color.parseColor("#111622"));
        msgInput.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
        msgInput.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        msgInput.setPadding(0, (int) (14 * density), 0, (int) (14 * density));
        msgInput.setInputType(
            InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        );
        msgInput.setMaxLines(6);
        msgInput.setVerticalScrollBarEnabled(true);
        msgInput.setOnFocusChangeListener((v, hasFocus) -> nativeSetFocused(hasFocus));
        msgInput.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {}
            @Override public void afterTextChanged(Editable s) {
                recalcHeight();
            }
        });

        final View root = getWindow().getDecorView();
        root.post(this::attachOverlays);
        root.getViewTreeObserver().addOnGlobalLayoutListener(new ViewTreeObserver.OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                Rect r = new Rect();
                root.getWindowVisibleDisplayFrame(r);
                int screenH = root.getHeight();
                int keypad = Math.max(0, screenH - r.bottom);
                nativeSetKeyboardInset(keypad > screenH * 0.12 ? keypad : 0);
            }
        });
    }

    private void attachOverlays() {
        if (overlaysAttached || isFinishing() || windowManager == null) return;
        IBinder token = getWindow().getDecorView().getWindowToken();
        if (token == null) {
            getWindow().getDecorView().postDelayed(this::attachOverlays, 50);
            return;
        }

        fpsLp = new WindowManager.LayoutParams(
            (int) (68 * density),
            (int) (28 * density),
            WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        fpsLp.token = token;
        fpsLp.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        fpsLp.y = (int) (30 * density);

        inputLp = new WindowManager.LayoutParams(
            100,
            (int) (52 * density),
            WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        inputLp.token = token;
        inputLp.gravity = Gravity.TOP | Gravity.START;
        inputLp.x = 0;
        inputLp.y = 0;

        try {
            windowManager.addView(fpsLabel, fpsLp);
            windowManager.addView(msgInput, inputLp);
            overlaysAttached = true;
        } catch (Throwable t) {
            StringWriter sw = new StringWriter();
            t.printStackTrace(new PrintWriter(sw));
            showErrorAndCopy("Overlay attach error:\n" + sw.toString());
        }
    }

    private void recalcHeight() {
        if (msgInput == null || msgInput.getWidth() <= 0) return;
        int wSpec = View.MeasureSpec.makeMeasureSpec(msgInput.getWidth(), View.MeasureSpec.EXACTLY);
        int hSpec = View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED);
        msgInput.measure(wSpec, hSpec);
        float contentDp = msgInput.getMeasuredHeight() / density;
        float clamped = Math.max(52f, Math.min(162f, contentDp));
        nativeSetTargetCapHeight(clamped);
    }

    public void syncInputLayout(final int leftPx, final int topPx, final int widthPx, final int heightPx, final float dropPx) {
        uiHandler.post(() -> {
            if (!overlaysAttached || msgInput == null || inputLp == null || windowManager == null) return;
            int targetY = topPx + Math.round(dropPx);
            if (leftPx != lastLeft || targetY != lastTop || widthPx != lastWidth || heightPx != lastHeight) {
                lastLeft = leftPx;
                lastTop = targetY;
                lastWidth = widthPx;
                lastHeight = heightPx;
                inputLp.x = leftPx;
                inputLp.y = targetY;
                inputLp.width = Math.max(60, widthPx);
                inputLp.height = Math.max(1, heightPx);
                try {
                    windowManager.updateViewLayout(msgInput, inputLp);
                } catch (Throwable ignored) {
                }
            }
        });
    }

    public void focusInput() {
        uiHandler.post(() -> {
            if (!overlaysAttached || msgInput == null || inputLp == null || windowManager == null) return;
            inputLp.flags &= ~WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
            try {
                windowManager.updateViewLayout(msgInput, inputLp);
            } catch (Throwable ignored) {
            }
            msgInput.requestFocus();
            InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
            if (imm != null) imm.showSoftInput(msgInput, InputMethodManager.SHOW_IMPLICIT);
        });
    }

    public void blurInput() {
        uiHandler.post(() -> {
            if (!overlaysAttached || msgInput == null || inputLp == null || windowManager == null) return;
            msgInput.clearFocus();
            InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
            if (imm != null) imm.hideSoftInputFromWindow(msgInput.getWindowToken(), 0);
            inputLp.flags |= WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
            try {
                windowManager.updateViewLayout(msgInput, inputLp);
            } catch (Throwable ignored) {
            }
        });
    }

    public void clearInput() {
        uiHandler.post(() -> {
            if (msgInput != null && msgInput.getText().length() > 0) {
                msgInput.setText("");
                nativeSetTargetCapHeight(52f);
            }
        });
    }

    public void updateFpsLabel(final int fps) {
        uiHandler.post(() -> {
            if (fpsLabel != null) {
                fpsLabel.setText(fps + "fps");
            }
        });
    }

    public void vibrateHaptic() {
        uiHandler.post(() -> {
            if (msgInput != null) {
                msgInput.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
            }
        });
    }

    public void loadWallpaper(final int index) {
        executor.execute(() -> {
            HttpURLConnection conn = null;
            try {
                String urlStr = WALLPAPERS[Math.abs(index) % WALLPAPERS.length];
                conn = (HttpURLConnection) new URL(urlStr).openConnection();
                conn.setConnectTimeout(8000);
                conn.setReadTimeout(10000);
                conn.setInstanceFollowRedirects(true);
                try (InputStream is = conn.getInputStream()) {
                    Bitmap bmp = BitmapFactory.decodeStream(is);
                    if (bmp != null) {
                        Bitmap rgbaBmp = bmp.getConfig() == Bitmap.Config.ARGB_8888
                            ? bmp
                            : bmp.copy(Bitmap.Config.ARGB_8888, false);
                        if (rgbaBmp != bmp) bmp.recycle();
                        int w = rgbaBmp.getWidth();
                        int h = rgbaBmp.getHeight();
                        ByteBuffer buf = ByteBuffer.allocate(w * h * 4);
                        rgbaBmp.copyPixelsToBuffer(buf);
                        rgbaBmp.recycle();
                        nativeOnWallpaperLoaded(buf.array(), w, h);
                    }
                }
            } catch (Throwable ignored) {
            } finally {
                if (conn != null) conn.disconnect();
            }
        });
    }

    public void showErrorAndCopy(final String errorText) {
        uiHandler.post(() -> {
            try {
                ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                if (cm != null) {
                    cm.setPrimaryClip(ClipData.newPlainText("App Error", errorText));
                }
                Toast.makeText(this, "Error otomatis disalin ke clipboard", Toast.LENGTH_SHORT).show();

                ScrollView scroll = new ScrollView(this);
                TextView tv = new TextView(this);
                tv.setText(errorText);
                tv.setTextIsSelectable(true);
                tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
                int pad = (int) (16 * density);
                tv.setPadding(pad, pad, pad, pad);
                scroll.addView(tv);

                new AlertDialog.Builder(this)
                    .setTitle("Terjadi Error (Tersalin ke Clipboard)")
                    .setView(scroll)
                    .setPositiveButton("Salin Lagi", (d, w) -> {
                        if (cm != null) {
                            cm.setPrimaryClip(ClipData.newPlainText("App Error", errorText));
                        }
                    })
                    .setNegativeButton("Tutup", null)
                    .show();
            } catch (Throwable ignored) {
            }
        });
    }

    @Override
    protected void onDestroy() {
        if (overlaysAttached && windowManager != null) {
            try { windowManager.removeViewImmediate(fpsLabel); } catch (Throwable ignored) {}
            try { windowManager.removeViewImmediate(msgInput); } catch (Throwable ignored) {}
            overlaysAttached = false;
        }
        executor.shutdownNow();
        super.onDestroy();
    }
}
