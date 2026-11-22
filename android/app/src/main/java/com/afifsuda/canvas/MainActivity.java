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
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.util.Base64;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

public class MainActivity extends NativeActivity {
    static {
        System.loadLibrary("antigravity_canvas");
    }

    private static native void nativeOnWallpaperLoaded(byte[] rgba, int width, int height);
    private static native void nativeSetTargetCapHeight(float heightDp);
    private static native void nativeSetFocused(boolean focused);
    private static native void nativeSetKeyboardInset(int insetPx);
    private static native void nativeSetCapPressed(boolean pressed);

    private static final String RELAY_HOST = "aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev";
    private static final String RELAY_PATH = "/?room=1234";

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
    private final ExecutorService wsSendExecutor = Executors.newSingleThreadExecutor();
    private final SecureRandom rng = new SecureRandom();

    private WindowManager windowManager;
    private EditText msgInput;
    private TextView fpsLabel;
    private FrameLayout chatRoot;
    private ScrollView chatScroll;
    private LinearLayout chatContainer;
    private WindowManager.LayoutParams fpsLp;
    private WindowManager.LayoutParams inputLp;
    private WindowManager.LayoutParams chatLp;

    private boolean overlaysAttached = false;
    private float density = 1.0f;
    private int lastLeft = -1, lastTop = -1, lastWidth = -1, lastHeight = -1;
    private int lastChatHeight = -1;

    private volatile boolean wsRunning = true;
    private volatile SSLSocket wsSocket;
    private volatile OutputStream wsOut;
    private Thread wsThread;

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

        chatRoot = new FrameLayout(this);
        chatRoot.setVisibility(View.INVISIBLE);
        chatRoot.setBackgroundColor(Color.TRANSPARENT);
        chatRoot.setClipChildren(false);
        chatRoot.setClipToPadding(false);

        chatScroll = new ScrollView(this);
        chatScroll.setBackgroundColor(Color.TRANSPARENT);
        chatScroll.setVerticalScrollBarEnabled(false);
        chatScroll.setOverScrollMode(View.OVER_SCROLL_NEVER);
        chatScroll.setClipChildren(false);
        chatScroll.setClipToPadding(false);

