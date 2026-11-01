import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Satellite Map Canvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        useMaterial3: true,
      ),
      home: const SatelliteMapScreen(),
    );
  }
}

// 1. Model Data (1:1 Flutter Size & LatLng)
class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

// 2. Proyeksi Web Mercator dengan Batasan Latitude
class Mercator {
  static double clampLat(double lat) {
    return lat.clamp(-85.051128, 85.051128);
  }

  static Offset latLngToPoint(LatLng latLng, double zoom) {
    final scale = 256.0 * math.pow(2.0, zoom);
    final x = ((latLng.lng + 180.0) / 360.0) * scale;
    final safeLat = clampLat(latLng.lat);
    final sinLat = math.sin(safeLat * math.pi / 180.0);
    final y = (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) * scale;
    return Offset(x, y);
  }

  static LatLng pointToLatLng(double x, double y, double zoom) {
    final scale = 256.0 * math.pow(2.0, zoom);
    final lng = (x / scale) * 360.0 - 180.0;
    final n = math.pi - 2.0 * math.pi * (y / scale);
    final lat = (180.0 / math.pi) * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return LatLng(clampLat(lat), lng);
  }
}

// 3. Tile Loader (Esri World Imagery - Tanpa API Key)
class TileManager extends ChangeNotifier {
  final Map<String, ui.Image?> _cache = {};
  final HttpClient _httpClient = HttpClient();

  ui.Image? getTile(int x, int y, int z) {
    final key = '$z/$y/$x';
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    final max = 1 << z;
    final wrappedX = ((x % max) + max) % max;
    if (y < 0 || y >= max) return null;

    _cache[key] = null; // Tandai sedang memuat
    _loadTile(wrappedX, y, z, key);
    return null;
  }

  Future<void> _loadTile(int x, int y, int z, String key) async {
    try {
      final url = Uri.parse(
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x',
      );
      final request = await _httpClient.getUrl(url);
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        _cache[key] = frameInfo.image;
        notifyListeners();
      }
    } catch (_) {
      // Abaikan jika ada kegagalan jaringan individual
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}

// 4. CustomPainter (1:1 Flutter CustomPainter)
class SatelliteMapPainter extends CustomPainter {
  final TileManager tileManager;
  final LatLng centerLatLng;
  final int zoom;

  SatelliteMapPainter({
    required this.tileManager,
    required this.centerLatLng,
    required this.zoom,
  }) : super(repaint: tileManager);

