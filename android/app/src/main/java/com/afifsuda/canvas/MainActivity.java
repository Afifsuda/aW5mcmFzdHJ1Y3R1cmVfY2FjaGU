package com.afifsuda.canvas;

import android.app.AlertDialog;
import android.app.NativeActivity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
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
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.HttpURLConnection;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URL;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.Date;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
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
    private static native void nativeSetModalOpen(boolean open);
    private static native void nativeSetModalBounds(float cx, float cy, float hw, float hh);

    private static final String RELAY_HOST = "aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev";
    private static final String RELAY_PATH = "/?room=1234";
    private static final int LOCAL_PORT = 8080;
    private static final int DISCOVERY_PORT = 8081;

    private static final String MODE_HOST = "host";
    private static final String MODE_CLIENT = "client";
    private static final String MODE_CLOUDFLARE = "cloudflare";

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
    private ScrollView chatScroll;
    private LinearLayout chatContainer;
    private WindowManager.LayoutParams fpsLp;
    private WindowManager.LayoutParams inputLp;
    private WindowManager.LayoutParams chatLp;
    private FrameLayout modalRoot;
    private LinearLayout modalCard;
    private WindowManager.LayoutParams modalLp;

    private boolean overlaysAttached = false;
    private float density = 1.0f;
    private int lastLeft = -1, lastTop = -1, lastWidth = -1, lastHeight = -1;
    private int lastChatHeight = -1;

    private volatile boolean appRunning = true;
    private volatile boolean wsConnected = false;
    private volatile Socket wsClientSocket;
    private volatile OutputStream wsOut;
    private Thread netThread;

    private volatile ServerSocket hostServerSocket;
    private final CopyOnWriteArrayList<HostPeer> hostPeers = new CopyOnWriteArrayList<>();
    private final ConcurrentHashMap<String, String> discoveredHosts = new ConcurrentHashMap<>();
    private volatile String lastNetError = "";
    private Thread discoveryThread;

    private final Object historyLock = new Object();
    private JSONArray chatHistory = new JSONArray();
    private String deviceId = "";
    private String netMode = MODE_HOST;
    private String hostIp = "192.168.1.2";

    private static class HostPeer {
        final Socket socket;
        final OutputStream out;
        HostPeer(Socket s, OutputStream o) { this.socket = s; this.out = o; }
    }

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

        SharedPreferences prefs = getSharedPreferences("cf_usage", Context.MODE_PRIVATE);
        deviceId = getOrCreateDeviceId();
        netMode = prefs.getString("net_mode", MODE_HOST);
        hostIp = prefs.getString("host_ip", "192.168.1.2");

        fpsLabel = new TextView(this);
        fpsLabel.setText("60fps");
        fpsLabel.setTextColor(Color.parseColor("#141923"));
        fpsLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        fpsLabel.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        fpsLabel.setIncludeFontPadding(false);
        fpsLabel.setGravity(Gravity.CENTER);
        fpsLabel.setBackgroundColor(Color.TRANSPARENT);

        chatScroll = new ScrollView(this);
        chatScroll.setVisibility(View.INVISIBLE);
        chatScroll.setBackgroundColor(Color.TRANSPARENT);
        chatScroll.setVerticalScrollBarEnabled(false);
        chatScroll.setOverScrollMode(View.OVER_SCROLL_NEVER);

        chatContainer = new LinearLayout(this);
        chatContainer.setOrientation(LinearLayout.VERTICAL);
        int padH = (int) (14 * density);
        int padV = (int) (8 * density);
        chatContainer.setPadding(padH, padV, padH, padV);
        chatScroll.addView(chatContainer, new ScrollView.LayoutParams(
            ScrollView.LayoutParams.MATCH_PARENT,
            ScrollView.LayoutParams.WRAP_CONTENT
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

        restartNetwork();
        startUdpDiscovery();
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
            windowManager.addView(chatScroll, chatLp);
            windowManager.addView(fpsLabel, fpsLp);
            windowManager.addView(msgInput, inputLp);

            modalRoot = new FrameLayout(this);
            modalRoot.setBackgroundColor(Color.TRANSPARENT);
            modalRoot.setVisibility(View.GONE);
            modalRoot.setOnClickListener(v -> closeModal());

            modalCard = new LinearLayout(this);
            modalCard.setOrientation(LinearLayout.VERTICAL);
            modalCard.setBackgroundColor(Color.TRANSPARENT);
            int mPad = (int) (20 * density);
            modalCard.setPadding(mPad, mPad, mPad, (int) (18 * density));
            modalCard.setClickable(true);
            FrameLayout.LayoutParams cardLp = new FrameLayout.LayoutParams(
                (int) Math.min(340 * density, getResources().getDisplayMetrics().widthPixels - 40 * density),
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            );
            modalRoot.addView(modalCard, cardLp);

            modalLp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                    | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            );
            modalLp.token = token;
            windowManager.addView(modalRoot, modalLp);

            overlaysAttached = true;
            loadChatHistory();
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
            int px = (int) (15 * density);
            int py = (int) (10 * density);
            bubble.setPadding(px, py, px, py);

            GradientDrawable bg = new GradientDrawable();
            if (isSelf) {
                bg.setColor(Color.parseColor("#1970F5"));
                float r = 18 * density;
                float sm = 5 * density;
                bg.setCornerRadii(new float[]{r, r, r, r, sm, sm, r, r});
            } else {
                bg.setColor(Color.parseColor("#F5F8FC"));
                bg.setStroke((int) Math.max(1, density), Color.parseColor("#D8E0EC"));
                float r = 18 * density;
                float sm = 5 * density;
                bg.setCornerRadii(new float[]{r, r, r, r, r, r, sm, sm});
            }
            bubble.setBackground(bg);
            bubble.setElevation(3 * density);

            row.addView(bubble);
            chatContainer.addView(row, rowLp);
            chatScroll.post(() -> chatScroll.fullScroll(View.FOCUS_DOWN));
        });
    }

    private synchronized void stopNetwork() {
        wsConnected = false;
        wsOut = null;
        try { if (wsClientSocket != null) wsClientSocket.close(); } catch (Throwable ignored) {}
        wsClientSocket = null;
        try { if (hostServerSocket != null) hostServerSocket.close(); } catch (Throwable ignored) {}
        hostServerSocket = null;
        for (HostPeer p : hostPeers) {
            try { p.socket.close(); } catch (Throwable ignored) {}
        }
        hostPeers.clear();
        if (netThread != null) {
            netThread.interrupt();
            netThread = null;
        }
    }

    private synchronized void restartNetwork() {
        stopNetwork();
        if (!appRunning) return;
        if (MODE_HOST.equals(netMode)) {
            startHostServerLoop();
        } else {
            startClientLoop();
        }
    }

    private void startHostServerLoop() {
        lastNetError = "";
        netThread = new Thread(() -> {
            try {
                ServerSocket ss = new ServerSocket(LOCAL_PORT);
                hostServerSocket = ss;
                wsConnected = true;
                while (appRunning && MODE_HOST.equals(netMode) && !ss.isClosed()) {
                    Socket client = ss.accept();
                    new Thread(() -> handleHostPeer(client), "AgyHostPeer").start();
                }
            } catch (Throwable t) {
                lastNetError = t.getMessage() != null ? t.getMessage() : t.getClass().getSimpleName();
            } finally {
                wsConnected = false;
            }
        }, "AgyHostServer");
        netThread.start();
    }

    private void startUdpDiscovery() {
        // Listener: discover nearby Host phones on same WiFi/Hotspot
        discoveryThread = new Thread(() -> {
            try (DatagramSocket rx = new DatagramSocket(DISCOVERY_PORT)) {
                rx.setBroadcast(true);
                rx.setSoTimeout(1500);
                byte[] buf = new byte[256];
                while (appRunning) {
                    try {
                        DatagramPacket pkt = new DatagramPacket(buf, buf.length);
                        rx.receive(pkt);
                        String msg = new String(pkt.getData(), 0, pkt.getLength(), StandardCharsets.UTF_8);
                        if (msg.startsWith("AGY_HOST|")) {
                            String senderIp = pkt.getAddress().getHostAddress();
                            String myIp = getLocalIpv4();
                            if (senderIp != null && !senderIp.equals(myIp)) {
                                String[] parts = msg.split("\\|", 3);
                                String model = parts.length >= 3 ? parts[2] : "HP Host";
                                discoveredHosts.put(senderIp, model);
                            }
                        }
                    } catch (Throwable ignored) {
                    }
                }
            } catch (Throwable ignored) {
            }
        }, "AgyUdpRx");
        discoveryThread.start();

        // Beacon: broadcast presence every 1.2s when acting as Host
        new Thread(() -> {
            try (DatagramSocket tx = new DatagramSocket()) {
                tx.setBroadcast(true);
                byte[] msg = ("AGY_HOST|" + LOCAL_PORT + "|" + Build.MODEL).getBytes(StandardCharsets.UTF_8);
                while (appRunning) {
                    if (MODE_HOST.equals(netMode)) {
                        try {
                            tx.send(new DatagramPacket(msg, msg.length, InetAddress.getByName("255.255.255.255"), DISCOVERY_PORT));
                            for (NetworkInterface nif : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                                if (!nif.isUp() || nif.isLoopback()) continue;
                                for (InterfaceAddress ia : nif.getInterfaceAddresses()) {
                                    InetAddress bcast = ia.getBroadcast();
                                    if (bcast != null) {
                                        tx.send(new DatagramPacket(msg, msg.length, bcast, DISCOVERY_PORT));
                                    }
                                }
                            }
                        } catch (Throwable ignored) {
                        }
                    }
                    try { Thread.sleep(1200); } catch (InterruptedException ignored) {}
                }
            } catch (Throwable ignored) {
            }
        }, "AgyUdpTx").start();
    }

    private void handleHostPeer(Socket socket) {
        HostPeer peer = null;
        try {
            DataInputStream in = new DataInputStream(socket.getInputStream());
            OutputStream out = socket.getOutputStream();

            String secKey = null;
            String line;
            while ((line = readHttpLine(in)) != null && !line.isEmpty()) {
                if (line.toLowerCase(Locale.US).startsWith("sec-websocket-key:")) {
                    secKey = line.substring(line.indexOf(':') + 1).trim();
                }
            }
            if (secKey == null) {
                socket.close();
                return;
            }

            String accept = Base64.encodeToString(
                MessageDigest.getInstance("SHA-1").digest(
                    (secKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").getBytes(StandardCharsets.UTF_8)
                ),
                Base64.NO_WRAP
            );
            String resp = "HTTP/1.1 101 Switching Protocols\r\n"
                + "Upgrade: websocket\r\n"
                + "Connection: Upgrade\r\n"
                + "Sec-WebSocket-Accept: " + accept + "\r\n\r\n";
            out.write(resp.getBytes(StandardCharsets.US_ASCII));
            out.flush();

            peer = new HostPeer(socket, out);
            hostPeers.add(peer);

            // Send existing history to newly joined client
            JSONArray copy;
            synchronized (historyLock) {
                copy = new JSONArray(chatHistory.toString());
            }
            if (copy.length() > 0) {
                JSONObject hist = new JSONObject();
                hist.put("type", "history");
                hist.put("items", copy);
                writeRawFrame(out, 0x1, hist.toString().getBytes(StandardCharsets.UTF_8), false);
            }

            while (appRunning && MODE_HOST.equals(netMode) && !socket.isClosed()) {
                int b0 = in.readUnsignedByte();
                int b1 = in.readUnsignedByte();
                int opcode = b0 & 0x0F;
                boolean masked = (b1 & 0x80) != 0;
                long len = b1 & 0x7F;
                if (len == 126) len = in.readUnsignedShort();
                else if (len == 127) len = in.readLong();
                byte[] mask = new byte[4];
                if (masked) in.readFully(mask);
                if (len > 1024 * 1024) break;

                byte[] payload = new byte[(int) len];
                in.readFully(payload);
                if (masked) {
                    for (int i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4];
                }

                if (opcode == 0x8) break;
                else if (opcode == 0x9) writeRawFrame(out, 0xA, payload, false);
                else if (opcode == 0x1) {
                    String msg = new String(payload, StandardCharsets.UTF_8);
                    handleIncomingJson(msg);
                    broadcastFromHost(payload, peer);
                }
            }
        } catch (Throwable ignored) {
        } finally {
            if (peer != null) hostPeers.remove(peer);
            try { socket.close(); } catch (Throwable ignored) {}
        }
    }

    private void broadcastFromHost(byte[] payload, HostPeer exclude) {
        for (HostPeer p : hostPeers) {
            if (p == exclude) continue;
            try {
                writeRawFrame(p.out, 0x1, payload, false);
            } catch (Throwable ignored) {
            }
        }
    }

    private String sanitizeIp(String raw) {
        if (raw == null) return "";
        String s = raw.trim()
            .replace("ws://", "")
            .replace("wss://", "")
            .replace(",", ".")
            .replace(";", ":")
            .replace(" ", "");
        int slash = s.indexOf('/');
        if (slash >= 0) s = s.substring(0, slash);
        int colon = s.indexOf(':');
        if (colon >= 0) s = s.substring(0, colon);
        return s;
    }

    private void startClientLoop() {
        final String modeSnapshot = netMode;
        final String ipSnapshot = sanitizeIp(hostIp);
        lastNetError = "";
        netThread = new Thread(() -> {
            while (appRunning && modeSnapshot.equals(netMode)) {
                try {
                    Socket socket;
                    String hostHeader;
                    String path;
                    if (MODE_CLOUDFLARE.equals(modeSnapshot)) {
                        SSLSocketFactory factory = (SSLSocketFactory) SSLSocketFactory.getDefault();
                        SSLSocket ssl = (SSLSocket) factory.createSocket(RELAY_HOST, 443);
                        ssl.setSoTimeout(0);
                        ssl.startHandshake();
                        socket = ssl;
                        hostHeader = RELAY_HOST;
                        path = RELAY_PATH;
                    } else {
                        socket = new Socket();
                        socket.connect(new java.net.InetSocketAddress(ipSnapshot, LOCAL_PORT), 3500);
                        socket.setSoTimeout(0);
                        hostHeader = ipSnapshot + ":" + LOCAL_PORT;
                        path = "/";
                    }

                    byte[] keyBytes = new byte[16];
                    rng.nextBytes(keyBytes);
                    String wsKey = Base64.encodeToString(keyBytes, Base64.NO_WRAP);

                    OutputStream out = socket.getOutputStream();
                    String req = "GET " + path + " HTTP/1.1\r\n"
                        + "Host: " + hostHeader + "\r\n"
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
                    while ((line = readHttpLine(in)) != null && !line.isEmpty()) {}

                    wsSocketUpdate: {
                        wsClientSocket = socket;
                        wsOut = out;
                        wsConnected = true;
                        lastNetError = "";
                    }
                    if (MODE_CLOUDFLARE.equals(modeSnapshot)) {
                        recordUsage(1, 0, 0);
                    }

                    while (appRunning && modeSnapshot.equals(netMode)) {
                        int b0 = in.readUnsignedByte();
                        int b1 = in.readUnsignedByte();
                        int opcode = b0 & 0x0F;
                        boolean masked = (b1 & 0x80) != 0;
                        long len = b1 & 0x7F;
                        if (len == 126) len = in.readUnsignedShort();
                        else if (len == 127) len = in.readLong();
                        byte[] mask = new byte[4];
                        if (masked) in.readFully(mask);
                        if (len > 1024 * 1024) break;

                        byte[] payload = new byte[(int) len];
                        in.readFully(payload);
                        if (masked) {
                            for (int i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4];
                        }

                        if (opcode == 0x8) break;
                        else if (opcode == 0x9) sendWsFrame(0xA, payload);
                        else if (opcode == 0x1) {
                            handleIncomingJson(new String(payload, StandardCharsets.UTF_8));
                        }
                    }
                } catch (Throwable t) {
                    lastNetError = t.getMessage() != null ? t.getMessage() : t.getClass().getSimpleName();
                } finally {
                    wsConnected = false;
                    wsOut = null;
                    try { if (wsClientSocket != null) wsClientSocket.close(); } catch (Throwable ignored) {}
                    wsClientSocket = null;
                }
                if (appRunning && modeSnapshot.equals(netMode)) {
                    try { Thread.sleep(2500); } catch (InterruptedException ignored) {}
                }
            }
        }, "AgyWsClient");
        netThread.start();
    }

    private void handleIncomingJson(String msg) {
        try {
            JSONObject obj = new JSONObject(msg);
            String type = obj.optString("type");
            if ("chat".equals(type)) {
                String txt = obj.optString("text", "").trim();
                String sid = obj.optString("senderId", "");
                long ts = obj.optLong("ts", System.currentTimeMillis());
                boolean self = !sid.isEmpty() && deviceId.equals(sid);
                if (!txt.isEmpty()) {
                    if (MODE_CLOUDFLARE.equals(netMode)) recordUsage(0, 0, 1);
                    saveChatMessage(txt, self, sid, ts);
                    addChatBubble(txt, self);
                }
            } else if ("history".equals(type)) {
                JSONArray items = obj.optJSONArray("items");
                if (items != null) syncHistoryFromServer(items);
            } else if ("clear_history".equals(type)) {
                clearLocalHistory();
            }
        } catch (Throwable ignored) {
        }
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

    private void writeRawFrame(OutputStream o, int opcode, byte[] payload, boolean maskFrame) throws Exception {
        ByteArrayOutputStream frame = new ByteArrayOutputStream();
        frame.write(0x80 | (opcode & 0x0F));
        int len = payload.length;
        int maskBit = maskFrame ? 0x80 : 0x00;
        if (len <= 125) {
            frame.write(maskBit | len);
        } else if (len <= 65535) {
            frame.write(maskBit | 126);
            frame.write((len >> 8) & 0xFF);
            frame.write(len & 0xFF);
        } else {
            frame.write(maskBit | 127);
            for (int i = 7; i >= 0; i--) {
                frame.write((int) (((long) len >> (i * 8)) & 0xFF));
            }
        }
        if (maskFrame) {
            byte[] mask = new byte[4];
            rng.nextBytes(mask);
            frame.write(mask);
            for (int i = 0; i < len; i++) frame.write(payload[i] ^ mask[i % 4]);
        } else {
            frame.write(payload);
        }
        synchronized (o) {
            o.write(frame.toByteArray());
            o.flush();
        }
    }

    private void sendWsFrame(int opcode, byte[] payload) {
        if (MODE_HOST.equals(netMode)) {
            wsSendExecutor.execute(() -> broadcastFromHost(payload, null));
            return;
        }
        if (wsOut == null) return;
        wsSendExecutor.execute(() -> {
            try {
                OutputStream o = wsOut;
                if (o != null) writeRawFrame(o, opcode, payload, true);
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

            if (chatScroll != null && chatLp != null && targetY > 0) {
                int chatTop = (int) (70 * density);
                int chatH = Math.max((int) (40 * density), targetY - chatTop - (int) (10 * density));
                if (Math.abs(chatH - lastChatHeight) > 2) {
                    lastChatHeight = chatH;
                    chatLp.y = chatTop;
                    chatLp.height = chatH;
                    try {
                        windowManager.updateViewLayout(chatScroll, chatLp);
                    } catch (Throwable ignored) {
                    }
                    if (chatScroll.getVisibility() != View.VISIBLE) {
                        chatScroll.setVisibility(View.VISIBLE);
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
                long nowTs = System.currentTimeMillis();
                if (MODE_CLOUDFLARE.equals(netMode)) recordUsage(0, 1, 0);
                saveChatMessage(text, true, deviceId, nowTs);
                addChatBubble(text, true);
                try {
                    JSONObject obj = new JSONObject();
                    obj.put("type", "chat");
                    obj.put("text", text);
                    obj.put("senderId", deviceId);
                    obj.put("ts", nowTs);
                    sendWsFrame(0x1, obj.toString().getBytes(StandardCharsets.UTF_8));
                } catch (Throwable ignored) {
                }
            }
        });
    }

    private SharedPreferences getUsagePrefs() {
        SharedPreferences prefs = getSharedPreferences("cf_usage", Context.MODE_PRIVATE);
        String today = new SimpleDateFormat("yyyy-MM-dd", Locale.US).format(new Date());
        if (!today.equals(prefs.getString("date", ""))) {
            prefs.edit()
                .putString("date", today)
                .putInt("connects", 0)
                .putInt("sent", 0)
                .putInt("recv", 0)
                .apply();
        }
        return prefs;
    }

    private synchronized void recordUsage(int connects, int sent, int recv) {
        try {
            SharedPreferences prefs = getUsagePrefs();
            prefs.edit()
                .putInt("connects", prefs.getInt("connects", 0) + connects)
                .putInt("sent", prefs.getInt("sent", 0) + sent)
                .putInt("recv", prefs.getInt("recv", 0) + recv)
                .apply();
        } catch (Throwable ignored) {
        }
    }

    private String getOrCreateDeviceId() {
        SharedPreferences prefs = getSharedPreferences("cf_usage", Context.MODE_PRIVATE);
        String id = prefs.getString("device_id", "");
        if (id == null || id.isEmpty()) {
            id = UUID.randomUUID().toString();
            prefs.edit().putString("device_id", id).apply();
        }
        return id;
    }

    private String getLocalIpv4() {
        try {
            for (NetworkInterface nif : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!nif.isUp() || nif.isLoopback()) continue;
                for (InetAddress addr : Collections.list(nif.getInetAddresses())) {
                    if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) {
                        String ip = addr.getHostAddress();
                        if (ip != null && !ip.startsWith("127.")) return ip;
                    }
                }
            }
        } catch (Throwable ignored) {
        }
        return "Tidak terdeteksi";
    }

    private void syncHistoryFromServer(final JSONArray serverItems) {
        executor.execute(() -> {
            synchronized (historyLock) {
                try {
                    JSONArray normalized = new JSONArray();
                    for (int i = 0; i < serverItems.length(); i++) {
                        JSONObject s = serverItems.optJSONObject(i);
                        if (s == null) continue;
                        String txt = s.optString("text", "").trim();
                        if (txt.isEmpty()) continue;
                        String sid = s.optString("senderId", "");
                        long ts = s.optLong("ts", 0);
                        boolean self = !sid.isEmpty() && deviceId.equals(sid);
                        JSONObject item = new JSONObject();
                        item.put("text", txt);
                        item.put("self", self);
                        item.put("senderId", sid);
                        item.put("ts", ts);
                        normalized.put(item);
                    }
                    chatHistory = normalized;
                    File f = new File(getFilesDir(), "chat_history.json");
                    try (FileOutputStream fos = new FileOutputStream(f)) {
                        fos.write(chatHistory.toString().getBytes(StandardCharsets.UTF_8));
                    }
                    uiHandler.post(() -> {
                        if (chatContainer != null) chatContainer.removeAllViews();
                        for (int i = 0; i < normalized.length(); i++) {
                            JSONObject item = normalized.optJSONObject(i);
                            if (item != null) {
                                addChatBubble(item.optString("text", ""), item.optBoolean("self", false));
                            }
                        }
                    });
                } catch (Throwable ignored) {
                }
            }
        });
    }

    private void clearLocalHistory() {
        synchronized (historyLock) {
            chatHistory = new JSONArray();
            File f = new File(getFilesDir(), "chat_history.json");
            if (f.exists()) f.delete();
        }
        uiHandler.post(() -> {
            if (chatContainer != null) chatContainer.removeAllViews();
        });
    }

    private void loadChatHistory() {
        executor.execute(() -> {
            try {
                File f = new File(getFilesDir(), "chat_history.json");
                if (!f.exists()) return;
                byte[] data = new byte[(int) f.length()];
                try (FileInputStream fis = new FileInputStream(f)) {
                    int read = 0;
                    while (read < data.length) {
                        int n = fis.read(data, read, data.length - read);
                        if (n <= 0) break;
                        read += n;
                    }
                }
                JSONArray arr = new JSONArray(new String(data, StandardCharsets.UTF_8));
                synchronized (historyLock) {
                    chatHistory = arr;
                }
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject item = arr.optJSONObject(i);
                    if (item != null) {
                        String txt = item.optString("text", "");
                        boolean self = item.optBoolean("self", false);
                        if (!txt.isEmpty()) addChatBubble(txt, self);
                    }
                }
            } catch (Throwable ignored) {
            }
        });
    }

    private void saveChatMessage(final String text, final boolean isSelf, final String senderId, final long ts) {
        executor.execute(() -> {
            synchronized (historyLock) {
                try {
                    JSONObject item = new JSONObject();
                    item.put("text", text);
                    item.put("self", isSelf);
                    item.put("senderId", senderId);
                    item.put("ts", ts);
                    chatHistory.put(item);
                    while (chatHistory.length() > 500) {
                        chatHistory.remove(0);
                    }
                    File f = new File(getFilesDir(), "chat_history.json");
                    try (FileOutputStream fos = new FileOutputStream(f)) {
                        fos.write(chatHistory.toString().getBytes(StandardCharsets.UTF_8));
                    }
                } catch (Throwable ignored) {
                }
            }
        });
    }

    private void closeModal() {
        nativeSetModalOpen(false);
        if (modalRoot != null) {
            modalRoot.animate().alpha(0.0f).setDuration(90).withEndAction(() -> {
                if (modalRoot != null) modalRoot.setVisibility(View.GONE);
            }).start();
        }
        if (chatScroll != null) {
            chatScroll.animate().alpha(1.0f).setDuration(140).start();
        }
    }

    private Button makeModalBtn(String label, int bgColor, int textColor) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        b.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        b.setTextColor(textColor);
        GradientDrawable d = new GradientDrawable();
        d.setColor(bgColor);
        d.setCornerRadius(14 * density);
        b.setBackground(d);
        b.setStateListAnimator(null);
        int py = (int) (9 * density);
        b.setPadding((int) (10 * density), py, (int) (10 * density), py);
        return b;
    }

    public void showUsageDialog() {
        uiHandler.post(() -> {
            try {
                if (modalRoot == null || modalCard == null) return;
                modalCard.removeAllViews();

                String myIp = getLocalIpv4();
                String modeLabel = MODE_HOST.equals(netMode)
                    ? "Host Lokal (Port " + LOCAL_PORT + ", " + hostPeers.size() + " client)"
                    : MODE_CLIENT.equals(netMode)
                        ? "Client Lokal (" + hostIp + ":" + LOCAL_PORT + ")"
                        : "Cloudflare Relay";
                String status = wsConnected
                    ? "Terhubung"
                    : ("Menyambung..." + (lastNetError.isEmpty() ? "" : " (" + lastNetError + ")"));

                TextView title = new TextView(this);
                title.setText("Koneksi Lokal & Chat");
                title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 17);
                title.setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD));
                title.setTextColor(Color.parseColor("#111622"));
                modalCard.addView(title);

                TextView tv = new TextView(this);
                tv.setText("Mode: " + modeLabel + "\nStatus: " + status + "\nIP HP ini: " + myIp);
                tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
                tv.setTextColor(Color.parseColor("#5B677A"));
                LinearLayout.LayoutParams tvLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                );
                tvLp.topMargin = (int) (6 * density);
                tvLp.bottomMargin = (int) (12 * density);
                modalCard.addView(tv, tvLp);

                if (!discoveredHosts.isEmpty()) {
                    for (Map.Entry<String, String> entry : discoveredHosts.entrySet()) {
                        final String foundIp = entry.getKey();
                        final String model = entry.getValue();
                        Button btn = makeModalBtn(
                            "Gabung " + model + " (" + foundIp + ")",
                            Color.parseColor("#E3EEFF"),
                            Color.parseColor("#145BD4")
                        );
                        LinearLayout.LayoutParams bLp = new LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                        );
                        bLp.bottomMargin = (int) (8 * density);
                        btn.setOnClickListener(v -> {
                            hostIp = foundIp;
                            netMode = MODE_CLIENT;
                            getSharedPreferences("cf_usage", Context.MODE_PRIVATE)
                                .edit()
                                .putString("net_mode", netMode)
                                .putString("host_ip", hostIp)
                                .apply();
                            restartNetwork();
                            closeModal();
                            Toast.makeText(this, "Menyambung ke " + model, Toast.LENGTH_SHORT).show();
                        });
                        modalCard.addView(btn, bLp);
                    }
                }

                final EditText ipInput = new EditText(this);
                ipInput.setHint("IP Host (misal 192.168.1.5)");
                ipInput.setText(hostIp);
                ipInput.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
                ipInput.setTextColor(Color.parseColor("#111622"));
                ipInput.setHintTextColor(Color.parseColor("#768296"));
                ipInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
                GradientDrawable inpBg = new GradientDrawable();
                inpBg.setColor(Color.argb(150, 255, 255, 255));
                inpBg.setStroke((int) Math.max(1, density), Color.argb(64, 118, 130, 150));
                inpBg.setCornerRadius(14 * density);
                ipInput.setBackground(inpBg);
                int iPad = (int) (12 * density);
                ipInput.setPadding(iPad, (int) (10 * density), iPad, (int) (10 * density));
                LinearLayout.LayoutParams inpLp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                );
                inpLp.bottomMargin = (int) (12 * density);
                modalCard.addView(ipInput, inpLp);

                LinearLayout row = new LinearLayout(this);
                row.setOrientation(LinearLayout.HORIZONTAL);

                Button btnClear = makeModalBtn("Hapus", Color.argb(26, 200, 30, 30), Color.parseColor("#C81E1E"));
                btnClear.setOnClickListener(v -> {
                    clearLocalHistory();
                    try {
                        JSONObject clr = new JSONObject();
                        clr.put("type", "clear_history");
                        sendWsFrame(0x1, clr.toString().getBytes(StandardCharsets.UTF_8));
                    } catch (Throwable ignored) {}
                    closeModal();
                    Toast.makeText(this, "Riwayat chat dihapus", Toast.LENGTH_SHORT).show();
                });

                Button btnJoin = makeModalBtn("Gabung", Color.argb(18, 20, 25, 35), Color.parseColor("#141923"));
                btnJoin.setOnClickListener(v -> {
                    String ip = sanitizeIp(ipInput.getText().toString());
                    if (!ip.isEmpty()) {
                        hostIp = ip;
                        netMode = MODE_CLIENT;
                        getSharedPreferences("cf_usage", Context.MODE_PRIVATE)
                            .edit()
                            .putString("net_mode", netMode)
                            .putString("host_ip", hostIp)
                            .apply();
                        restartNetwork();
                        closeModal();
                        Toast.makeText(this, "Menyambung ke " + hostIp, Toast.LENGTH_SHORT).show();
                    }
                });

                Button btnHost = makeModalBtn("Jadi Host", Color.parseColor("#1970F5"), Color.WHITE);
                btnHost.setOnClickListener(v -> {
                    netMode = MODE_HOST;
                    getSharedPreferences("cf_usage", Context.MODE_PRIVATE)
                        .edit().putString("net_mode", netMode).apply();
                    restartNetwork();
                    closeModal();
                    Toast.makeText(this, "Host aktif di " + myIp, Toast.LENGTH_LONG).show();
                });

                LinearLayout.LayoutParams p1 = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
                p1.rightMargin = (int) (6 * density);
                LinearLayout.LayoutParams p2 = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
                p2.rightMargin = (int) (6 * density);
                LinearLayout.LayoutParams p3 = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
                row.addView(btnClear, p1);
                row.addView(btnJoin, p2);
                row.addView(btnHost, p3);
                modalCard.addView(row);

                if (chatScroll != null) {
                    chatScroll.animate().alpha(0.0f).setDuration(80).start();
                }
                modalRoot.setAlpha(0.0f);
                modalCard.setScaleX(0.94f);
                modalCard.setScaleY(0.94f);
                modalRoot.setVisibility(View.VISIBLE);
                modalCard.post(() -> {
                    int[] loc = new int[2];
                    modalCard.getLocationOnScreen(loc);
                    float hw = modalCard.getWidth() * 0.5f;
                    float hh = modalCard.getHeight() * 0.5f;
                    nativeSetModalBounds(loc[0] + hw, loc[1] + hh, hw, hh);
                    nativeSetModalOpen(true);
                    modalRoot.animate().alpha(1.0f).setDuration(100).start();
                    modalCard.animate().scaleX(1.0f).scaleY(1.0f).setDuration(110).start();
                });
            } catch (Throwable ignored) {
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
        appRunning = false;
        stopNetwork();
        if (overlaysAttached && windowManager != null) {
            try { windowManager.removeViewImmediate(modalRoot); } catch (Throwable ignored) {}
            try { windowManager.removeViewImmediate(chatScroll); } catch (Throwable ignored) {}
            try { windowManager.removeViewImmediate(fpsLabel); } catch (Throwable ignored) {}
            try { windowManager.removeViewImmediate(msgInput); } catch (Throwable ignored) {}
            overlaysAttached = false;
        }
        executor.shutdownNow();
        wsSendExecutor.shutdownNow();
        super.onDestroy();
    }
}
