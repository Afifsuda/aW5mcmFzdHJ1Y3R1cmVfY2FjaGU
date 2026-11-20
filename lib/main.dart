import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTokens.bgScaffold,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const FlutterNativeApp());
}

abstract final class AppTokens {
  static const Color bgScaffold = Color(0xFFF7F7F5);
  static const Color bgPrimaryBtn = Color(0xFF181816);
  static const Color bgPrimaryPressed = Color(0xFFE54826);
  static const Color bgSecondaryIdle = Color(0xFFECECE8);
  static const Color bgSecondaryActive = Color(0xFF181816);

  static const Color inkLight = Color(0xFFFFFFFF);
  static const Color inkDark = Color(0xFF181816);
  static const Color inkMuted = Color(0xFF787872);
  static const Color borderSubtle = Color.fromRGBO(20, 20, 19, 0.08);

  static const BoxShadow shadowPrimary = BoxShadow(
    color: Color.fromRGBO(24, 24, 22, 0.16),
    offset: Offset(0, 12),
    blurRadius: 28,
  );

  static const BoxShadow shadowPrimaryPressed = BoxShadow(
    color: Color.fromRGBO(229, 72, 38, 0.32),
    offset: Offset(0, 6),
    blurRadius: 20,
  );

  static const BoxShadow shadowSecondaryActive = BoxShadow(
    color: Color.fromRGBO(24, 24, 22, 0.14),
    offset: Offset(0, 6),
    blurRadius: 16,
  );

  static const Curve easeCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const String relayBaseWsUrl =
      'wss://aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev';
}

class FlutterNativeApp extends StatelessWidget {
  const FlutterNativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity HT & Musik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTokens.bgScaffold,
        useMaterial3: true,
      ),
      home: const VoiceNodeScreen(),
    );
  }
}

enum AppMode { voice, music }

class VoiceNodeScreen extends StatefulWidget {
  const VoiceNodeScreen({super.key});

  @override
  State<VoiceNodeScreen> createState() => _VoiceNodeScreenState();
}

class _VoiceNodeScreenState extends State<VoiceNodeScreen> {
  static const MethodChannel _audioChannel =
      MethodChannel('com.afifsuda.canvas/audio');
  static const EventChannel _audioStreamChannel =
      EventChannel('com.afifsuda.canvas/audio_stream');

  AppMode _mode = AppMode.voice;

  // HT Suara state
  bool _localPressed = false;
  bool _remotePressed = false;
  bool _micGranted = false;
  int? _activePointer;
  StreamSubscription<dynamic>? _micSub;

  // WebSocket state (HT Suara + WebRTC Signaling)
  WebSocket? _socket;
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusText = 'Menyiapkan koneksi...';
  final TextEditingController _roomController = TextEditingController();

  // Stream Musik (Internal Audio Capture) state
  bool _isMusicStreaming = false;
  bool _musicBusy = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _checkOrRequestMic();

    _micSub = _audioStreamChannel.receiveBroadcastStream().listen((event) {
      final canSendVoice = _mode == AppMode.voice && _localPressed;
      final canSendMusic = _mode == AppMode.music && _isMusicStreaming;
      if ((!canSendVoice && !canSendMusic) || !_isConnected || _socket == null) {
        return;
      }
      if (event is Uint8List && event.isNotEmpty) {
        try {
          _socket!.add(event);
        } catch (_) {}
      }
    });

    try {
      final savedRoom =
          await _audioChannel.invokeMethod<String>('getSavedRoom') ?? '1234';
      if (mounted) {
        _roomController.text = savedRoom;
      }
    } catch (_) {
      if (mounted) _roomController.text = '1234';
    }

