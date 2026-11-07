import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );
  runApp(const MultiCanvasApp());
}

class MultiCanvasApp extends StatelessWidget {
  const MultiCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D Floating UI - Multi Canvas 9Router & Webview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
      ),
      home: const MainWorkspaceScreen(),
    );
  }
}

class ProductionConfig {
  static const String routerDashboardUrl = 'http://localhost:20128';
  static const String apiEndpoint =
      'http://localhost:20128/v1/chat/completions';
  static const String apiKey = '9router-local';
  static const String modelName = 'claude-3-5-sonnet';
}

class MainWorkspaceScreen extends StatefulWidget {
  const MainWorkspaceScreen({super.key});

  @override
  State<MainWorkspaceScreen> createState() => _MainWorkspaceScreenState();
}

class _MainWorkspaceScreenState extends State<MainWorkspaceScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatTurnItem> _turns = [];
  bool _isWorking = false;
  HttpClientRequest? _activeRequest;

  // Webview Canvas States
  bool _isRouterCanvasOpen = false;
  bool _isLinkCanvasOpen = false;
  String _currentWebviewUrl = 'about:blank';
  late final WebViewController _routerWebController;
  late final WebViewController _linkWebController;

  @override
  void initState() {
    super.initState();
    _initWebControllers();
    _startRuntimeBackground();
  }

  void _initWebControllers() {
    _routerWebController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            _showRouterFallbackError();
          },
        ),
      );

    _linkWebController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
  }

  void _showRouterFallbackError() {
    const errorHtml = '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0; padding: 24px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #F8FAFC; color: #1E293B;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      min-height: 80vh; text-align: center;
    }
    .card {
      background: #FFFFFF; border-radius: 24px;
      padding: 32px 24px; max-width: 400px; width: 100%;
      box-shadow: 0 10px 25px -5px rgba(0,0,0,0.06), 0 8px 10px -6px rgba(0,0,0,0.04);
      border: 1px solid #E2E8F0;
    }
    .badge {
      display: inline-flex; align-items: center; gap: 6px;
      background: #FEF3C7; color: #D97706;
      padding: 6px 12px; border-radius: 20px; font-size: 12px;
      font-weight: 700; margin-bottom: 16px;
    }
    h2 { margin: 0 0 10px 0; font-size: 19px; font-weight: 700; color: #0F172A; }
    p { margin: 0 0 16px 0; font-size: 13.5px; line-height: 1.6; color: #64748B; }
    .code-box {
      background: #0F172A; color: #38BDF8; padding: 14px 16px;
      border-radius: 12px; font-size: 13.5px; font-family: monospace;
      font-weight: 600; text-align: left; margin-bottom: 20px;
    }
    .btn {
      display: block; width: 100%;
      background: linear-gradient(135deg, #2563EB, #1D4ED8);
      color: white; border: none; padding: 14px; border-radius: 14px;
      font-weight: 600; font-size: 14px; text-decoration: none;
      cursor: pointer; box-shadow: 0 4px 12px rgba(37,99,235,0.25);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">⚠️ 9ROUTER GATEWAY OFFLINE</div>
    <h2>Dashboard Belum Aktif</h2>
    <p>Instance 9Router belum berjalan di <b>localhost:20128</b>. Buka Termux dan aktifkan gateway dengan perintah:</p>
    <div class="code-box">
      <span>$ 9router start</span>
    </div>
    <button class="btn" onclick="location.href='http://localhost:20128'">⚡ Muat Ulang Dashboard</button>
  </div>
</body>
</html>
''';
    _routerWebController.loadHtmlString(errorHtml);
  }

  Future<void> _startRuntimeBackground() async {
    // Memastikan environment runtime Node.js & 9Router di APK
    try {
      final appDir = await Directory.systemTemp.createTemp('app_runtime');
      debugPrint('[Runtime] Initialized runtime storage: ${appDir.path}');
    } catch (e) {
      debugPrint('[Runtime] Initialization error: $e');
    }
  }

  void _openRouterDashboard() {
    setState(() {
      _currentWebviewUrl = ProductionConfig.routerDashboardUrl;
      _isRouterCanvasOpen = true;
    });
    _routerWebController.loadRequest(Uri.parse(ProductionConfig.routerDashboardUrl));
  }

  void _openExternalLink(String url) {
    var validUrl = url;
    if (!validUrl.startsWith('http://') && !validUrl.startsWith('https://')) {
      validUrl = 'https://$validUrl';
    }
    setState(() {
      _currentWebviewUrl = validUrl;
      _isLinkCanvasOpen = true;
    });
    _linkWebController.loadRequest(Uri.parse(validUrl));
  }

  void _closeRouterCanvas() {
    setState(() => _isRouterCanvasOpen = false);
  }

  void _closeLinkCanvas() {
    setState(() => _isLinkCanvasOpen = false);
  }

  void _submitTask(String text) {
    if (text.trim().isEmpty || _isWorking) return;

    final turn = _ChatTurnItem(
      userQuery: text.trim(),
      startTime: DateTime.now(),
    );

    setState(() {
      _turns.add(turn);
      _isWorking = true;
      _inputController.clear();
    });

    _scrollToBottom();
    _executeStreamTask(turn);
  }

  void _abortTask() {
    if (_activeRequest != null) {
      _activeRequest?.abort();
      _activeRequest = null;
    }
    setState(() {
      _isWorking = false;
      if (_turns.isNotEmpty) {
        _turns.last.isAborted = true;
        _turns.last.isFinished = true;
      }
    });
  }

  Future<void> _executeStreamTask(_ChatTurnItem turn) async {
    turn.thinkingSteps.add('Menghubungkan ke 9Router gateway (localhost:20128)...');
    setState(() {});

    final client = HttpClient();
    try {
      final uri = Uri.parse(ProductionConfig.apiEndpoint);
      final request = await client.postUrl(uri);
      _activeRequest = request;

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer ${ProductionConfig.apiKey}');

      final payload = jsonEncode({
        'model': ProductionConfig.modelName,
        'messages': [
          {'role': 'user', 'content': turn.userQuery}
        ],
        'stream': true,
      });

      request.write(payload);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception(
            '9Router Response Status: ${response.statusCode} ${response.reasonPhrase}');
      }

      setState(() {
        turn.isThinkingFinished = true;
      });

      var buffer = '';
      await for (final chunk in response.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
          if (trimmed == 'data: [DONE]') break;

          if (trimmed.startsWith('data: ')) {
            try {
              final json = jsonDecode(trimmed.substring(6));
              final content =
                  json['choices']?[0]?['delta']?['content'] ?? '';
              if (content.isNotEmpty) {
                setState(() {
                  turn.responseContent += content;
                });
                _scrollToBottom();
              }
            } catch (_) {}
          }
        }
      }

      setState(() {
        turn.isFinished = true;
      });
    } catch (e) {
      if (!turn.isAborted) {
        setState(() {
          turn.isThinkingFinished = true;
          turn.isFinished = true;
          turn.responseContent =
              '**Gagal terhubung ke 9Router**: $e.\n\nPastikan instance 9Router aktif di terminal via `9router start` dan port `20128` dapat dijangkau.';
        });
      }
    } finally {
      client.close();
      _activeRequest = null;
      setState(() {
        _isWorking = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Content Scroll Area
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: topPadding + 92.0,
                bottom: bottomPadding + 110.0,
                left: 18.0,
                right: 18.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      for (int i = 0; i < _turns.length; i++)
                        _buildChatTurnWidget(_turns[i]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Top Header (Tombol 9Router di kiri atas & Settings di kanan atas)
          Positioned(
            top: topPadding + 24.0,
            left: 20.0,
            right: 20.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tombol Buka Dashboard 9Router (Kiri Atas)
                _CircleButton(
                  onTap: _openRouterDashboard,
                  child: CustomPaint(
                    size: const Size(22, 22),
                    painter: _RouterIconPainter(),
                  ),
                ),

                // Tombol Settings (Kanan Atas)
                _CircleButton(
                  onTap: () {},
                  child: CustomPaint(
                    size: const Size(20, 20),
                    painter: _SettingsIconPainter(),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Bottom Capsule Input Bar
          Positioned(
            bottom: bottomPadding + 12.0,
            left: 16.0,
            right: 16.0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _FloatingCapsuleBar(
                  controller: _inputController,
                  isWorking: _isWorking,
                  onSubmit: () => _submitTask(_inputController.text),
                  onAbort: _abortTask,
                ),
              ),
            ),
          ),

          // 4. Canvas Khusus 1: Webview Dashboard 9Router Localhost
          _buildWebviewCanvas(
            isOpen: _isRouterCanvasOpen,
            controller: _routerWebController,
            url: _currentWebviewUrl,
            onClose: _closeRouterCanvas,
            onOpenExternal: () {},
          ),

          // 5. Canvas Khusus 2: Webview Tautan Eksternal / Link Markdown Chat
          _buildWebviewCanvas(
            isOpen: _isLinkCanvasOpen,
            controller: _linkWebController,
            url: _currentWebviewUrl,
            onClose: _closeLinkCanvas,
            onOpenExternal: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildWebviewCanvas({
    required bool isOpen,
    required WebViewController controller,
    required String url,
    required VoidCallback onClose,
    required VoidCallback onOpenExternal,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: const Cubic(0.16, 1, 0.3, 1),
      top: isOpen ? 0 : MediaQuery.of(context).size.height,
      left: 0,
      right: 0,
      bottom: isOpen ? 0 : -MediaQuery.of(context).size.height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isOpen ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !isOpen,
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: SafeArea(
              child: Stack(
                children: [
                  // Webview Viewport
                  Positioned.fill(
                    top: 84.0,
                    child: Container(
                      color: Colors.white,
                      child: WebViewWidget(controller: controller),
                    ),
                  ),

                  // Top Bar
                  Positioned(
                    top: 20.0,
                    left: 20.0,
                    right: 20.0,
                    child: Row(
                      children: [
                        _CircleButton(
                          onTap: onClose,
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            size: 26,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFF8FAFC),
                                  Color(0xFFEEF2F6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color.fromRGBO(255, 255, 255, 0.95),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.08),
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                                BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.16),
                                  offset: Offset(0, 8),
                                  blurRadius: 16,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 15,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    url,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _CircleButton(
                          onTap: () => controller.reload(),
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
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

  Widget _buildChatTurnWidget(_ChatTurnItem turn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Query Bubble
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.86,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(6),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(15, 23, 42, 0.15),
                      offset: Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  turn.userQuery,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 15,
                    height: 1.45,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Thinking Panel
          _ThinkingPanelWidget(turn: turn),

          // Markdown Content Response
          if (turn.responseContent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.05)),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.04),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Text(
                turn.responseContent,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatTurnItem {
  final String userQuery;
  final DateTime startTime;
  final List<String> thinkingSteps = [];
  bool isThinkingFinished = false;
  bool isFinished = false;
  bool isAborted = false;
  String responseContent = '';

  _ChatTurnItem({
    required this.userQuery,
    required this.startTime,
  });
}

class _ThinkingPanelWidget extends StatefulWidget {
  final _ChatTurnItem turn;

  const _ThinkingPanelWidget({required this.turn});

  @override
  State<_ThinkingPanelWidget> createState() => _ThinkingPanelWidgetState();
}

class _ThinkingPanelWidgetState extends State<_ThinkingPanelWidget> {
  bool _isOpen = true;
  Timer? _timer;
  double _elapsedSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (widget.turn.isThinkingFinished || widget.turn.isAborted) {
        t.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds =
            (DateTime.now().difference(widget.turn.startTime).inMilliseconds) /
                1000.0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turn = widget.turn;
    String label;
    if (turn.isAborted) {
      label = 'Stopped (${_elapsedSeconds.toStringAsFixed(1)}s)';
    } else if (turn.isThinkingFinished) {
      label = 'Thought for ${_elapsedSeconds.toStringAsFixed(1)}s';
    } else {
      label = 'Working for ${_elapsedSeconds.toStringAsFixed(1)}s...';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isOpen = !_isOpen),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!turn.isThinkingFinished && !turn.isAborted) ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: turn.isAborted
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isOpen && turn.thinkingSteps.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6, left: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFCBD5E1), width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: turn.thinkingSteps
                  .map(
                    (step) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// Circle Button Widget (48x48)
class _CircleButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _CircleButton({required this.onTap, required this.child});

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: const Cubic(0.34, 1.56, 0.64, 1),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFE8EDF3)],
            ),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.9),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.10),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.22),
                offset: Offset(0, 8),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// Floating Capsule Bar Widget
class _FloatingCapsuleBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isWorking;
  final VoidCallback onSubmit;
  final VoidCallback onAbort;

  const _FloatingCapsuleBar({
    required this.controller,
    required this.isWorking,
    required this.onSubmit,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFEEF2F6)],
        ),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.9),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            offset: Offset(0, 10),
            blurRadius: 15,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.16),
            offset: Offset(0, 32),
            blurRadius: 48,
          ),
        ],
      ),
      child: Row(
        children: [
          // Plus Button
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF1F5F9),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Color(0xFF334155),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Text Field Input
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
              decoration: const InputDecoration(
                hintText: 'Ketik perintah atau tugas produksi...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => isWorking ? onAbort() : onSubmit(),
            ),
          ),
          const SizedBox(width: 8),

          // Send / Stop Action Button
          GestureDetector(
            onTap: isWorking ? onAbort : onSubmit,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isWorking
                    ? const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.2),
                    offset: Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: isWorking
                    ? Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 9Router Icon CustomPainter (SVG: rect, dots, line, arcs)
class _RouterIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 2.0 * (size.width / 24.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final sX = size.width / 24.0;
    final sY = size.height / 24.0;

    // rect x="2" y="14" width="20" height="8" rx="2"
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2 * sX, 14 * sY, 20 * sX, 8 * sY),
      Radius.circular(2 * sX),
    );
    canvas.drawRRect(rrect, paint);

    // dots at (6, 18) and (10, 18)
    canvas.drawCircle(Offset(6 * sX, 18 * sY), 0.5 * sX, paint);
    canvas.drawCircle(Offset(10 * sX, 18 * sY), 0.5 * sX, paint);

    // line x1="15" y1="6" x2="15" y2="14"
    canvas.drawLine(Offset(15 * sX, 6 * sY), Offset(15 * sX, 14 * sY), paint);

    // antenna arcs
    final path1 = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(15 * sX, 10 * sY), radius: 3 * sX),
        math.pi,
        math.pi,
      );
    canvas.drawPath(path1, paint);

    final path2 = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(15 * sX, 7 * sY), radius: 6 * sX),
        math.pi,
        math.pi,
      );
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Settings Icon CustomPainter (Gear SVG)
class _SettingsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 2.0 * (size.width / 24.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final sX = size.width / 24.0;
    final sY = size.height / 24.0;

    // Center circle cx=12, cy=12, r=3
    canvas.drawCircle(Offset(12 * sX, 12 * sY), 3 * sX, paint);

    // Outer gear body
    final path = Path()
      ..moveTo(19.4 * sX, 15 * sY)
      ..lineTo(19.73 * sX, 16.82 * sY)
      ..lineTo(16.9 * sX, 19.65 * sY)
      ..lineTo(15.08 * sX, 19.32 * sY)
      ..lineTo(14 * sX, 21 * sY)
      ..lineTo(10 * sX, 21 * sY)
      ..lineTo(8.92 * sX, 19.32 * sY)
      ..lineTo(7.1 * sX, 19.65 * sY)
      ..lineTo(4.27 * sX, 16.82 * sY)
      ..lineTo(4.6 * sX, 15 * sY)
      ..lineTo(3 * sX, 14 * sY)
      ..lineTo(3 * sX, 10 * sY)
      ..lineTo(4.6 * sX, 9 * sY)
      ..lineTo(4.27 * sX, 7.18 * sY)
      ..lineTo(7.1 * sX, 4.35 * sY)
      ..lineTo(8.92 * sX, 4.68 * sY)
      ..lineTo(10 * sX, 3 * sY)
      ..lineTo(14 * sX, 3 * sY)
      ..lineTo(15.08 * sX, 4.68 * sY)
      ..lineTo(16.9 * sX, 4.35 * sY)
      ..lineTo(19.73 * sX, 7.18 * sY)
      ..lineTo(19.4 * sX, 9 * sY)
      ..lineTo(21 * sX, 10 * sY)
      ..lineTo(21 * sX, 14 * sY)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