  @override
  void paint(Canvas canvas, Size size) {
    const double tileSize = 256.0;
    final centerPoint = Mercator.latLngToPoint(centerLatLng, zoom.toDouble());

    final startX = centerPoint.dx - size.width / 2.0;
    final startY = centerPoint.dy - size.height / 2.0;

    final minTileX = (startX / tileSize).floor();
    final maxTileX = ((startX + size.width) / tileSize).floor();
    final int maxIndex = (1 << zoom) - 1;
    final minTileY = (startY / tileSize).floor().clamp(0, maxIndex);
    final maxTileY = ((startY + size.height) / tileSize).floor().clamp(0, maxIndex);

    // Background hitam
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    for (int tx = minTileX; tx <= maxTileX; tx++) {
      for (int ty = minTileY; ty <= maxTileY; ty++) {
        final tileImg = tileManager.getTile(tx, ty, zoom);
        final posX = (tx * tileSize - startX).roundToDouble();
        final posY = (ty * tileSize - startY).roundToDouble();

        if (tileImg != null) {
          canvas.drawImageRect(
            tileImg,
            Rect.fromLTWH(0, 0, tileImg.width.toDouble(), tileImg.height.toDouble()),
            Rect.fromLTWH(posX, posY, tileSize, tileSize),
            Paint(),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SatelliteMapPainter oldDelegate) {
    return oldDelegate.centerLatLng != centerLatLng || oldDelegate.zoom != zoom;
  }
}

// 5. Host & Kontrol Interaksi
class SatelliteMapScreen extends StatefulWidget {
  const SatelliteMapScreen({super.key});

  @override
  State<SatelliteMapScreen> createState() => _SatelliteMapScreenState();
}

class _SatelliteMapScreenState extends State<SatelliteMapScreen> {
  late final TileManager _tileManager;
  LatLng _center = const LatLng(-6.1754, 106.8272);
  int _zoom = 15;
  static const int _minZoom = 3;
  static const int _maxZoom = 18;

  bool _isActionActive = false;
  final TextEditingController _searchController = TextEditingController();

  double _baseScale = 1.0;
  Offset? _lastFocalPoint;

  @override
  void initState() {
    super.initState();
    _tileManager = TileManager();
  }

  @override
  void dispose() {
    _tileManager.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _clampCenterY(double pointY, int zoom, double screenHeight) {
    final totalMapHeight = 256.0 * math.pow(2.0, zoom);
    final halfScreen = screenHeight / 2.0;

    if (totalMapHeight <= screenHeight) {
      return totalMapHeight / 2.0;
    }

    final minY = halfScreen;
    final maxY = totalMapHeight - halfScreen;
    return pointY.clamp(minY, maxY);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = 1.0;
    _lastFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    // 2-Jari: Pinch to Zoom
    if (details.pointerCount >= 2) {
      final scaleDiff = details.scale - _baseScale;
      if (scaleDiff.abs() > 0.25) {
        int nextZoom = _zoom;
        if (scaleDiff > 0 && _zoom < _maxZoom) {
          nextZoom += 1;
        } else if (scaleDiff < 0 && _zoom > _minZoom) {
          nextZoom -= 1;
        }

        if (nextZoom != _zoom) {
          setState(() {
            _zoom = nextZoom;
            final curPt = Mercator.latLngToPoint(_center, _zoom.toDouble());
            final clampedY = _clampCenterY(curPt.dy, _zoom, size.height);
            _center = Mercator.pointToLatLng(curPt.dx, clampedY, _zoom.toDouble());
          });
          _baseScale = details.scale;
        }
      }
      return;
    }

    // 1-Jari: Pan
    if (details.pointerCount == 1 && _lastFocalPoint != null) {
      final dx = details.focalPoint.dx - _lastFocalPoint!.dx;
      final dy = details.focalPoint.dy - _lastFocalPoint!.dy;
      _lastFocalPoint = details.focalPoint;

      final currentPoint = Mercator.latLngToPoint(_center, _zoom.toDouble());
      final targetX = currentPoint.dx - dx;
      final targetY = _clampCenterY(currentPoint.dy - dy, _zoom, size.height);

      setState(() {
        _center = Mercator.pointToLatLng(targetX, targetY, _zoom.toDouble());
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
    _baseScale = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Canvas Peta Satelit
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: (details) => _onScaleUpdate(details, screenSize),
              onScaleEnd: _onScaleEnd,
              child: CustomPaint(
                painter: SatelliteMapPainter(
                  tileManager: _tileManager,
                  centerLatLng: _center,
                  zoom: _zoom,
                ),
                size: Size.infinite,
              ),
            ),
          ),

          // Bottom Bar (1:1 dengan CSS/HTML)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Row(
              children: [
                // Tombol (+) yang berotasi menjadi (x)
                _buildCircleButton(
                  onTap: () {
                    setState(() {
                      _isActionActive = !_isActionActive;
                    });
                  },
                  child: AnimatedRotation(
                    turns: _isActionActive ? 0.125 : 0.0, // 45 derajat (1/8 turn)
                    duration: const Duration(milliseconds: 250),
                    curve: const Cubic(0.4, 0, 0.2, 1),
                    child: CustomPaint(
                      size: const Size(18, 18),
                      painter: _PlusIconPainter(color: const Color(0xFF1A1A1A)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Tombol Maps
                _buildCircleButton(
                  onTap: () {
                    // Reset ke posisi awal Monas Jakarta
                    setState(() {
                      _center = const LatLng(-6.1754, 106.8272);
                      _zoom = 15;
                    });
                  },
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter: _PinIconPainter(color: const Color(0xFF1A1A1A)),
                  ),
                ),
                const SizedBox(width: 12),

                // Capsule Search Bar
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        CustomPaint(
                          size: const Size(18, 18),
                          painter: _SearchIconPainter(color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 14,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (query) {
                              FocusScope.of(context).unfocus();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Cari lokasi...',
                              hintStyle: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFE5E5E7),
        highlightColor: const Color(0xFFE5E5E7),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: child),
        ),
      ),
    );
  }
}

// 1:1 SVG Vector Painters
class _PlusIconPainter extends CustomPainter {
  final Color color;
  _PlusIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // SVG: line x1="12" y1="5" x2="12" y2="19"
    canvas.drawLine(Offset(w / 2, h * (5 / 24)), Offset(w / 2, h * (19 / 24)), paint);
    // SVG: line x1="5" y1="12" x2="19" y2="12"
    canvas.drawLine(Offset(w * (5 / 24), h / 2), Offset(w * (19 / 24), h / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PinIconPainter extends CustomPainter {
  final Color color;
  _PinIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final scaleX = w / 24.0;
    final scaleY = h / 24.0;

    // Path pin: M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z
    final path = Path();
    path.moveTo(21 * scaleX, 10 * scaleY);
    path.cubicTo(21 * scaleX, 17 * scaleY, 12 * scaleX, 23 * scaleY, 12 * scaleX, 23 * scaleY);
    path.cubicTo(12 * scaleX, 23 * scaleY, 3 * scaleX, 17 * scaleY, 3 * scaleX, 10 * scaleY);
    path.arcToPoint(
      Offset(21 * scaleX, 10 * scaleY),
      radius: Radius.circular(9 * scaleX),
      clockwise: true,
    );
    canvas.drawPath(path, paint);

    // Circle: cx="12" cy="10" r="3"
    canvas.drawCircle(Offset(12 * scaleX, 10 * scaleY), 3 * scaleX, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SearchIconPainter extends CustomPainter {
  final Color color;
  _SearchIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    // Circle: cx="11" cy="11" r="8"
    canvas.drawCircle(Offset(11 * scaleX, 11 * scaleY), 8 * scaleX, paint);

    // Line: x1="21" y1="21" x2="16.65" y2="16.65"
    canvas.drawLine(
      Offset(21 * scaleX, 21 * scaleY),
      Offset(16.65 * scaleX, 16.65 * scaleY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
