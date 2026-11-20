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
  static const Color inkDark = Color(0xFF181816);
  static const Color inkMuted = Color(0xFF787872);

  // Cloudflare Worker Relay (diamankan, siap dipakai lagi)
  static const String relayBaseWsUrl =
      'wss://aw5mcmfzdhj1y3R1cmvfy2fjagu.sudaapip.workers.dev';
}

class FlutterNativeApp extends StatelessWidget {
  const FlutterNativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTokens.bgScaffold,
        useMaterial3: true,
      ),
      home: const CanvasHomeScreen(),
    );
  }
}

class CanvasHomeScreen extends StatelessWidget {
  const CanvasHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTokens.bgScaffold,
      body: SafeArea(
        child: Center(
          child: Text(
            'Antigravity Canvas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTokens.inkDark,
            ),
          ),
        ),
      ),
    );
  }
}
