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
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canvas Capsule UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      home: const CanvasCapsuleScreen(),
    );
  }
}

class CanvasCapsuleScreen extends StatefulWidget {
  const CanvasCapsuleScreen({super.key});

  @override
  State<CanvasCapsuleScreen> createState() => _CanvasCapsuleScreenState();
}

class _CanvasCapsuleScreenState extends State<CanvasCapsuleScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Canvas Kosong
            const Expanded(
              child: SizedBox.expand(),
            ),

            // Capsule UI di bawah (satu baris, flat + shadow)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Tombol Plus di sebelah kiri di dalam capsule
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF334155),
                        size: 24,
                      ),
                      splashRadius: 22,
                      onPressed: () {},
                    ),

                    // Input Text
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          hintText: '',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),

                    // Tombol Kirim di sebelah kanan di dalam capsule
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Color(0xFF334155),
                        size: 24,
                      ),
                      splashRadius: 22,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
