import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AntigravityFlutterApp());
}

class AntigravityFlutterApp extends StatelessWidget {
  const AntigravityFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Mobile',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0E17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF0F172A),
          background: Color(0xFF0B0E17),
        ),
        fontFamily: 'monospace',
      ),
      home: const AntigravityWorkspaceScreen(),
    );
  }
}

enum ModelEffort { low, medium, high }

class ChatMessage {
  final String id;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final String? codeSnippet;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.codeSnippet,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AntigravityWorkspaceScreen extends StatefulWidget {
  const AntigravityWorkspaceScreen({super.key});

  @override
  State<AntigravityWorkspaceScreen> createState() =>
      _AntigravityWorkspaceScreenState();
}

class _AntigravityWorkspaceScreenState extends State<AntigravityWorkspaceScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _currentModel = 'Gemini 2.5 Flash';
  ModelEffort _effortLevel = ModelEffort.medium;
  bool _isAgentRunning = false;
  int _activeTabIndex = 0; // 0: Chat, 1: Files, 2: Terminal

  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      role: 'assistant',
      content:
          'Halo! Antigravity Mobile Engine (ARM64) aktif.\nAutonomous workspace siap digunakan di Android tanpa PRoot/chroot.',
      codeSnippet: '''// Native Bionic Engine Check
Architecture: aarch64 (ARMv8.0-A+)
Backend: Local ConnectRPC Engine (127.0.0.1:42124)
Storage Engine: Direct UFS /data/local/tmp
Status: 100% Native Flutter UI''',
    ),
  ];

  final List<String> _workspaceFiles = [
    'lib/main.dart',
    'android/app/build.gradle.kts',
    'android/app/release.keystore',
    'pubspec.yaml',
    '.github/workflows/build-apk.yml',
    'modules/core/bionic_loader.so',
    'modules/patches/syscall_table.json',
  ];

  final List<String> _terminalLogs = [
    '\$ agy status',
    '[OK] Daemon PID 18492 running (memory: 8.4 MB)',
    '[OK] ARM64 bionic syscall table mapped',
    '[OK] ConnectRPC TLS listener bound to 127.0.0.1:42124',
    '[OK] Worktree initialized at /home/repo_flutter',
    '\$ ready for prompt...',
  ];

  void _scrollToBottom() {
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

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: 'user',
          content: text,
        ),
      );
      _isAgentRunning = true;
    });
    _scrollToBottom();

    // Simulate Agent Thinking & Response
    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _terminalLogs.add('\$ execute task: "$text"');
        _messages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content:
                'Instruksi diproses oleh engine [$_currentModel - ${_effortLevel.name.toUpperCase()}]. Operasi file dan kompilasi lokal berhasil diselesaikan.',
            codeSnippet: '''void executeAutonomousTask() {
  print("Running on ARM64 Native Runtime");
  // Done with 0 KB storage overhead
}''',
          ),
        );
        _isAgentRunning = false;
      });
      _scrollToBottom();
    });
  }

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final models = [
              'Gemini 2.5 Flash',
              'Gemini 2.5 Pro',
              'Claude 3.7 Sonnet',
              'DeepSeek-R1 (Local)',
            ];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PILIH MODEL AI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF38BDF8), width: 0.8),
                        ),
                        child: const Text(
                          'ARM64 NATIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...models.map((m) {
                    final isSelected = m == _currentModel;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? const Color(0xFF38BDF8)
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                      title: Text(
                        m,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFCBD5E1),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _effortLevel.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        setState(() => _currentModel = m);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                  const Divider(color: Color(0xFF334155), height: 32),
                  const Text(
                    'THINKING EFFORT (BUDGET)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: ModelEffort.values.map((effort) {
                      final isSelected = effort == _effortLevel;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() => _effortLevel = effort);
                            setState(() => _effortLevel = effort);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              effort.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Antigravity Mobile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
                GestureDetector(
                  onTap: _showModelPicker,
                  child: Row(
                    children: [
                      Text(
                        '$_currentModel (${_effortLevel.name})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF38BDF8),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isAgentRunning
                  ? Colors.amber.withOpacity(0.15)
                  : const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isAgentRunning
                    ? Colors.amber
                    : const Color(0xFF10B981),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isAgentRunning
                        ? Colors.amber
                        : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isAgentRunning ? 'WORKING' : 'DAEMON IDLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isAgentRunning
                        ? Colors.amber
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation Tabs (Chat / Files / Terminal)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildNavTab(0, 'Chat Stream', Icons.chat_bubble_outline),
                _buildNavTab(1, 'Project Files', Icons.folder_outlined),
                _buildNavTab(2, 'ARM64 Shell', Icons.terminal_outlined),
              ],
            ),
          ),

          // Main View Body
          Expanded(
            child: IndexedStack(
              index: _activeTabIndex,
              children: [
                _buildChatView(),
                _buildFilesView(),
                _buildTerminalView(),
              ],
            ),
          ),

          // Bottom Prompt Input Bar
          if (_activeTabIndex == 0) _buildBottomInputBar(),
        ],
      ),
    );
  }

  Widget _buildNavTab(int index, String label, IconData icon) {
    final isActive = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFF38BDF8) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? const Color(0xFFF1F5F9) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.role == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFF0369A1)
                  : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUser
                    ? const Color(0xFF38BDF8).withOpacity(0.3)
                    : const Color(0xFF334155),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isUser ? 'USER' : 'ANTIGRAVITY ENGINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isUser
                            ? const Color(0xFFBAE6FD)
                            : const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  msg.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFF8FAFC),
                    height: 1.4,
                  ),
                ),
                if (msg.codeSnippet != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0E17),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      msg.codeSnippet!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _workspaceFiles.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Color(0xFF1E293B), height: 1),
      itemBuilder: (context, index) {
        final file = _workspaceFiles[index];
        final isDart = file.endsWith('.dart');
        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Icon(
            isDart ? Icons.code_rounded : Icons.insert_drive_file_outlined,
            color: isDart ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
            size: 20,
          ),
          title: Text(
            file,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFE2E8F0),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: Color(0xFF64748B),
            size: 16,
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Membuka file: $file'),
                duration: const Duration(seconds: 1),
                backgroundColor: const Color(0xFF0284C7),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTerminalView() {
    return Container(
      color: const Color(0xFF0B0E17),
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: _terminalLogs.length,
        itemBuilder: (context, index) {
          final line = _terminalLogs[index];
          final isCommand = line.startsWith('\$');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              line,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isCommand
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF94A3B8),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Perintahkan Autonomous AI Agent...',
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
