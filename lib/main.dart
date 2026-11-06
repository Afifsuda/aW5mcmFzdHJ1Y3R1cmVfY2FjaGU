import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D Floating UI - Web Components',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
      ),
      home: const FloatingUiScreen(),
    );
  }
}

class FloatingUiScreen extends StatefulWidget {
  const FloatingUiScreen({super.key});

  @override
  State<FloatingUiScreen> createState() => _FloatingUiScreenState();
}

class _FloatingUiScreenState extends State<FloatingUiScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPopupOpen = false;

  // Toggle UI tombol kiri atas (tetap tersimpan di kode, disembunyikan sementara)
  final bool _showTopLeftCircleButton = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'user',
      'text': 'Ringkas konsep layer antarmuka floating capsule ini.',
    },
    {
      'role': 'assistant',
      'text':
          'Semua interaksi dipecah menjadi tiga bidang elevasi independen agar tidak saling mengunci scroll canvas utama:',
      'specs': [
        {
          'title': 'Canvas Dinamis: ',
          'desc':
              'Berjalan di background utama dengan inset vertikal 92px atas dan 110px bawah untuk area gerak leluasa.',
        },
        {
          'title': 'Action Overlay: ',
          'desc':
              'Dua tombol lingkaran melayang presisi di area status bar dengan bayangan ambient terpisah.',
        },
        {
          'title': 'Control Capsule: ',
          'desc':
              'Input bar cembung 3D berada 12px dari dasar layar dengan menu aksi vertikal berbasis trigger lokal.',
        },
      ],
    },
    {
      'role': 'user',
      'text': 'Apakah popup aksi aman dari pemotongan batas layar?',
    },
    {
      'role': 'assistant',
      'text':
          'Aman. Origin scale dan transform anchored tepat di pojok kiri bawah (bottom: calc(100% + 14px); left: 0;), sehingga pembukaan card selalu mengarah ke atas menjauhi bezel perangkat.',
    },
  ];

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
      });
      _inputController.clear();
      _isPopupOpen = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _closePopup() {
    if (_isPopupOpen) {
      setState(() => _isPopupOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: GestureDetector(
        onTap: _closePopup,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Area Scroll Konten (.content-scroll)
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < _messages.length; i++) ...[
                          _buildTurn(_messages[i]),
                          if (i < _messages.length - 1)
                            const SizedBox(height: 28),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top Container (.top-container) - Fixed top: 24px + topPadding
            Positioned(
              top: topPadding + 24.0,
              left: 20.0,
              right: 20.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol kiri atas (disembunyikan sementara) atau Debug UI Performance Minimalis
                  if (_showTopLeftCircleButton)
                    const _TopCircleButton()
                  else
                    const _MinimalPerformanceDebugBadge(),

                  // Tombol kanan atas
                  const _TopCircleButton(),
                ],
              ),
            ),

            // Bottom Container (.bottom-container) - Fixed bottom: 12px + bottomPadding
            Positioned(
              bottom: bottomPadding + 12.0,
              left: 16.0,
              right: 16.0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Popup Card Vertikal
                      Positioned(
                        bottom: 56.0 + 14.0,
                        left: 0,
                        child: _buildPopupCard(),
                      ),

                      // Kapsul Bar
                      _buildCapsuleBar(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurn(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.86,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
              msg['text'] as String,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 15,
                height: 1.45,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ),
      );
    } else {
      final specs = msg['specs'] as List<Map<String, String>>?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg['text'] as String,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF1E293B),
            ),
          ),
          if (specs != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color.fromRGBO(0, 0, 0, 0.05),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.04),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < specs.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 7),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF334155),
                              ),
                              children: [
                                TextSpan(
                                  text: specs[i]['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: specs[i]['desc']),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < specs.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }
  }

  // Popup Card Vertikal
  Widget _buildPopupCard() {
    return AnimatedScale(
      scale: _isPopupOpen ? 1.0 : 0.92,
      duration: const Duration(milliseconds: 160),
      curve: const Cubic(0.34, 1.56, 0.64, 1),
      alignment: Alignment.bottomLeft,
      child: AnimatedOpacity(
        opacity: _isPopupOpen ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 160),
        child: IgnorePointer(
          ignoring: !_isPopupOpen,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.9),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.08),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.16),
                  offset: Offset(0, 16),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.22),
                  offset: Offset(0, 28),
                  blurRadius: 40,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PopupItem(
                  label: 'Camera',
                  iconPainter: _CameraIconPainter(),
                  onTap: () {
                    setState(() => _isPopupOpen = false);
                  },
                ),
                const SizedBox(height: 6),
                _PopupItem(
                  label: 'Upload',
                  iconPainter: _UploadIconPainter(),
                  onTap: () {
                    setState(() => _isPopupOpen = false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Kapsul Bar
  Widget _buildCapsuleBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55, 1.0],
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
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            offset: Offset(0, 10),
            blurRadius: 15,
            spreadRadius: -3,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.10),
            offset: Offset(0, 20),
            blurRadius: 25,
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.16),
            offset: Offset(0, 32),
            blurRadius: 48,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Plus Button (rotasi 45deg saat aktif)
          _PlusButton(
            isOpen: _isPopupOpen,
            onTap: () {
              setState(() => _isPopupOpen = !_isPopupOpen);
            },
          ),
          const SizedBox(width: 12),

          // Input Text
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF0F172A),
                decoration: TextDecoration.none,
              ),
              decoration: const InputDecoration(
                hintText: 'Ketik pesan atau perintah...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          _SendButton(
            onTap: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// Circle Button Atas (Width: 48, Height: 48, Gradient 3D, Multi-layer Shadow)
class _TopCircleButton extends StatefulWidget {
  const _TopCircleButton();

  @override
  State<_TopCircleButton> createState() => _TopCircleButtonState();
}

class _TopCircleButtonState extends State<_TopCircleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
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
              stops: [0.0, 0.50, 1.0],
              colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFE8EDF3)],
            ),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.9),
              width: 1,
            ),
            boxShadow: _isPressed
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.20),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.12),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ]
                : const [
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
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.30),
                      offset: Offset(0, 14),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

