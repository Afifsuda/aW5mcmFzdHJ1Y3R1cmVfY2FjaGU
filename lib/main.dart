import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const AntigravityApp());
}

class AntigravityApp extends StatelessWidget {
  const AntigravityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Antigravity Chat',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const ChatHomePage(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isSelf;
  final String senderId;
  final int ts;

  ChatMessage({
    required this.text,
    required this.isSelf,
    required this.senderId,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'self': isSelf,
        'senderId': senderId,
        'ts': ts,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j, String myId) {
    final sid = (j['senderId'] ?? '').toString();
    final self = j['self'] is bool ? j['self'] as bool : (sid.isNotEmpty && sid == myId);
    return ChatMessage(
      text: (j['text'] ?? '').toString(),
      isSelf: self,
      senderId: sid,
      ts: (j['ts'] is int) ? j['ts'] as int : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  static const int localPort = 8080;
  static const int discoveryPort = 8081;

  static const List<String> wallpapers = [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1080&q=80',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1080&q=80',
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1080&q=80',
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1080&q=80',
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1080&q=80',
    'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1080&q=80',
  ];

  int _wallIdx = 0;

  bool _plusPressed = false;
  bool _btnPressed = false;
  bool _videoPressed = false;
  bool _callPressed = false;

  bool _isOnline = true;
  String _lastSeenText = 'Online';
  bool _modalOpen = false;

  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _ipCtrl = TextEditingController();

  final List<ChatMessage> _messages = [];
  String _deviceId = '';
  String _netMode = 'host';
  String _hostIp = '192.168.1.5';
  String _myIp = '127.0.0.1';
  bool _wsConnected = false;
  String _lastNetError = '';

  HttpServer? _hostServer;
  final List<WebSocket> _hostPeers = [];
  WebSocket? _clientWs;
  RawDatagramSocket? _udpSocket;
  Timer? _udpBeaconTimer;
  Timer? _clientReconnectTimer;
  final Map<String, String> _discoveredHosts = {};

  @override
  void initState() {
    super.initState();
    _loadPrefsAndStart();
  }

  Future<void> _loadPrefsAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id') ?? '';
    if (id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
      await prefs.setString('device_id', id);
    }
    _deviceId = id;
    _netMode = prefs.getString('net_mode') ?? 'host';
    _hostIp = prefs.getString('host_ip') ?? '192.168.1.5';
    _ipCtrl.text = _hostIp;

    final rawHist = prefs.getString('chat_history');
    if (rawHist != null && rawHist.isNotEmpty) {
      try {
        final list = jsonDecode(rawHist) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _messages.add(ChatMessage.fromJson(item, _deviceId));
          }
        }
      } catch (_) {}
    }

    _myIp = await _getLocalIpv4();
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
    _restartNetwork();
    _startUdpDiscovery();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = _messages.length > 200 ? _messages.sublist(_messages.length - 200) : _messages;
    await prefs.setString('chat_history', jsonEncode(trimmed.map((m) => m.toJson()).toList()));
  }

