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
      'wss://aw5mcmfzdhj1y3r1cmvfy2fjagu.sudaapip.workers.dev';
}

class FlutterNativeApp extends StatelessWidget {
  const FlutterNativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity HT',
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

  bool _localPressed = false;
  bool _remotePressed = false;
  bool _micGranted = false;
  int? _activePointer;
  StreamSubscription<dynamic>? _micSub;

  WebSocket? _socket;
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusText = 'Menyiapkan koneksi...';

  final TextEditingController _roomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _checkOrRequestMic();

    _micSub = _audioStreamChannel.receiveBroadcastStream().listen((event) {
      if (!_localPressed || !_isConnected || _socket == null) return;
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
    _audioChannel.invokeMethod('stopCapture').catchError((_) {});
    _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    _audioChannel.invokeMethod('stopKeepAlive').catchError((_) {});
    _disconnectSocket(manual: true);
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _connectRelay({bool isRetry = false}) async {
    final room = _roomController.text.trim().isEmpty
        ? '1234'
        : _roomController.text.trim();
    if (_roomController.text.trim().isEmpty) {
      _roomController.text = room;
    }

    // Simpan room terakhir
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
      final ws =
          await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 8));
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

      // Aktifkan Foreground Service agar tetap jalan saat layar mati
      _audioChannel.invokeMethod('startKeepAlive', room).catchError((_) {});

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _statusText = 'Terhubung Room $room (Siap 2 arah)';
      });

      ws.listen(
        (data) {
          if (data is String) {
            try {
              final map = jsonDecode(data) as Map<String, dynamic>;
              if (!map.containsKey('pressed')) return;
              final pressed = map['pressed'] == true;
              if (mounted && _remotePressed != pressed) {
                setState(() => _remotePressed = pressed);
              }
              if (pressed && !_localPressed) {
                _audioChannel.invokeMethod('startPlayback').catchError((_) {});
              } else if (!pressed) {
                _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
              }
            } catch (_) {}
          } else if (data is List<int>) {
            // Hindari echo jika kita sendiri sedang menekan tombol bicara
            if (_localPressed) return;
            final bytes = data is Uint8List ? data : Uint8List.fromList(data);
            _audioChannel
                .invokeMethod('writePlayback', bytes)
                .catchError((_) {});
          }
        },
        onDone: () => _handleDrop(
          'Terputus (code ${ws.closeCode ?? "-"}), menyambung ulang...',
        ),
        onError: (_) => _handleDrop('Koneksi error, menyambung ulang...'),
      );
    } catch (_) {
      _handleDrop('Gagal konek, mencoba ulang...');
    }
  }

  void _handleDrop(String msg) {
    _keepaliveTimer?.cancel();
    _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _remotePressed = false;
      _statusText = _manualDisconnect ? 'Terputus' : msg;
    });
    if (!_manualDisconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_manualDisconnect) {
          _connectRelay(isRetry: true);
        }
      });
    }
  }

  Future<void> _closeSocketOnly() async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    await _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    await _socket?.close().catchError((_) {});
    _socket = null;
  }

  Future<void> _disconnectSocket({bool manual = true}) async {
    _manualDisconnect = manual;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocketOnly();
    if (manual) {
      _audioChannel.invokeMethod('stopKeepAlive').catchError((_) {});
    }
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _remotePressed = false;
        if (manual) {
          _statusText = 'Terputus';
        }
      });
    }
  }

  Future<void> _setPressed(bool pressed) async {
    if (pressed && !_micGranted) {
      final ok = await _checkOrRequestMic();
      if (!ok) return;
    }
    if (_localPressed != pressed) {
      setState(() => _localPressed = pressed);
      if (_isConnected && _socket != null) {
        try {
          _socket!.add(jsonEncode({'pressed': pressed}));
        } catch (_) {}
      }
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildConnectionBar(),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBar() {
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
                child: SizedBox(
                  height: 38,
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
                height: 38,
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
                child: Text(
                  _statusText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTokens.inkMuted,
                  ),
                ),
              ),
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
