import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const KoreanVocabApp());
}

class KoreanVocabApp extends StatelessWidget {
  const KoreanVocabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kosakata Bahasa Korea',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          primary: const Color(0xFF4F46E5),
          background: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
      ),
      home: const KoreanVocabScreen(),
    );
  }
}

class VocabItem {
  final String hangul;
  final String romanization;
  final String indonesian;
  final String category;
  final String emoji;
  final IconData fallbackIcon;
  final String exampleSentence;
  final String exampleMeaning;

  const VocabItem({
    required this.hangul,
    required this.romanization,
    required this.indonesian,
    required this.category,
    required this.emoji,
    required this.fallbackIcon,
    required this.exampleSentence,
    required this.exampleMeaning,
  });
}

class KoreanVocabScreen extends StatefulWidget {
  const KoreanVocabScreen({super.key});

  @override
  State<KoreanVocabScreen> createState() => _KoreanVocabScreenState();
}

class _KoreanVocabScreenState extends State<KoreanVocabScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  final List<VocabItem> _allVocab = const [
    // Makanan & Minuman
    VocabItem(
      hangul: '사과',
      romanization: 'sa-gwa',
      indonesian: 'Apel',
      category: 'Makanan',
      emoji: '🍎',
      fallbackIcon: Icons.restaurant,
      exampleSentence: '사과가 아주 맛있어요.',
      exampleMeaning: 'Apelnya sangat enak.',
    ),
    VocabItem(
      hangul: '물',
      romanization: 'mul',
      indonesian: 'Air',
      category: 'Makanan',
      emoji: '💧',
      fallbackIcon: Icons.water_drop,
      exampleSentence: '물 좀 주세요.',
      exampleMeaning: 'Tolong berikan air.',
    ),
    VocabItem(
      hangul: '밥',
      romanization: 'bap',
      indonesian: 'Nasi / Makanan',
      category: 'Makanan',
      emoji: '🍚',
      fallbackIcon: Icons.rice_bowl,
      exampleSentence: '밥을 먹었어요?',
      exampleMeaning: 'Sudah makan nasi?',
    ),
    VocabItem(
      hangul: '김치',
      romanization: 'gim-chi',
      indonesian: 'Kimchi',
      category: 'Makanan',
      emoji: '🥬',
      fallbackIcon: Icons.set_meal,
      exampleSentence: '김치는 매콤하고 맛있어요.',
      exampleMeaning: 'Kimchi sedikit pedas dan enak.',
    ),
    VocabItem(
      hangul: '우유',
      romanization: 'u-yu',
      indonesian: 'Susu',
      category: 'Makanan',
      emoji: '🥛',
      fallbackIcon: Icons.local_drink,
      exampleSentence: '아침에 우유를 마셔요.',
      exampleMeaning: 'Minum susu di pagi hari.',
    ),
    VocabItem(
      hangul: '커피',
      romanization: 'keo-pi',
      indonesian: 'Kopi',
      category: 'Makanan',
      emoji: '☕',
      fallbackIcon: Icons.coffee,
      exampleSentence: '따뜻한 커피 한 잔 주세요.',
      exampleMeaning: 'Minta secangkir kopi hangat.',
    ),
    VocabItem(
      hangul: '빵',
      romanization: 'ppang',
      indonesian: 'Roti',
      category: 'Makanan',
      emoji: '🍞',
      fallbackIcon: Icons.bakery_dining,
      exampleSentence: '빵을 구워요.',
      exampleMeaning: 'Memanggang roti.',
    ),

    // Hewan
    VocabItem(
      hangul: '고양이',
      romanization: 'go-yang-i',
      indonesian: 'Kucing',
      category: 'Hewan',
      emoji: '🐱',
      fallbackIcon: Icons.pets,
      exampleSentence: '고양이가 귀여워요.',
      exampleMeaning: 'Kucingnya lucu.',
    ),
    VocabItem(
      hangul: '강아지',
      romanization: 'gang-a-ji',
      indonesian: 'Anak Anjing',
      category: 'Hewan',
      emoji: '🐶',
      fallbackIcon: Icons.pets,
      exampleSentence: '강아지가 공을 물었어요.',
      exampleMeaning: 'Anak anjing menggigit bola.',
    ),
    VocabItem(
      hangul: '새',
      romanization: 'sae',
      indonesian: 'Burung',
      category: 'Hewan',
      emoji: '🐦',
      fallbackIcon: Icons.flight,
      exampleSentence: '하늘에 새가 날아요.',
      exampleMeaning: 'Burung terbang di langit.',
    ),
    VocabItem(
      hangul: '물고기',
      romanization: 'mul-go-gi',
      indonesian: 'Ikan',
      category: 'Hewan',
      emoji: '🐟',
      fallbackIcon: Icons.waves,
      exampleSentence: '물고기가 헤엄쳐요.',
      exampleMeaning: 'Ikan sedang berenang.',
    ),
    VocabItem(
      hangul: '토끼',
      romanization: 'to-kki',
      indonesian: 'Kelinci',
      category: 'Hewan',
      emoji: '🐰',
      fallbackIcon: Icons.cruelty_free,
      exampleSentence: '토끼가 당근을 좋아해요.',
      exampleMeaning: 'Kelinci suka wortel.',
    ),

    // Benda & Tempat
    VocabItem(
      hangul: '책',
      romanization: 'chaek',
      indonesian: 'Buku',
      category: 'Benda',
      emoji: '📚',
      fallbackIcon: Icons.menu_book,
      exampleSentence: '도서관에서 책을 읽어요.',
      exampleMeaning: 'Membaca buku di perpustakaan.',
    ),
    VocabItem(
      hangul: '학교',
      romanization: 'hak-gyo',
      indonesian: 'Sekolah',
      category: 'Benda',
      emoji: '🏫',
      fallbackIcon: Icons.school,
      exampleSentence: '내일 학교에 가요.',
      exampleMeaning: 'Besok pergi ke sekolah.',
    ),
    VocabItem(
      hangul: '집',
      romanization: 'jip',
      indonesian: 'Rumah',
      category: 'Benda',
      emoji: '🏠',
      fallbackIcon: Icons.home,
      exampleSentence: '우리 집에 놀러 오세요.',
      exampleMeaning: 'Ayo main ke rumahku.',
    ),
    VocabItem(
      hangul: '자동차',
      romanization: 'ja-dong-cha',
      indonesian: 'Mobil',
      category: 'Benda',
      emoji: '🚗',
      fallbackIcon: Icons.directions_car,
      exampleSentence: '새 자동차를 샀어요.',
      exampleMeaning: 'Saya membeli mobil baru.',
    ),
    VocabItem(
      hangul: '핸드폰',
      romanization: 'haen-deu-pon',
      indonesian: 'Handphone',
      category: 'Benda',
      emoji: '📱',
      fallbackIcon: Icons.smartphone,
      exampleSentence: '핸드폰 배터리가 없어요.',
      exampleMeaning: 'Baterai handphone habis.',
    ),
    VocabItem(
      hangul: '비행기',
      romanization: 'bi-haeng-gi',
      indonesian: 'Pesawat Terbang',
      category: 'Benda',
      emoji: '✈️',
      fallbackIcon: Icons.flight_takeoff,
      exampleSentence: '비행기를 타고 한국에 가요.',
      exampleMeaning: 'Naik pesawat pergi ke Korea.',
    ),

    // Alam & Waktu
    VocabItem(
      hangul: '태양 / 해',
      romanization: 'tae-yang / hae',
      indonesian: 'Matahari',
      category: 'Alam',
      emoji: '☀️',
      fallbackIcon: Icons.wb_sunny,
      exampleSentence: '해가 떠오르고 있어요.',
      exampleMeaning: 'Matahari sedang terbit.',
    ),
    VocabItem(
      hangul: '달',
      romanization: 'dal',
      indonesian: 'Bulan',
      category: 'Alam',
      emoji: '🌙',
      fallbackIcon: Icons.nightlight_round,
      exampleSentence: '오늘 밤 달이 밝아요.',
      exampleMeaning: 'Malam ini bulan sangat terang.',
    ),
    VocabItem(
      hangul: '꽃',
      romanization: 'kkot',
      indonesian: 'Bunga',
      category: 'Alam',
      emoji: '🌸',
      fallbackIcon: Icons.local_florist,
      exampleSentence: '봄에 꽃이 피어요.',
      exampleMeaning: 'Bunga mekar di musim semi.',
    ),
    VocabItem(
      hangul: '나무',
      romanization: 'na-mu',
      indonesian: 'Pohon',
      category: 'Alam',
      emoji: '🌳',
      fallbackIcon: Icons.park,
      exampleSentence: '나무 그늘 아래에서 쉬어요.',
      exampleMeaning: 'Istirahat di bawah bayangan pohon.',
    ),
    VocabItem(
      hangul: '바다',
      romanization: 'ba-da',
      indonesian: 'Laut',
      category: 'Alam',
      emoji: '🌊',
      fallbackIcon: Icons.beach_access,
      exampleSentence: '여름에 바다에 가요.',
      exampleMeaning: 'Pergi ke laut di musim panas.',
    ),

    // Percakapan & Salam
    VocabItem(
      hangul: '안녕하세요',
      romanization: 'an-nyeong-ha-se-yo',
      indonesian: 'Halo / Selamat Pagi/Siang/Malam',
      category: 'Ungkapan',
      emoji: '👋',
      fallbackIcon: Icons.waving_hand,
      exampleSentence: '안녕하세요! 만나서 반가워요.',
      exampleMeaning: 'Halo! Senang bertemu denganmu.',
    ),
    VocabItem(
      hangul: '감사합니다',
      romanization: 'gam-sa-ham-ni-da',
      indonesian: 'Terima kasih',
      category: 'Ungkapan',
      emoji: '🙏',
      fallbackIcon: Icons.favorite,
      exampleSentence: '도와주셔서 감사합니다.',
      exampleMeaning: 'Terima kasih atas bantuannya.',
    ),
    VocabItem(
      hangul: '사랑해',
      romanization: 'sa-rang-hae',
      indonesian: 'Aku cinta kamu',
      category: 'Ungkapan',
      emoji: '💖',
      fallbackIcon: Icons.favorite,
      exampleSentence: '정말 많이 사랑해요.',
      exampleMeaning: 'Aku sangat mencintaimu.',
    ),
    VocabItem(
      hangul: '죄송합니다',
      romanization: 'joe-song-ham-ni-da',
      indonesian: 'Maaf',
      category: 'Ungkapan',
      emoji: '🙇',
      fallbackIcon: Icons.sentiment_dissatisfied,
      exampleSentence: '늦어서 정말 죄송합니다.',
      exampleMeaning: 'Maaf sekali saya terlambat.',
    ),
  ];

  final List<String> _categories = [
    'Semua',
    'Makanan',
    'Hewan',
    'Benda',
    'Alam',
    'Ungkapan',
  ];

  List<VocabItem> get _filteredList {
    final query = _searchController.text.trim().toLowerCase();
    return _allVocab.where((item) {
      final matchesCategory =
          _selectedCategory == 'Semua' || item.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          item.hangul.toLowerCase().contains(query) ||
          item.romanization.toLowerCase().contains(query) ||
          item.indonesian.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _showDetailSheet(VocabItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.hangul,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '[ ${item.romanization} ]',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.indonesian,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contoh Kalimat:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.exampleSentence,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.exampleMeaning,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredList;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '한국어 단어 (Kosakata)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Belajar kosakata Korea bergambar & artinya',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari Hangul, Romawi, atau Indonesia...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // Category Filters
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      selectedColor: const Color(0xFF4F46E5),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      showCheckmark: false,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kosakata tidak ditemukan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coba kata kunci lain atau pilih kategori Semua',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showDetailSheet(item),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Gambar / Emoji Visual Badge
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                item.emoji,
                                style: const TextStyle(fontSize: 30),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Detail Text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.hangul,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${item.romanization})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.indonesian,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Category Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