        chatContainer = new LinearLayout(this);
        chatContainer.setOrientation(LinearLayout.VERTICAL);
        chatContainer.setClipChildren(false);
        chatContainer.setClipToPadding(false);
        int padH = (int) (14 * density);
        int padV = (int) (16 * density);
        chatContainer.setPadding(padH, padV, padH, padV);
        chatScroll.addView(chatContainer, new ScrollView.LayoutParams(
            ScrollView.LayoutParams.MATCH_PARENT,
            ScrollView.LayoutParams.WRAP_CONTENT
        ));
        chatRoot.addView(chatScroll, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ));

        // Top & Bottom soft shadow/fade overlay agar chat tidak terpotong kasar
        View topFade = new View(this);
        topFade.setBackground(new GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            new int[]{Color.argb(95, 238, 241, 246), Color.argb(0, 238, 241, 246)}
        ));
        chatRoot.addView(topFade, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            (int) (22 * density),
            Gravity.TOP
        ));

        View bottomFade = new View(this);
        bottomFade.setBackground(new GradientDrawable(
            GradientDrawable.Orientation.BOTTOM_TOP,
            new int[]{Color.argb(115, 238, 241, 246), Color.argb(0, 238, 241, 246)}
        ));
        chatRoot.addView(bottomFade, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            (int) (24 * density),
            Gravity.BOTTOM
        ));

        msgInput = new EditText(this);
        msgInput.setVisibility(View.INVISIBLE);
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
        msgInput.setOnTouchListener((v, event) -> {
            int action = event.getActionMasked();
            if (action == MotionEvent.ACTION_DOWN) {
                nativeSetCapPressed(true);
                v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
                focusInput();
            } else if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
                nativeSetCapPressed(false);
            }
            return false;
        });
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

        startWebSocketLoop();
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

        chatLp = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            (int) (200 * density),
            WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        chatLp.token = token;
        chatLp.gravity = Gravity.TOP | Gravity.START;
        chatLp.x = 0;
        chatLp.y = (int) (70 * density);

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
            windowManager.addView(chatRoot, chatLp);
            windowManager.addView(fpsLabel, fpsLp);
            windowManager.addView(msgInput, inputLp);
            overlaysAttached = true;
        } catch (Throwable t) {
            StringWriter sw = new StringWriter();
            t.printStackTrace(new PrintWriter(sw));
            showErrorAndCopy("Overlay attach error:\n" + sw.toString());
        }
    }

    private void addChatBubble(final String text, final boolean isSelf) {
        uiHandler.post(() -> {
            if (chatContainer == null || chatScroll == null) return;

            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            row.setGravity(isSelf ? Gravity.END : Gravity.START);
            LinearLayout.LayoutParams rowLp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            );
            rowLp.bottomMargin = (int) (8 * density);

            TextView bubble = new TextView(this);
            bubble.setText(text);
            bubble.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
            bubble.setTextColor(isSelf ? Color.WHITE : Color.parseColor("#111622"));
            bubble.setMaxWidth((int) (270 * density));
            float r = 18 * density;
            float sm = 5 * density;
            float[] radii = isSelf
                ? new float[]{r, r, r, r, sm, sm, r, r}
                : new float[]{r, r, r, r, r, r, sm, sm};

            GradientDrawable shadow = new GradientDrawable();
            shadow.setColor(Color.argb(34, 20, 30, 48));
            shadow.setCornerRadii(radii);

            GradientDrawable bg = new GradientDrawable();
            if (isSelf) {
                bg.setColor(Color.parseColor("#1970F5"));
            } else {
                bg.setColor(Color.parseColor("#F5F8FC"));
                bg.setStroke((int) Math.max(1, density), Color.parseColor("#D8E0EC"));
            }
            bg.setCornerRadii(radii);

            LayerDrawable layered = new LayerDrawable(new android.graphics.drawable.Drawable[]{shadow, bg});
            int padS = (int) (1.5f * density);
            int padB = (int) (3.5f * density);
            layered.setLayerInset(1, padS, padS, padS, padB);
            bubble.setBackground(layered);

            int px = (int) (15 * density) + padS;
            int py = (int) (10 * density) + padS;
            bubble.setPadding(px, py, px, py + padB);

            row.addView(bubble);
            chatContainer.addView(row, rowLp);
            chatScroll.post(() -> chatScroll.fullScroll(View.FOCUS_DOWN));
        });
    }

    private void startWebSocketLoop() {
        wsThread = new Thread(() -> {
            while (wsRunning) {
                try {
                    SSLSocketFactory factory = (SSLSocketFactory) SSLSocketFactory.getDefault();
                    SSLSocket socket = (SSLSocket) factory.createSocket(RELAY_HOST, 443);
                    socket.setSoTimeout(0);
                    socket.startHandshake();

                    byte[] keyBytes = new byte[16];
                    rng.nextBytes(keyBytes);
                    String wsKey = Base64.encodeToString(keyBytes, Base64.NO_WRAP);

                    OutputStream out = socket.getOutputStream();
                    String req = "GET " + RELAY_PATH + " HTTP/1.1\r\n"
                        + "Host: " + RELAY_HOST + "\r\n"
                        + "Upgrade: websocket\r\n"
                        + "Connection: Upgrade\r\n"
                        + "Sec-WebSocket-Key: " + wsKey + "\r\n"
                        + "Sec-WebSocket-Version: 13\r\n\r\n";
                    out.write(req.getBytes(StandardCharsets.US_ASCII));
                    out.flush();

                    DataInputStream in = new DataInputStream(socket.getInputStream());
                    String statusLine = readHttpLine(in);
                    if (statusLine == null || !statusLine.contains("101")) {
                        socket.close();
                        Thread.sleep(3000);
                        continue;
                    }
                    String line;
                    while ((line = readHttpLine(in)) != null && !line.isEmpty()) {
                        // Consume headers
                    }

                    wsSocket = socket;
                    wsOut = out;

                    while (wsRunning) {
                        int b0 = in.readUnsignedByte();
                        int b1 = in.readUnsignedByte();
                        int opcode = b0 & 0x0F;
                        boolean masked = (b1 & 0x80) != 0;
                        long len = b1 & 0x7F;
                        if (len == 126) {
                            len = in.readUnsignedShort();
                        } else if (len == 127) {
                            len = in.readLong();
                        }
                        byte[] mask = new byte[4];
                        if (masked) in.readFully(mask);
                        if (len > 1024 * 1024) break;

                        byte[] payload = new byte[(int) len];
                        in.readFully(payload);
                        if (masked) {
                            for (int i = 0; i < payload.length; i++) {
                                payload[i] ^= mask[i % 4];
                            }
                        }

                        if (opcode == 0x8) {
                            break;
                        } else if (opcode == 0x9) {
                            sendWsFrame(0xA, payload);
                        } else if (opcode == 0x1) {
                            String msg = new String(payload, StandardCharsets.UTF_8);
                            try {
                                JSONObject obj = new JSONObject(msg);
                                if ("chat".equals(obj.optString("type"))) {
                                    String txt = obj.optString("text", "").trim();
                                    if (!txt.isEmpty()) {
                                        addChatBubble(txt, false);
                                    }
                                }
                            } catch (Throwable ignored) {
                            }
                        }
                    }
                } catch (Throwable ignored) {
                } finally {
                    wsOut = null;
                    try {
                        if (wsSocket != null) wsSocket.close();
                    } catch (Throwable ignored) {
                    }
                    wsSocket = null;
                }
                if (wsRunning) {
                    try { Thread.sleep(3000); } catch (InterruptedException ignored) {}
                }
            }
        }, "AgyWsClient");
        wsThread.start();
    }

    private String readHttpLine(DataInputStream in) throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        int prev = -1;
        while (true) {
            int b = in.read();
            if (b == -1) return null;
            if (b == '\n') {
                byte[] arr = baos.toByteArray();
                int len = (prev == '\r' && arr.length > 0) ? arr.length - 1 : arr.length;
                return new String(arr, 0, len, StandardCharsets.US_ASCII);
            }
            baos.write(b);
            prev = b;
        }
    }

    private void sendWsFrame(int opcode, byte[] payload) {
        OutputStream out = wsOut;
        if (out == null) return;
        wsSendExecutor.execute(() -> {
            try {
                OutputStream o = wsOut;
                if (o == null) return;
                ByteArrayOutputStream frame = new ByteArrayOutputStream();
                frame.write(0x80 | (opcode & 0x0F));
                int len = payload.length;
                if (len <= 125) {
                    frame.write(0x80 | len);
                } else if (len <= 65535) {
                    frame.write(0x80 | 126);
                    frame.write((len >> 8) & 0xFF);
                    frame.write(len & 0xFF);
                } else {
                    frame.write(0x80 | 127);
                    for (int i = 7; i >= 0; i--) {
                        frame.write((int) (((long) len >> (i * 8)) & 0xFF));
                    }
                }
                byte[] mask = new byte[4];
                rng.nextBytes(mask);
                frame.write(mask);
                for (int i = 0; i < len; i++) {
                    frame.write(payload[i] ^ mask[i % 4]);
                }
                o.write(frame.toByteArray());
                o.flush();
            } catch (Throwable ignored) {
            }
        });
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
            if (msgInput.getVisibility() != View.VISIBLE && widthPx > 60 && targetY > 0) {
                msgInput.setVisibility(View.VISIBLE);
            }

            if (chatRoot != null && chatScroll != null && chatLp != null && targetY > 0) {
                int chatTop = (int) (70 * density);
                int chatH = Math.max((int) (40 * density), targetY - chatTop - (int) (8 * density));
                if (Math.abs(chatH - lastChatHeight) > 2) {
                    lastChatHeight = chatH;
                    chatLp.y = chatTop;
                    chatLp.height = chatH;
                    try {
                        windowManager.updateViewLayout(chatRoot, chatLp);
                    } catch (Throwable ignored) {
                    }
                    if (chatRoot.getVisibility() != View.VISIBLE) {
                        chatRoot.setVisibility(View.VISIBLE);
                    }
                    chatScroll.post(() -> chatScroll.fullScroll(View.FOCUS_DOWN));
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

    public void sendMessage() {
        uiHandler.post(() -> {
            if (msgInput == null) return;
            String text = msgInput.getText().toString().trim();
            if (!text.isEmpty()) {
                msgInput.setText("");
                nativeSetTargetCapHeight(52f);
                addChatBubble(text, true);
                try {
                    JSONObject obj = new JSONObject();
                    obj.put("type", "chat");
                    obj.put("text", text);
                    sendWsFrame(0x1, obj.toString().getBytes(StandardCharsets.UTF_8));
                } catch (Throwable ignored) {
                }
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
        wsRunning = false;
        try { if (wsSocket != null) wsSocket.close(); } catch (Throwable ignored) {}
        if (overlaysAttached && windowManager != null) {
            try { windowManager.removeViewImmediate(chatRoot); } catch (Throwable ignored) {}
            try { windowManager.removeViewImmediate(fpsLabel); } catch (Throwable ignored) {}
            try { windowManager.removeViewImmediate(msgInput); } catch (Throwable ignored) {}
            overlaysAttached = false;
        }
        executor.shutdownNow();
        wsSendExecutor.shutdownNow();
        super.onDestroy();
    }
}
