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

  NodeRole _role = NodeRole.sender;
  bool _localPressed = false;
  bool _remotePressed = false;
  bool _micGranted = false;
  int? _activePointer;
  StreamSubscription<dynamic>? _micSub;

  // Host (Pengirim) state
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  String _hostIp = 'Mendeteksi IP...';

  // Client (Penerima) state
  WebSocket? _clientSocket;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _clientStatus = 'Belum terhubung';
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAudioAndServer();
  }

  Future<void> _initAudioAndServer() async {
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
    _audioChannel.invokeMethod('stopCapture').catchError((_) {});
    _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    _stopHostServer();
    _disconnectClient();
    _ipController.dispose();
    super.dispose();
  }

  Future<String> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      String? fallbackIp;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.')) {
            return ip;
          }
          fallbackIp ??= ip;
        }
      }
      return fallbackIp ?? '127.0.0.1';
    } catch (_) {
      return '127.0.0.1';
    }
  }

  Future<void> _startHostServer() async {
    await _stopHostServer();
    final ip = await _detectLocalIp();
    if (!mounted) return;
    setState(() => _hostIp = ip);

    try {
      final server =
          await HttpServer.bind(InternetAddress.anyIPv4, AppTokens.wsPort);
      _server = server;
      server.listen((HttpRequest req) async {
        if (WebSocketTransformer.isUpgradeRequest(req)) {
          final ws = await WebSocketTransformer.upgrade(req);
          if (!mounted) {
            await ws.close();
            return;
          }
          setState(() => _clients.add(ws));
          ws.add(jsonEncode({'pressed': _localPressed}));
          ws.listen(
            (_) {},
            onDone: () {
              if (mounted) setState(() => _clients.remove(ws));
            },
            onError: (_) {
              if (mounted) setState(() => _clients.remove(ws));
            },
          );
        } else {
          req.response.statusCode = HttpStatus.ok;
          req.response.write('Antigravity Hotspot WS Server');
          await req.response.close();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _hostIp = 'Error: $e');
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

  Future<void> _prefillGatewayIp() async {
    if (_ipController.text.isNotEmpty) return;
    final myIp = await _detectLocalIp();
    final parts = myIp.split('.');
    if (parts.length == 4 && myIp != '127.0.0.1') {
      _ipController.text = '${parts[0]}.${parts[1]}.${parts[2]}.1';
    } else {
      _ipController.text = '192.168.43.1';
    }
  }

  Future<void> _connectToHost() async {
    var raw = _ipController.text.trim();
    if (raw.isEmpty) return;
    raw = raw.replaceFirst(RegExp(r'^wss?://'), '');
    final wsUrl =
        raw.contains(':') ? 'ws://$raw' : 'ws://$raw:${AppTokens.wsPort}';
    await _disconnectClient();
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
      _clientStatus = 'Menghubungkan ke $wsUrl...';
    });

    try {
      final ws = await WebSocket.connect(wsUrl)
          .timeout(const Duration(seconds: 5));
      if (!mounted) {
        await ws.close();
        return;
      }
      _clientSocket = ws;
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _clientStatus = 'Terhubung ke $raw (Siap menerima suara)';
      });
      ws.listen(
        (data) {
          if (data is String) {
            try {
              final map = jsonDecode(data) as Map<String, dynamic>;
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
            final bytes =
                data is Uint8List ? data : Uint8List.fromList(data);
            _audioChannel
                .invokeMethod('writePlayback', bytes)
                .catchError((_) {});
          }
        },
        onDone: () {
          _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
          if (mounted) {
            setState(() {
              _isConnected = false;
              _remotePressed = false;
              _clientStatus = 'Terputus dari host';
            });
          }
        },
        onError: (_) {
          _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
          if (mounted) {
            setState(() {
              _isConnected = false;
              _remotePressed = false;
              _clientStatus = 'Koneksi error';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
          _clientStatus = 'Gagal konek ke $raw';
        });
      }
    }
  }

  Future<void> _disconnectClient() async {
    await _audioChannel.invokeMethod('stopPlayback').catchError((_) {});
    await _clientSocket?.close().catchError((_) {});
    _clientSocket = null;
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _remotePressed = false;
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
      await _disconnectClient();
      await _checkOrRequestMic();
      await _startHostServer();
    } else {
      await _stopHostServer();
      await _prefillGatewayIp();
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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
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
          if (_role == NodeRole.sender)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'IP: $_hostIp:${AppTokens.wsPort} • Mic: ${_micGranted ? "Aktif" : "Belum izin"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.inkDark,
                  ),
                ),
                Text(
                  '${_clients.length} terhubung',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTokens.inkMuted,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'IP atau IP:Port (mis. 192.168.43.1)',
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
                        : (_isConnected ? _disconnectClient : _connectToHost),
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
          if (_role == NodeRole.receiver) ...[
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