// Plus Button dengan animasi rotasi 45 derajat & scale
class _PlusButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _PlusButton({required this.isOpen, required this.onTap});

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
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
      child: AnimatedRotation(
        turns: widget.isOpen ? 0.125 : 0.0, // 45 degrees = 1/8 turn
        duration: const Duration(milliseconds: 160),
        curve: const Cubic(0.34, 1.56, 0.64, 1),
        child: AnimatedScale(
          scale: _isPressed && !widget.isOpen ? 0.86 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: const Cubic(0.34, 1.56, 0.64, 1),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.60, 1.0],
                colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
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
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.30),
                  offset: Offset(0, 14),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(22, 22),
                painter: _PlusIconPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Send Button (Kirim) dengan Gradient Biru 3D
class _SendButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.55, 1.0],
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.35),
              width: 1,
            ),
            boxShadow: _isPressed
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.20),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ]
                : const [
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
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.30),
                      offset: Offset(0, 14),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _UpArrowPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

// Popup Item Button
class _PopupItem extends StatefulWidget {
  final String label;
  final CustomPainter iconPainter;
  final VoidCallback onTap;

  const _PopupItem({
    required this.label,
    required this.iconPainter,
    required this.onTap,
  });

  @override
  State<_PopupItem> createState() => _PopupItemState();
}

