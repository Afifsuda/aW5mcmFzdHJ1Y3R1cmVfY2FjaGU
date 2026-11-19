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

class VoiceNodeScreen extends StatefulWidget {
  const VoiceNodeScreen({super.key});

  @override
  State<VoiceNodeScreen> createState() => _VoiceNodeScreenState();
}

class _VoiceNodeScreenState extends State<VoiceNodeScreen> {
  bool _isPressed = false;
  int? _activePointer;

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) {
      setState(() => _isPressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bgScaffold,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 64, 24, 72),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SecondaryReceiverNode(isActive: _isPressed),
                  _PrimarySenderNode(
                    isActive: _isPressed,
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
