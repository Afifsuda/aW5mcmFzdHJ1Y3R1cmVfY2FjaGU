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
  static const int wsPort = 8765;
}

class FlutterNativeApp extends StatelessWidget {
  const FlutterNativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Native UI Base',
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

enum NodeRole { sender, receiver }

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
  static const MethodChannel _tunnelChannel =
      MethodChannel('com.afifsuda.canvas/tunnel');
  static const EventChannel _tunnelEventChannel =
      EventChannel('com.afifsuda.canvas/tunnel_events');

  NodeRole _role = NodeRole.sender;
  bool _localPressed = false;
  bool _remotePressed = false;
  bool _micGranted = false;
  int? _activePointer;
  StreamSubscription<dynamic>? _micSub;
  StreamSubscription<dynamic>? _tunnelSub;

  // Host (Pengirim) state — murni 127.0.0.1 untuk Tunnel Publik
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  String _tunnelStatus = 'stopped';
  String? _tunnelUrl;
  String _tunnelMessage = 'Tunnel nonaktif';

  // Client (Penerima) state
  WebSocket? _clientSocket;
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _clientStatus = 'Tempel Link Tunnel dari HP 1';
  final TextEditingController _targetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _checkOrRequestMic();

    _micSub = _audioStreamChannel.receiveBroadcastStream().listen((event) {
      if (!_localPressed || _role != NodeRole.sender) return;
      if (event is Uint8List && event.isNotEmpty) {
        for (final c in List<WebSocket>.from(_clients)) {
          try {
            c.add(event);
          } catch (_) {}
        }
      }
    });