class _PopupItemState extends State<_PopupItem> {
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
      child: Container(
        padding: const EdgeInsets.only(left: 6, top: 6, right: 14, bottom: 6),
        decoration: BoxDecoration(
          color: _isPressed ? const Color.fromRGBO(0, 0, 0, 0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _isPressed ? 0.88 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: const Cubic(0.34, 1.56, 0.64, 1),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.50, 1.0],
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
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.30),
                      offset: Offset(0, 14),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(19, 19),
                    painter: widget.iconPainter,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 1:1 Vector Plus SVG Painter: <line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line>
class _PlusIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 2.5 * (size.width / 24.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    canvas.drawLine(
      Offset(12 * scaleX, 5 * scaleY),
      Offset(12 * scaleX, 19 * scaleY),
      paint,
    );
    canvas.drawLine(
      Offset(5 * scaleX, 12 * scaleY),
      Offset(19 * scaleX, 12 * scaleY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 1:1 Vector Arrow Up SVG Painter
class _UpArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.5 * (size.width / 24.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    canvas.drawLine(
      Offset(12 * scaleX, 19 * scaleY),
      Offset(12 * scaleX, 5 * scaleY),
      paint,
    );

    final path = Path()
      ..moveTo(5 * scaleX, 12 * scaleY)
      ..lineTo(12 * scaleX, 5 * scaleY)
      ..lineTo(19 * scaleX, 12 * scaleY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 1:1 Vector Camera SVG: <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path><circle cx="12" cy="13" r="4"></circle>
class _CameraIconPainter extends CustomPainter {
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

    // Body path
    final path = Path()
      ..moveTo(23 * sX, 19 * sY)
      ..arcToPoint(Offset(21 * sX, 21 * sY), radius: Radius.circular(2 * sX))
      ..lineTo(3 * sX, 21 * sY)
      ..arcToPoint(Offset(1 * sX, 19 * sY), radius: Radius.circular(2 * sX))
      ..lineTo(1 * sX, 8 * sY)
      ..arcToPoint(Offset(3 * sX, 6 * sY), radius: Radius.circular(2 * sX))
      ..lineTo(7 * sX, 6 * sY)
      ..lineTo(9 * sX, 3 * sY)
      ..lineTo(15 * sX, 3 * sY)
      ..lineTo(17 * sX, 6 * sY)
      ..lineTo(21 * sX, 6 * sY)
      ..arcToPoint(Offset(23 * sX, 8 * sY), radius: Radius.circular(2 * sX))
      ..close();

    canvas.drawPath(path, paint);

    // Circle lens cx=12, cy=13, r=4
    canvas.drawCircle(Offset(12 * sX, 13 * sY), 4 * sX, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 1:1 Vector Upload SVG: <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" y1="3" x2="12" y2="15"></line>
class _UploadIconPainter extends CustomPainter {
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

    // Tray path: M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4
    final path = Path()
      ..moveTo(21 * sX, 15 * sY)
      ..lineTo(21 * sX, 19 * sY)
      ..arcToPoint(Offset(19 * sX, 21 * sY), radius: Radius.circular(2 * sX))
      ..lineTo(5 * sX, 21 * sY)
      ..arcToPoint(Offset(3 * sX, 19 * sY), radius: Radius.circular(2 * sX))
      ..lineTo(3 * sX, 15 * sY);
    canvas.drawPath(path, paint);

    // Arrow stem: line x1="12" y1="3" x2="12" y2="15"
    canvas.drawLine(Offset(12 * sX, 3 * sY), Offset(12 * sX, 15 * sY), paint);

    // Arrow head: polyline points="17 8 12 3 7 8"
    final head = Path()
      ..moveTo(17 * sX, 8 * sY)
      ..lineTo(12 * sX, 3 * sY)
      ..lineTo(7 * sX, 8 * sY);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Debug UI Performance Minimalist (FPS & Frame Time)
class _MinimalPerformanceDebugBadge extends StatefulWidget {
  const _MinimalPerformanceDebugBadge();

  @override
  State<_MinimalPerformanceDebugBadge> createState() =>
      _MinimalPerformanceDebugBadgeState();
}

class _MinimalPerformanceDebugBadgeState
    extends State<_MinimalPerformanceDebugBadge> {
  int _fps = 60;
  double _frameTimeMs = 16.6;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_onPostFrame);
  }

  void _onPostFrame(Duration timestamp) {
    if (!mounted) return;
    final now = DateTime.now();
    _frameCount++;
    final elapsed = now.difference(_lastTime).inMilliseconds;

    if (elapsed >= 500) {
      final currentFps = ((_frameCount * 1000) / elapsed).round().clamp(1, 120);
      final currentFrameTime = currentFps > 0 ? 1000.0 / currentFps : 16.6;
      setState(() {
        _fps = currentFps;
        _frameTimeMs = double.parse(currentFrameTime.toStringAsFixed(1));
        _frameCount = 0;
        _lastTime = now;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback(_onPostFrame);
  }

  @override
  Widget build(BuildContext context) {
    final isGood = _fps >= 55;
    final statusColor =
        isGood ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color.fromRGBO(0, 0, 0, 0.06),
          width: 1,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live pulse dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // FPS display
          Text(
            '$_fps',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'FPS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),

          // Divider
          Container(
            width: 1,
            height: 14,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 8),

          // Frame Time display
          Text(
            '${_frameTimeMs}ms',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
