import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GpxImportedRoute {
  final String name;
  final List<Map<String, double>> points;

  const GpxImportedRoute({required this.name, required this.points});
}

/// GPX 1.1 ve KML rota içe/dışa aktarma servisi.
class GpxService {
  static String buildGpxXml(String routeName, List<Map<String, dynamic>> points) {
    final safeName = _escapeXml(routeName.isEmpty ? 'Rota+' : routeName);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<gpx version="1.1" creator="ROTA+ Mountaineering App" xmlns="http://www.topografix.com/GPX/1/1">')
      ..writeln('  <metadata>')
      ..writeln('    <name>$safeName</name>')
      ..writeln('    <time>$nowIso</time>')
      ..writeln('  </metadata>')
      ..writeln('  <trk>')
      ..writeln('    <name>$safeName</name>')
      ..writeln('    <trkseg>');

    for (final p in points) {
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble() ?? (p['lon'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final ele = (p['ele'] as num?)?.toDouble() ?? (p['alt'] as num?)?.toDouble();
      if (ele != null) {
        buffer.writeln('      <trkpt lat="${lat.toStringAsFixed(6)}" lon="${lng.toStringAsFixed(6)}"><ele>${ele.toStringAsFixed(1)}</ele></trkpt>');
      } else {
        buffer.writeln('      <trkpt lat="${lat.toStringAsFixed(6)}" lon="${lng.toStringAsFixed(6)}" />');
      }
    }

    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    return buffer.toString();
  }

  static Future<void> exportAndShareGpx(
    String routeName,
    List<Map<String, dynamic>> points,
  ) async {
    final xml = buildGpxXml(routeName, points);
    final dir = await getTemporaryDirectory();
    final sanitized = routeName
        .replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName = '${sanitized.isEmpty ? 'rotaplus_rota' : sanitized}.gpx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(xml);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '$routeName (GPX Rota)',
      text: 'ROTA+ üzerinden paylaşılan GPX parkur dosyası: $routeName',
    );
  }

  static Future<GpxImportedRoute?> pickAndParseRouteFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx', 'kml', 'xml'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;

    final raw = await File(path).readAsString();
    final fileName = result.files.single.name.replaceAll(RegExp(r'\.(gpx|kml|xml)$', caseSensitive: false), '');
    final parsed = parseRouteContent(raw, fallbackName: fileName);
    if (parsed.points.isEmpty) return null;
    return parsed;
  }

  static GpxImportedRoute parseRouteContent(String content, {String fallbackName = 'İçe Aktarılan Rota'}) {
    final nameMatch = RegExp(r'<name>\s*(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?\s*</name>', dotAll: true).firstMatch(content);
    final extractedName = nameMatch?.group(1)?.trim();
    final name = (extractedName != null && extractedName.isNotEmpty) ? extractedName : fallbackName;

    final points = <Map<String, double>>[];

    // 1. GPX trkpt / rtept / wpt
    final gpxPtRegex = RegExp(
      r'<(?:trkpt|rtept|wpt)\b[^>]*lat=["\x27]([^"\x27]+)["\x27][^>]*lon=["\x27]([^"\x27]+)["\x27][^>]*>',
      caseSensitive: false,
    );
    for (final m in gpxPtRegex.allMatches(content)) {
      final lat = double.tryParse(m.group(1) ?? '');
      final lng = double.tryParse(m.group(2) ?? '');
      if (lat != null && lng != null) {
        points.add({'lat': lat, 'lng': lng});
      }
    }

    // 2. Fallback: lon önce yazılmış GPX
    if (points.isEmpty) {
      final revRegex = RegExp(
        r'<(?:trkpt|rtept|wpt)\b[^>]*lon=["\x27]([^"\x27]+)["\x27][^>]*lat=["\x27]([^"\x27]+)["\x27][^>]*>',
        caseSensitive: false,
      );
      for (final m in revRegex.allMatches(content)) {
        final lng = double.tryParse(m.group(1) ?? '');
        final lat = double.tryParse(m.group(2) ?? '');
        if (lat != null && lng != null) {
          points.add({'lat': lat, 'lng': lng});
        }
      }
    }

    // 3. KML <coordinates>lng,lat[,alt] ...</coordinates>
    if (points.isEmpty) {
      final kmlRegex = RegExp(r'<coordinates>(.*?)</coordinates>', dotAll: true, caseSensitive: false);
      for (final m in kmlRegex.allMatches(content)) {
        final block = (m.group(1) ?? '').trim();
        for (final token in block.split(RegExp(r'\s+'))) {
          final parts = token.split(',');
          if (parts.length >= 2) {
            final lng = double.tryParse(parts[0].trim());
            final lat = double.tryParse(parts[1].trim());
            if (lat != null && lng != null) {
              points.add({'lat': lat, 'lng': lng});
            }
          }
        }
      }
    }

    return GpxImportedRoute(name: name, points: points);
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
