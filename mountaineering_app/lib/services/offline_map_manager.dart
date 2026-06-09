import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// OfflineTileProvider — flutter_map 7.x compatible
// ──────────────────────────────────────────────────────────────────────────────
class OfflineTileProvider extends TileProvider {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = (options.urlTemplate ??
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png')
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());

    return _CachedNetworkTileImage(
      url: url,
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
      dio: _dio,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _CachedNetworkTileImage — disk-cached ImageProvider
// ──────────────────────────────────────────────────────────────────────────────
class _CachedNetworkTileImage extends ImageProvider<_CachedNetworkTileImage> {
  const _CachedNetworkTileImage({
    required this.url,
    required this.z,
    required this.x,
    required this.y,
    required this.dio,
  });

  final String url;
  final int z, x, y;
  final Dio dio;

  @override
  Future<_CachedNetworkTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _CachedNetworkTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      informationCollector: () => [DiagnosticsProperty('URL', url)],
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await _fetchBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  Future<Uint8List> _fetchBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/map_tiles/$z/$x');
      await folder.create(recursive: true);
      final file = File('${folder.path}/$y.png');

      // Fresh cache (< 7 days)
      if (file.existsSync()) {
        final age = DateTime.now().difference(file.statSync().modified);
        if (age.inDays < 7) return file.readAsBytes();
      }

      // Download
      final res = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.statusCode == 200 && res.data != null) {
        final bytes = Uint8List.fromList(res.data!);
        await file.writeAsBytes(bytes);
        return bytes;
      }

      // Stale cache fallback
      if (file.existsSync()) return file.readAsBytes();
    } catch (e) {
      debugPrint('Tile fetch error: $e');
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/map_tiles/$z/$x/$y.png');
        if (file.existsSync()) return file.readAsBytes();
      } catch (_) {}
    }

    // 1×1 transparent PNG fallback
    return Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0,
      0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 15, 0, 0, 1, 1, 0, 5, 24,
      212, 141, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedNetworkTileImage &&
      z == other.z &&
      x == other.x &&
      y == other.y;

  @override
  int get hashCode => Object.hash(z, x, y);
}

// ──────────────────────────────────────────────────────────────────────────────
// OfflineMapManager — cache utilities
// ──────────────────────────────────────────────────────────────────────────────
class OfflineMapManager {
  static final Dio _dio = Dio();

  static Future<void> clearCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/map_tiles');
      if (d.existsSync()) await d.delete(recursive: true);
    } catch (e) {
      debugPrint('Cache clear error: $e');
    }
  }

  static Future<double> getCacheSizeMB() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final d = Directory('${dir.path}/map_tiles');
      if (!d.existsSync()) return 0.0;
      int total = 0;
      await for (final e in d.list(recursive: true)) {
        if (e is File) total += await e.length();
      }
      return total / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  static Future<void> preCacheArea({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int minZoom = 11,
    int maxZoom = 15,
    void Function(int done, int total)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final tiles = <List<int>>[];

    for (int z = minZoom; z <= maxZoom; z++) {
      final xMin = _lngToX(minLng, z);
      final xMax = _lngToX(maxLng, z);
      final yMin = _latToY(maxLat, z);
      final yMax = _latToY(minLat, z);
      for (int x = xMin; x <= xMax; x++) {
        for (int y = yMin; y <= yMax; y++) {
          tiles.add([z, x, y]);
        }
      }
    }

    int done = 0;
    for (final t in tiles) {
      try {
        final zz = t[0], xx = t[1], yy = t[2];
        final folder = Directory('${dir.path}/map_tiles/$zz/$xx');
        await folder.create(recursive: true);
        final file = File('${folder.path}/$yy.png');
        if (!file.existsSync()) {
          final res = await _dio.get<List<int>>(
            'https://tile.openstreetmap.org/$zz/$xx/$yy.png',
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.statusCode == 200 && res.data != null) {
            await file.writeAsBytes(Uint8List.fromList(res.data!));
          }
        }
      } catch (_) {}
      done++;
      onProgress?.call(done, tiles.length);
    }
  }

  static int _lngToX(double lng, int z) =>
      ((lng + 180.0) / 360.0 * (1 << z)).floor();

  static int _latToY(double lat, int z) {
    const pi = 3.141592653589793;
    final latRad = lat * pi / 180.0;
    final val = (1.0 - (latRad.clamp(-pi / 2 + 0.0001, pi / 2 - 0.0001).abs() == latRad.abs()
            ? (0.5 + (latRad / pi))
            : 0.5)) *
        (1 << z);
    return val.floor().clamp(0, (1 << z) - 1);
  }
}