    _tunnelSub = _tunnelEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map && mounted) {
        setState(() {
          _tunnelStatus = (event['status'] as String?) ?? 'stopped';
          _tunnelUrl = event['url'] as String?;
          _tunnelMessage = (event['message'] as String?) ?? '';
        });
      }
    });

    await _startHostServer();
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
    _tunnelSub?.cancel();
    _keepaliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _audioChannel.invokeMethod('stopCapture').catchError((_) {});
    _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    _stopHostServer();
    _disconnectClient(manual: true);
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _startHostServer() async {
    await _stopHostServer();
    try {
      final server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, AppTokens.wsPort);
      _server = server;
      server.listen((HttpRequest req) async {
        if (WebSocketTransformer.isUpgradeRequest(req)) {
          final ws = await WebSocketTransformer.upgrade(req);
          ws.pingInterval = const Duration(seconds: 10);
          if (!mounted) {
            await ws.close();
            return;
          }
          setState(() => _clients.add(ws));
          ws.add(jsonEncode({'pressed': _localPressed}));
          ws.listen(
            (data) {
              if (data is String && data.contains('"ping"')) {
                try {
                  ws.add('{"pong":1}');
                } catch (_) {}
              }
            },
            onDone: () {
              if (mounted) setState(() => _clients.remove(ws));
            },
            onError: (_) {
              if (mounted) setState(() => _clients.remove(ws));
            },
          );
        } else {
          req.response.statusCode = HttpStatus.ok;
          req.response.write('Antigravity Tunnel WS Ready');
          await req.response.close();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _tunnelMessage = 'Server lokal gagal: $e');
      }
    }
  }

  Future<void> _stopHostServer() async {
    for (final c in List<WebSocket>.from(_clients)) {
      await c.close().catchError((_) {});
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _toggleTunnel() async {
    if (_tunnelStatus == 'running' || _tunnelStatus == 'starting') {
      await _tunnelChannel.invokeMethod('stopTunnel').catchError((_) {});
    } else {
      await _tunnelChannel.invokeMethod('startTunnel').catchError((_) {});
    }
  }

  void _copyTunnelUrl() {
    final url = _tunnelUrl;
    if (url == null || url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link tunnel disalin! Kirim ke HP 2.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String? _normalizeTunnelWsUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return null;
    if (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }
    if (raw.startsWith('https://')) {
      return raw.replaceFirst('https://', 'wss://');
    }
    if (raw.startsWith('http://')) {
      return raw.replaceFirst('http://', 'ws://');
    }
    if (raw.startsWith('wss://') || raw.startsWith('ws://')) {
      return raw;
    }
    return 'wss://$raw';
  }

  Future<void> _connectToHost({bool isRetry = false}) async {
    final wsUrl = _normalizeTunnelWsUrl(_targetController.text);
    if (wsUrl == null) return;
    if (!isRetry) {
      _manualDisconnect = false;
      _reconnectTimer?.cancel();
    }
    await _closeSocketOnly();
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
      _clientStatus =
          isRetry ? 'Menyambungkan ulang...' : 'Menghubungkan ke tunnel...';
    });

    try {
      final ws =
          await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 8));
      ws.pingInterval = const Duration(seconds: 10);
      if (!mounted) {
        await ws.close();
        return;
      }
      _clientSocket = ws;
      _keepaliveTimer?.cancel();
      _keepaliveTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (_isConnected && ws.readyState == WebSocket.open) {
          try {
            ws.add('{"ping":1}');
          } catch (_) {}
        }
      });

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _clientStatus = 'Terhubung (Siap menerima suara)';
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
              if (pressed) {
                _audioChannel.invokeMethod('startPlayback').catchError((_) {});
              } else {
                _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
              }
            } catch (_) {}
          } else if (data is List<int>) {
            final bytes = data is Uint8List ? data : Uint8List.fromList(data);
            _audioChannel
                .invokeMethod('writePlayback', bytes)
                .catchError((_) {});
          }
        },
        onDone: () => _handleSocketDrop(
          'Terputus (code: ${ws.closeCode ?? "-"}), mencoba ulang...',
        ),
        onError: (err) => _handleSocketDrop('Error: $err, mencoba ulang...'),
      );
    } catch (e) {
      _handleSocketDrop('Gagal konek: $e');
    }
  }

  void _handleSocketDrop(String msg) {
    _keepaliveTimer?.cancel();
    _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _remotePressed = false;
      _clientStatus = _manualDisconnect ? 'Terputus' : msg;
    });
    if (!_manualDisconnect && _role == NodeRole.receiver) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_manualDisconnect && _role == NodeRole.receiver) {
          _connectToHost(isRetry: true);
        }
      });
    }
  }

  Future<void> _closeSocketOnly() async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    await _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    await _clientSocket?.close().catchError((_) {});
    _clientSocket = null;
  }

  Future<void> _disconnectClient({bool manual = true}) async {
    _manualDisconnect = manual;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocketOnly();
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _remotePressed = false;
        if (manual) {
          _clientStatus = 'Terputus';
        }
      });
    }
  }

  void _switchRole(NodeRole next) async {
    if (_role == next) return;
    await _audioChannel.invokeMethod('stopCapture').catchError((_) {});
    await _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    setState(() {
      _role = next;
      _localPressed = false;
      _remotePressed = false;
    });
    if (next == NodeRole.sender) {
      await _disconnectClient(manual: true);
      await _checkOrRequestMic();
      await _startHostServer();
    } else {
      await _tunnelChannel.invokeMethod('stopTunnel').catchError((_) {});
      await _stopHostServer();
    }
  }

  Future<void> _setPressed(bool pressed) async {
    if (pressed && !_micGranted) {
      final ok = await _checkOrRequestMic();
      if (!ok) return;
    }
    if (_localPressed != pressed) {
      setState(() => _localPressed = pressed);
      final payload = jsonEncode({'pressed': pressed});
      for (final c in List<WebSocket>.from(_clients)) {
        try {
          c.add(payload);
        } catch (_) {}
      }
      if (pressed) {
        _audioChannel.invokeMethod('startCapture').catchError((_) {});
      } else {
        _audioChannel.invokeMethod('stopCapture').catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool receiverActive =
        _role == NodeRole.sender ? _localPressed : _remotePressed;

    return Scaffold(
      backgroundColor: AppTokens.bgScaffold,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildConnectionBar(),
                  _SecondaryReceiverNode(isActive: receiverActive),
                  if (_role == NodeRole.sender)
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
                    )
                  else
                    const SizedBox(height: 168),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBar() {
    final bool tunnelBusy =
        _tunnelStatus == 'starting' || _tunnelStatus == 'running';

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
                child: _RoleChip(
                  label: 'HP 1: Pengirim (Host)',
                  selected: _role == NodeRole.sender,
                  onTap: () => _switchRole(NodeRole.sender),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RoleChip(
                  label: 'HP 2: Penerima (Client)',
                  selected: _role == NodeRole.receiver,
                  onTap: () => _switchRole(NodeRole.receiver),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_role == NodeRole.sender) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mic: ${_micGranted ? "Aktif" : "Belum izin"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.inkDark,
                  ),
                ),
                Text(
                  '${_clients.length} penerima terhubung',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTokens.inkMuted,
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
                    child: ElevatedButton(
                      onPressed: _toggleTunnel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tunnelBusy
                            ? AppTokens.bgPrimaryPressed
                            : AppTokens.bgPrimaryBtn,
                        foregroundColor: AppTokens.inkLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _tunnelStatus == 'running'
                            ? 'Matikan Tunnel Publik'
                            : (_tunnelStatus == 'starting'
                                ? 'Membuka Tunnel...'
                                : 'Mulai Tunnel Publik'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                if (_tunnelUrl != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _copyTunnelUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.inkLight,
                        foregroundColor: AppTokens.inkDark,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Salin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _tunnelUrl ?? _tunnelMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      _tunnelUrl != null ? FontWeight.w600 : FontWeight.w400,
                  color: _tunnelUrl != null
                      ? AppTokens.inkDark
                      : AppTokens.inkMuted,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _targetController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Tempel Link Tunnel (https://...)',
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
                            ? () => _disconnectClient(manual: true)
                            : () => _connectToHost()),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _clientStatus,
                style: const TextStyle(fontSize: 11, color: AppTokens.inkMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
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

class _SecondaryReceiverNode extends StatelessWidget {
  const _SecondaryReceiverNode({required this.isActive});

  final bool isActive;

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
            child: const Text('Penerima'),
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
            child: const Text(
              'Pengirim',
              style: TextStyle(
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
