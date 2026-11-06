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
      title: 'Floating Capsule & Top Circle Buttons',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: const FloatingCapsuleScreen(),
    );
  }
}

class FloatingCapsuleScreen extends StatefulWidget {
  const FloatingCapsuleScreen({super.key});

  @override
  State<FloatingCapsuleScreen> createState() => _FloatingCapsuleScreenState();
}

class _FloatingCapsuleScreenState extends State<FloatingCapsuleScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background canvas kosong
          const Positioned.fill(
            child: SizedBox.expand(),
          ),

          // Top Circle Buttons (Fixed top: 24px + safe area)
          Positioned(
            top: topPadding + 24.0,
            left: 20.0,
            right: 20.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TopCircleButton(
                  onTap: () {},
                ),
                _TopCircleButton(
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Bottom Capsule Input Bar (Fixed bottom: 24px + safe area)
          Positioned(
            bottom: bottomPadding + 24.0,
            left: 16.0,
            right: 16.0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: const Color.fromRGBO(0, 0, 0, 0.04),
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
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    top: 6.0,
                    right: 8.0,
                    bottom: 6.0,
                  ),
                  child: Row(
                    children: [
                      // Input TextField
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
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Action Button (Kirim)
                      _ActionButton(
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Circle Button Atas (Width: 48, Height: 48, Deep separation shadow, Scale on tap)
class _TopCircleButton extends StatefulWidget {
  final VoidCallback onTap;

  const _TopCircleButton({required this.onTap});

  @override
  State<_TopCircleButton> createState() => _TopCircleButtonState();
}

class _TopCircleButtonState extends State<_TopCircleButton> {
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
            color: const Color(0xFFFFFFFF),
            border: Border.all(
              color: const Color.fromRGBO(0, 0, 0, 0.06),
              width: 1,
            ),
            boxShadow: _isPressed
                ? const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.25),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.15),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ]
                : const [
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
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.22),
                      offset: Offset(0, 16),
                      blurRadius: 32,
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.28),
                      offset: Offset(0, 24),
                      blurRadius: 48,
                      spreadRadius: -8,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

// Action Button Kirim (Width: 44, Height: 44, Accent blue, Custom Arrow Icon, Scale on tap)
class _ActionButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ActionButton({required this.onTap});

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
            color: const Color(0xFF2563EB),
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

// 1:1 Vector Arrow Up SVG Painter
// <line x1="12" y1="19" x2="12" y2="5"></line>
// <polyline points="5 12 12 5 19 12"></polyline>
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

    // Line x1="12" y1="19" x2="12" y2="5"
    canvas.drawLine(
      Offset(12 * scaleX, 19 * scaleY),
      Offset(12 * scaleX, 5 * scaleY),
      paint,
    );

    // Polyline points="5 12 12 5 19 12"
    final path = Path()
      ..moveTo(5 * scaleX, 12 * scaleY)
      ..lineTo(12 * scaleX, 5 * scaleY)
      ..lineTo(19 * scaleX, 12 * scaleY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