    await _connectRelay();
  }

  Future<bool> _checkOrRequestMic() async {
    try {
      bool granted =
          await _audioChannel.invokeMethod<bool>('hasMicPermission') ?? false;
      if (!granted) {
        granted =
            await _audioChannel.invokeMethod<bool>('requestMicPermission') ??
                false;
      }
      if (mounted) setState(() => _micGranted = granted);
      return granted;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _micSub?.cancel();
    _keepaliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _audioChannel.invokeMethod('stopMusicCapture').catchError((_) {});
    _audioChannel.invokeMethod('stopCapture').catchError((_) {});
    _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    _audioChannel.invokeMethod('stopKeepAlive').catchError((_) {});
    _disconnectSocket(manual: true);
    _roomController.dispose();
    super.dispose();
  }

  void _sendJson(Map<String, dynamic> data) {
    if (_isConnected && _socket != null) {
      try {
        _socket!.add(jsonEncode(data));
      } catch (_) {}
    }
  }

  Future<InternetAddress> _resolveIpv4ViaDoh(String host) async {
    final endpoints = [
      'https://1.1.1.1/dns-query?name=${Uri.encodeComponent(host)}&type=A',
      'https://8.8.8.8/resolve?name=${Uri.encodeComponent(host)}&type=A',
    ];
    for (final url in endpoints) {
      try {
        final dohClient = HttpClient()
          ..connectionTimeout = const Duration(seconds: 4);
        final req = await dohClient.getUrl(Uri.parse(url));
        req.headers.set('accept', 'application/dns-json');
        final res = await req.close().timeout(const Duration(seconds: 4));
        final body = await res.transform(utf8.decoder).join();
        dohClient.close(force: true);
        final json = jsonDecode(body) as Map<String, dynamic>;
        final answers = json['Answer'] as List<dynamic>?;
        if (answers != null) {
          for (final ans in answers) {
            if (ans is Map && ans['type'] == 1 && ans['data'] is String) {
              final ip = InternetAddress.tryParse(ans['data'] as String);
              if (ip != null && ip.type == InternetAddressType.IPv4) {
                return ip;
              }
            }
          }
        }
      } catch (_) {}
    }
    final addrs = await InternetAddress.lookup(
      host,
      type: InternetAddressType.IPv4,
    );
    return addrs.first;
  }

  Future<void> _connectRelay({bool isRetry = false}) async {
    final room = _roomController.text.trim().isEmpty
        ? '1234'
        : _roomController.text.trim();
    if (_roomController.text.trim().isEmpty) {
      _roomController.text = room;
    }

    _audioChannel.invokeMethod('saveRoom', room).catchError((_) {});
    final wsUrl =
        '${AppTokens.relayBaseWsUrl}?room=${Uri.encodeComponent(room)}';

    if (!isRetry) {
      _manualDisconnect = false;
      _reconnectTimer?.cancel();
    }
    await _closeSocketOnly();
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
      _statusText = isRetry
          ? 'Menyambung ulang ke Room $room...'
          : 'Menghubungkan ke Room $room...';
    });

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      client.connectionFactory =
          (Uri uri, String? proxyHost, int? proxyPort) async {
        final port = (uri.hasPort && uri.port != 0)
            ? uri.port
            : ((uri.scheme == 'https' || uri.scheme == 'wss') ? 443 : 80);
        final ip = await _resolveIpv4ViaDoh(uri.host);
        if (uri.scheme == 'https' || uri.scheme == 'wss') {
          final task = await Socket.startConnect(ip, port);
          return ConnectionTask.fromSocket(
            task.socket.then(
              (raw) => SecureSocket.secure(
                raw,
                host: uri.host,
                supportedProtocols: const ['http/1.1'],
              ),
            ),
            task.cancel,
          );
        }
        return Socket.startConnect(ip, port);
      };

      final ws = await WebSocket.connect(wsUrl, customClient: client)
          .timeout(const Duration(seconds: 8));
      if (!mounted) {
        await ws.close();
        return;
      }
      _socket = ws;
      _keepaliveTimer?.cancel();
      _keepaliveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_isConnected && ws.readyState == WebSocket.open) {
          try {
            ws.add('{"ping":1}');
          } catch (_) {}
        }
      });

      _audioChannel.invokeMethod('startKeepAlive', room).catchError((_) {});

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _statusText = 'Terhubung Room $room';
      });

      ws.listen(
        (data) {
          if (data is String) {
            _handleIncomingText(data);
          } else if (data is List<int>) {
            if (_localPressed || _isMusicStreaming) return;
            final bytes = data is Uint8List ? data : Uint8List.fromList(data);
            _audioChannel
                .invokeMethod('writePlayback', bytes)
                .catchError((_) {});
          }
        },
        onDone: () => _handleDrop(
          'Terputus (code ${ws.closeCode ?? "-"}), menyambung ulang...',
        ),
        onError: (err) => _handleDrop('Error: $err'),
      );
    } catch (e) {
      _handleDrop('Gagal konek: $e');
    }
  }

  void _handleIncomingText(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map.containsKey('pressed')) {
        final pressed = map['pressed'] == true;
        if (mounted && _remotePressed != pressed) {
          setState(() => _remotePressed = pressed);
        }
        if (pressed && !_localPressed && !_isMusicStreaming) {
          _audioChannel.invokeMethod('startPlayback').catchError((_) {});
        } else if (!pressed) {
          _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
        }
      }
    } catch (_) {}
  }

  // ==========================================================
  Future<void> _toggleMusicStream() async {
    if (_musicBusy) return;
    if (_isMusicStreaming) {
      await _stopMusicStream();
      return;
    }
    if (!_micGranted) {
      final ok = await _checkOrRequestMic();
      if (!ok) return;
    }
    setState(() => _musicBusy = true);
    try {
      await _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
      final started =
          await _audioChannel.invokeMethod<bool>('startMusicCapture') ?? false;
      if (started && mounted) {
        setState(() => _isMusicStreaming = true);
        _sendJson({'pressed': true});
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _musicBusy = false);
    }
  }

  Future<void> _stopMusicStream() async {
    await _audioChannel.invokeMethod('stopMusicCapture').catchError((_) {});
    if (mounted) {
      setState(() => _isMusicStreaming = false);
    }
    _sendJson({'pressed': false});
  }

  Future<void> _switchMode(AppMode next) async {
    if (_mode == next) return;
    if (_localPressed) {
      await _setPressed(false);
    }
    if (_isMusicStreaming) {
      await _stopMusicStream();
    }
    setState(() => _mode = next);
  }

  Future<void> _setPressed(bool pressed) async {
    if (_mode != AppMode.voice) return;
    if (pressed && !_micGranted) {
      final ok = await _checkOrRequestMic();
      if (!ok) return;
    }
    if (_localPressed != pressed) {
      setState(() => _localPressed = pressed);
      _sendJson({'pressed': pressed});
      if (pressed) {
        await _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
        await _audioChannel.invokeMethod('startCapture').catchError((_) {});
      } else {
        await _audioChannel.invokeMethod('stopCapture').catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool receiverActive = _remotePressed || _localPressed;

    return Scaffold(
      backgroundColor: AppTokens.bgScaffold,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTopBar(),
                  if (_mode == AppMode.voice) ...[
                    _SecondaryReceiverNode(
                      isActive: receiverActive,
                      label: _remotePressed ? 'Mendengar' : 'Penerima',
                    ),
                    _PrimarySenderNode(
                      isActive: _localPressed,
                      onPointerDown: (event) {
                        _activePointer = event.pointer;
                        _setPressed(true);
                      },
                      onPointerUp: (event) {
                        if (_activePointer == event.pointer) {
                          _activePointer = null;
                          _setPressed(false);
                        }
                      },
                      onPointerCancel: (event) {
                        if (_activePointer == event.pointer) {
                          _activePointer = null;
                          _setPressed(false);
                        }
                      },
                    ),
                  ] else
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildMusicArea(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.bgSecondaryIdle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'HT Suara',
                  selected: _mode == AppMode.voice,
                  onTap: () => _switchMode(AppMode.voice),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Stream Musik',
                  selected: _mode == AppMode.music,
                  onTap: () => _switchMode(AppMode.music),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _roomController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixText: 'Room: ',
                      prefixStyle: const TextStyle(
                        fontSize: 12,
                        color: AppTokens.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      hintText: '1234',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: AppTokens.inkLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _isConnecting
                      ? null
                      : (_isConnected
                          ? () => _disconnectSocket(manual: true)
                          : () => _connectRelay()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConnected
                        ? AppTokens.bgPrimaryPressed
                        : AppTokens.bgPrimaryBtn,
                    foregroundColor: AppTokens.inkLight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isConnecting
                        ? '...'
                        : (_isConnected ? 'Putus' : 'Sambung'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _statusText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status/Error lengkap disalin!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: _statusText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status/Error lengkap disalin!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    _statusText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTokens.inkMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Mic: ${_micGranted ? "Aktif" : "Belum"}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTokens.inkDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMusicArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTokens.bgSecondaryIdle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isMusicStreaming ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
            size: 56,
            color: _isMusicStreaming
                ? AppTokens.bgPrimaryPressed
                : AppTokens.inkDark,
          ),
          const SizedBox(height: 16),
          Text(
            _isMusicStreaming
                ? 'Sedang Streaming Audio Internal'
                : 'Stream Musik Jarak Jauh',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTokens.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isMusicStreaming
                ? 'Suara dari pemutar musik / YouTube di HP ini sedang dikirim ke room.'
                : 'Putar musik di HP ini lalu tekan tombol di bawah untuk mengirim suaranya ke HP lain di room yang sama.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTokens.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _musicBusy ? null : _toggleMusicStream,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMusicStreaming
                    ? AppTokens.bgPrimaryPressed
                    : AppTokens.bgPrimaryBtn,
                foregroundColor: AppTokens.inkLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                _isMusicStreaming ? Icons.stop_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                _musicBusy
                    ? 'Meminta izin...'
                    : (_isMusicStreaming ? 'Stop Stream Musik' : 'Mulai Stream Musik'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppTokens.bgPrimaryBtn : AppTokens.inkLight,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppTokens.inkLight : AppTokens.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _VideoCtrlBtn extends StatelessWidget {
  const _VideoCtrlBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? AppTokens.bgPrimaryPressed
        : (active ? AppTokens.bgPrimaryBtn : AppTokens.bgSecondaryIdle);
    final fg = (danger || active) ? AppTokens.inkLight : AppTokens.inkDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: AppTokens.borderSubtle),
        ),
        child: Icon(icon, color: fg, size: 24),
      ),
    );
  }
}

class _SecondaryReceiverNode extends StatelessWidget {
  const _SecondaryReceiverNode({
    required this.isActive,
    required this.label,
  });

  final bool isActive;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedScale(
        scale: isActive ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: AppTokens.easeCurve,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: AppTokens.easeCurve,
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppTokens.bgSecondaryActive
                : AppTokens.bgSecondaryIdle,
            border: Border.all(
              color: isActive ? Colors.transparent : AppTokens.borderSubtle,
              width: 1,
            ),
            boxShadow: isActive ? const [AppTokens.shadowSecondaryActive] : [],
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 160),
            curve: AppTokens.easeCurve,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? AppTokens.inkLight : AppTokens.inkMuted,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _PrimarySenderNode extends StatelessWidget {
  const _PrimarySenderNode({
    required this.isActive,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final bool isActive;
  final PointerDownEventListener onPointerDown;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: onPointerDown,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerCancel,
        child: AnimatedScale(
          scale: isActive ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: AppTokens.easeCurve,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: AppTokens.easeCurve,
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTokens.bgPrimaryPressed
                  : AppTokens.bgPrimaryBtn,
              boxShadow: [
                isActive
                    ? AppTokens.shadowPrimaryPressed
                    : AppTokens.shadowPrimary,
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              isActive ? 'Bicara...' : 'Tahan Bicara',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.16,
                color: AppTokens.inkLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