  void _setProfileState(bool online) {
    setState(() {
      _isOnline = online;
      if (online) {
        _lastSeenText = 'Online';
      } else {
        final now = DateTime.now();
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        _lastSeenText = 'Terakhir dilihat pukul $hh:$mm';
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _triggerSend() {
    final text = _msgCtrl.text.trim();
    HapticFeedback.lightImpact();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    final cmd = RegExp(r'^/stateprofile(?:\s+(online|offline))?$', caseSensitive: false).firstMatch(text);
    if (cmd != null) {
      final arg = cmd.group(1)?.toLowerCase();
      _setProfileState(arg == 'online' ? true : arg == 'offline' ? false : !_isOnline);
      return;
    }

    final msg = ChatMessage(
      text: text,
      isSelf: true,
      senderId: _deviceId,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _messages.add(msg));
    _saveHistory();
    _scrollToBottom();
    _broadcastJson({'type': 'chat', ...msg.toJson()});
  }

  void _triggerPlus() {
    HapticFeedback.mediumImpact();
    _ipCtrl.text = _hostIp;
    setState(() => _modalOpen = true);
  }

  Future<String> _getLocalIpv4() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void _stopNetwork() {
    _clientReconnectTimer?.cancel();
    _clientReconnectTimer = null;
    try {
      _clientWs?.close();
    } catch (_) {}
    _clientWs = null;
    for (final p in _hostPeers) {
      try {
        p.close();
      } catch (_) {}
    }
    _hostPeers.clear();
    try {
      _hostServer?.close(force: true);
    } catch (_) {}
    _hostServer = null;
    _wsConnected = false;
  }

  Future<void> _restartNetwork() async {
    _stopNetwork();
    _myIp = await _getLocalIpv4();
    if (_netMode == 'host') {
      try {
        _hostServer = await HttpServer.bind(InternetAddress.anyIPv4, localPort);
        _wsConnected = true;
        _lastNetError = '';
        _hostServer!.listen((req) async {
          if (WebSocketTransformer.isUpgradeRequest(req)) {
            final ws = await WebSocketTransformer.upgrade(req);
            _hostPeers.add(ws);
            ws.add(jsonEncode({
              'type': 'history',
              'items': _messages.map((m) => m.toJson()).toList(),
            }));
            if (mounted) setState(() {});
            ws.listen(
              (data) => _handleIncomingPayload(data.toString(), fromHostPeer: ws),
              onDone: () {
                _hostPeers.remove(ws);
                if (mounted) setState(() {});
              },
              onError: (_) => _hostPeers.remove(ws),
            );
          } else {
            req.response.statusCode = 200;
            req.response.write('Antigravity Host OK');
            await req.response.close();
          }
        });
      } catch (e) {
        _lastNetError = e.toString();
      }
    } else {
      _connectClient();
    }
    if (mounted) setState(() {});
  }

  Future<void> _connectClient() async {
    try {
      final ws = await WebSocket.connect('ws://$_hostIp:$localPort').timeout(const Duration(seconds: 5));
      _clientWs = ws;
      _wsConnected = true;
      _lastNetError = '';
      if (mounted) setState(() {});
      ws.listen(
        (data) => _handleIncomingPayload(data.toString()),
        onDone: () {
          _wsConnected = false;
          if (mounted) setState(() {});
          _scheduleClientReconnect();
        },
        onError: (e) {
          _wsConnected = false;
          _lastNetError = e.toString();
          if (mounted) setState(() {});
          _scheduleClientReconnect();
        },
      );
    } catch (e) {
      _wsConnected = false;
      _lastNetError = e.toString();
      if (mounted) setState(() {});
      _scheduleClientReconnect();
    }
  }

  void _scheduleClientReconnect() {
    if (_netMode != 'client' || !mounted) return;
    _clientReconnectTimer?.cancel();
    _clientReconnectTimer = Timer(const Duration(milliseconds: 2500), () {
      if (_netMode == 'client' && mounted) _connectClient();
    });
  }

  void _broadcastJson(Map<String, dynamic> obj, {WebSocket? exclude}) {
    final encoded = jsonEncode(obj);
    if (_netMode == 'host') {
      for (final p in List<WebSocket>.from(_hostPeers)) {
        if (p != exclude) {
          try {
            p.add(encoded);
          } catch (_) {}
        }
      }
    } else {
      try {
        _clientWs?.add(encoded);
      } catch (_) {}
    }
  }

  void _handleIncomingPayload(String raw, {WebSocket? fromHostPeer}) {
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      final type = obj['type'];
      if (type == 'chat') {
        final msg = ChatMessage.fromJson(obj, _deviceId);
        if (msg.text.trim().isNotEmpty) {
          if (mounted) {
            setState(() => _messages.add(msg));
            _saveHistory();
            _scrollToBottom();
          }
          if (fromHostPeer != null) {
            _broadcastJson(obj, exclude: fromHostPeer);
          }
        }
      } else if (type == 'history') {
        final items = obj['items'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _messages
              ..clear()
              ..addAll(items.whereType<Map<String, dynamic>>().map((e) => ChatMessage.fromJson(e, _deviceId)));
          });
          _saveHistory();
          _scrollToBottom();
        }
      } else if (type == 'clear_history') {
        if (mounted) {
          setState(() => _messages.clear());
          _saveHistory();
        }
      }
    } catch (_) {}
  }

  Future<void> _startUdpDiscovery() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true);
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen((ev) {
        if (ev == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg == null) return;
          final s = utf8.decode(dg.data, allowMalformed: true);
          if (s.startsWith('AGY_HOST|')) {
            final ip = dg.address.address;
            if (ip != _myIp) {
              final model = s.substring('AGY_HOST|'.length).trim();
              if (mounted) setState(() => _discoveredHosts[ip] = model.isEmpty ? 'Android' : model);
            }
          }
        }
      });
      _udpBeaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_netMode == 'host' && _udpSocket != null) {
          final data = utf8.encode('AGY_HOST|Flutter');
          _udpSocket!.send(data, InternetAddress('255.255.255.255'), discoveryPort);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _udpBeaconTimer?.cancel();
    _udpSocket?.close();
    _stopNetwork();
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  BoxDecoration _matteSurface({
    double radius = 28,
    bool isCircle = false,
    bool isAccent = false,
    bool pressed = false,
  }) {
    return BoxDecoration(
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isAccent
            ? (pressed
                ? const [Color(0xFF2372EA), Color(0xFF104EB8)]
                : const [Color(0xFF2E84FF), Color(0xFF145FD9)])
            : (pressed
                ? const [Color(0xFFEBF0F7), Color(0xFFD5DFEC)]
                : const [Color(0xFFFCFDFF), Color(0xFFE3EAF4)]),
      ),
      border: Border.all(
        color: isAccent ? const Color(0x669AC5FF) : Colors.white.withOpacity(0.88),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(pressed ? 0.14 : (isCircle ? 0.20 : 0.15)),
          blurRadius: pressed ? 4 : (isCircle ? 8 : 14),
          offset: Offset(0, pressed ? 1 : (isCircle ? 3 : 5)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final topInset = mq.padding.top;
    final kbBottom = mq.viewInsets.bottom;

    final totalHeaderW = math.min(sw - 28.0, 540.0);
    const actionW = 108.0;
    const gapW = 10.0;
    final profileW = totalHeaderW - actionW - gapW;
    final headerTop = topInset + 10.0;

    final totalBarW = math.min(sw - 28.0, 540.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFEEF1F6),
      body: Stack(
        children: [
          // 1. NATIVE FLUTTER WALLPAPER BACKGROUND
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _msgFocus.unfocus();
                setState(() => _wallIdx = (_wallIdx + 1) % wallpapers.length);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Image.network(
                  wallpapers[_wallIdx],
                  key: ValueKey(_wallIdx),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEEF1F6)),
                ),
              ),
            ),
          ),

          // 2. FLOATING CHAT LIST WITH SMOOTH TOP/BOTTOM FADE
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) {
                final topStop = ((headerTop + 56.0) / rect.height).clamp(0.0, 0.35);
                final topFadeEnd = ((headerTop + 78.0) / rect.height).clamp(0.0, 0.40);
                final botFadeStart = ((rect.height - kbBottom - 84.0) / rect.height).clamp(0.5, 1.0);
                final botStop = ((rect.height - kbBottom - 58.0) / rect.height).clamp(0.55, 1.0);
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: [0.0, topStop, topFadeEnd, botFadeStart, botStop, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  14,
                  headerTop + 68.0,
                  14,
                  kbBottom + 84.0,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return Align(
                    alignment: m.isSelf ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      constraints: BoxConstraints(maxWidth: math.min(sw * 0.76, 290)),
                      padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
                      decoration: BoxDecoration(
                        gradient: m.isSelf
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFDFF7EA), Color(0xFFCBEEDC)],
                              )
                            : null,
                        color: m.isSelf ? null : const Color(0xFFF5F8FC),
                        border: Border.all(
                          color: m.isSelf ? const Color(0xFF9ED8BB) : const Color(0xFFD8E0EC),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(m.isSelf ? 18 : 5),
                          bottomRight: Radius.circular(m.isSelf ? 5 : 18),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22141E30),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              m.text,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                color: m.isSelf ? const Color(0xFF142C22) : const Color(0xFF111622),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatTime(m.ts),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: (m.isSelf ? const Color(0xFF142C22) : const Color(0xFF111622))
                                  .withOpacity(0.62),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. FLOATING HEADER: PROFILE CAPSULE + SEPARATE ACTIONS CAPSULE
          Positioned(
            top: headerTop,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: totalHeaderW,
                height: 56,
                child: Row(
                  children: [
                    Container(
                      width: profileW,
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: _matteSurface(radius: 28),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.person, color: Colors.white, size: 20),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isOnline ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                                      border: Border.all(color: const Color(0xFFF5F8FC), width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Afif',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111622),
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _lastSeenText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: gapW),
                    Container(
                      width: actionW,
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: _matteSurface(radius: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCircleActionBtn(
                            icon: Icons.videocam_rounded,
                            pressed: _videoPressed,
                            onChanged: (v) => setState(() => _videoPressed = v),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Video Call (Preview)'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                          _buildCircleActionBtn(
                            icon: Icons.call_rounded,
                            pressed: _callPressed,
                            onChanged: (v) => setState(() => _callPressed = v),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Voice Call (Preview)'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. FLOATING BOTTOM INPUT CAPSULE (+, TEXTFIELD, SEND)
          Positioned(
            bottom: kbBottom + 10.0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: totalBarW,
                constraints: const BoxConstraints(minHeight: 52, maxHeight: 148),
                padding: const EdgeInsets.all(6),
                decoration: _matteSurface(radius: 26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildCircleActionBtn(
                      icon: Icons.add_rounded,
                      size: 40,
                      iconSize: 22,
                      pressed: _plusPressed,
                      onChanged: (v) => setState(() => _plusPressed = v),
                      onTap: _triggerPlus,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        focusNode: _msgFocus,
                        maxLines: 6,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 22 / 17,
                          color: Color(0xFF111622),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Tulis pesan...',
                          hintStyle: TextStyle(color: Color(0xFF768296), fontSize: 17),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleActionBtn(
                      icon: Icons.arrow_upward_rounded,
                      size: 40,
                      iconSize: 21,
                      isAccent: true,
                      pressed: _btnPressed,
                      onChanged: (v) => setState(() => _btnPressed = v),
                      onTap: _triggerSend,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. POPUP + MODAL
          if (_modalOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _modalOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.10),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: _matteSurface(radius: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Koneksi Lokal & Chat',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111622),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Mode: ${_netMode == 'host' ? 'Host Lokal (Port $localPort, ${_hostPeers.length} client)' : 'Client Lokal ($_hostIp:$localPort)'}\n'
                            'Status: ${_wsConnected ? 'Terhubung' : 'Menyambung...${_lastNetError.isEmpty ? '' : ' ($_lastNetError)'}'}\n'
                            'IP HP ini: $_myIp',
                            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF5B677A)),
                          ),
                          if (_discoveredHosts.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ..._discoveredHosts.entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildModalButton(
                                    label: 'Gabung ${e.value} (${e.key})',
                                    topColor: const Color(0xFFE8EEF6),
                                    botColor: const Color(0xFFD8E1EE),
                                    strokeColor: const Color(0xFFCBD5E1),
                                    textColor: const Color(0xFF1E293B),
                                    onTap: () async {
                                      _hostIp = e.key;
                                      _netMode = 'client';
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setString('net_mode', _netMode);
                                      await prefs.setString('host_ip', _hostIp);
                                      _restartNetwork();
                                      if (mounted) setState(() => _modalOpen = false);
                                    },
                                  ),
                                )),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _ipCtrl,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF111622)),
                            decoration: InputDecoration(
                              hintText: 'IP Host (misal 192.168.1.5)',
                              hintStyle: const TextStyle(color: Color(0xFF768296), fontSize: 14),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0x40768296)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0x40768296)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModalButton(
                                  label: 'Hapus',
                                  topColor: const Color(0xFFFEE2E2),
                                  botColor: const Color(0xFFFECACA),
                                  strokeColor: const Color(0xFFFCA5A5),
                                  textColor: const Color(0xFFB91C1C),
                                  onTap: () {
                                    setState(() {
                                      _messages.clear();
                                      _modalOpen = false;
                                    });
                                    _saveHistory();
                                    _broadcastJson({'type': 'clear_history'});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildModalButton(
                                  label: 'Gabung',
                                  topColor: const Color(0xFFE8EEF6),
                                  botColor: const Color(0xFFD8E1EE),
                                  strokeColor: const Color(0xFFCBD5E1),
                                  textColor: const Color(0xFF1E293B),
                                  onTap: () async {
                                    final ip = _ipCtrl.text.trim();
                                    if (ip.isEmpty) return;
                                    _hostIp = ip;
                                    _netMode = 'client';
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('net_mode', _netMode);
                                    await prefs.setString('host_ip', _hostIp);
                                    _restartNetwork();
                                    if (mounted) setState(() => _modalOpen = false);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildModalButton(
                                  label: 'Jadi Host',
                                  topColor: const Color(0xFF10B981),
                                  botColor: const Color(0xFF059669),
                                  strokeColor: const Color(0xFF047857),
                                  textColor: Colors.white,
                                  onTap: () async {
                                    _netMode = 'host';
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('net_mode', _netMode);
                                    _restartNetwork();
                                    if (mounted) setState(() => _modalOpen = false);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCircleActionBtn({
    required IconData icon,
    required bool pressed,
    required ValueChanged<bool> onChanged,
    required VoidCallback onTap,
    double size = 44,
    double iconSize = 19,
    bool isAccent = false,
  }) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) {
        onChanged(false);
        onTap();
      },
      onTapCancel: () => onChanged(false),
      child: AnimatedScale(
        scale: pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: size,
          height: size,
          decoration: _matteSurface(isCircle: true, isAccent: isAccent, pressed: pressed),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: isAccent ? Colors.white : const Color(0xFF111622),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalButton({
    required String label,
    required Color topColor,
    required Color botColor,
    required Color strokeColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, botColor],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: strokeColor, width: 0.75),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
