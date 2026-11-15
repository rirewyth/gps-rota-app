import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tactical_styles.dart';

class SummitPassportScreen extends StatefulWidget {
  const SummitPassportScreen({super.key});

  @override
  State<SummitPassportScreen> createState() => _SummitPassportScreenState();
}

class _SummitPassportScreenState extends State<SummitPassportScreen> {
  static const String _storageKey = 'pro_summit_passport_v1';
  final List<Map<String, dynamic>> _summits = [];
  bool _loading = true;
  bool _capturingGps = false;

  @override
  void initState() {
    super.initState();
    _loadSummits();
  }

  Future<void> _loadSummits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        _summits
          ..clear()
          ..addAll(list.map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSummits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_summits));
  }

  double get _maxAltitude {
    if (_summits.isEmpty) return 0;
    return _summits.fold<double>(
      0,
      (prev, e) => ((e['alt'] ?? 0) as num).toDouble() > prev ? ((e['alt'] ?? 0) as num).toDouble() : prev,
    );
  }

  String get _rankTitle {
    if (_summits.length >= 10 || _maxAltitude >= 4000) return 'EKSPEDİSYON ELİTİ';
    if (_summits.length >= 5 || _maxAltitude >= 3000) return 'ZİRVE KOMUTANI';
    if (_summits.length >= 2 || _maxAltitude >= 2000) return 'ALPINİST PRO';
    return 'KAŞİF ADAYI';
  }

  Future<void> _addSummitDialog() async {
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final altCtrl = TextEditingController();
    double? lat;
    double? lng;

    setState(() => _capturingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 6));
      lat = pos.latitude;
      lng = pos.longitude;
      altCtrl.text = pos.altitude.toStringAsFixed(0);
    } catch (_) {
      altCtrl.text = '2450';
    } finally {
      if (mounted) setState(() => _capturingGps = false);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TacticalStyles.kSurfaceLow,
        title: const Row(
          children: [
            Icon(Icons.flag_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Yeni Zirve Kaydı', style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: TacticalStyles.kOnSurface),
              decoration: const InputDecoration(
                labelText: 'Zirve / Tepe Adı',
                hintText: 'Örn: Erciyes Kuzey Kulvarı',
                labelStyle: TextStyle(color: TacticalStyles.kOnSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: altCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: TacticalStyles.kOnSurface),
              decoration: const InputDecoration(
                labelText: 'Rakım (m)',
                labelStyle: TextStyle(color: TacticalStyles.kOnSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: TacticalStyles.kOnSurface),
              decoration: const InputDecoration(
                labelText: 'Zirve Notu / Hava',
                hintText: 'Örn: Açık hava, 18 km/s rüzgar',
                labelStyle: TextStyle(color: TacticalStyles.kOnSurfaceVariant),
              ),
            ),
            if (lat != null && lng != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: const TextStyle(color: TacticalStyles.kTertiary, fontSize: 11),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              final title = nameCtrl.text.trim();
              if (title.isEmpty) return;
              final alt = double.tryParse(altCtrl.text.trim()) ?? 0;
              setState(() {
                _summits.insert(0, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': title,
                  'alt': alt,
                  'note': noteCtrl.text.trim(),
                  'lat': lat,
                  'lng': lng,
                  'date': DateTime.now().toIso8601String(),
                });
              });
              _saveSummits();
              Navigator.pop(ctx);
            },
            child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCertificate(Map<String, dynamic> summit) async {
    final certKey = GlobalKey();
    final dateStr = (summit['date'] ?? '').toString().split('T').first;
    final altStr = '${((summit['alt'] ?? 0) as num).toInt()} m';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TacticalStyles.kSurfaceLow,
        contentPadding: const EdgeInsets.all(14),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: certKey,
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF15181C), Color(0xFF0A0C0E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.7), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ROTA+ PRO',
                          style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('ZİRVE SERTİFİKASI', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      (summit['name'] ?? '').toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'RAKIM: $altStr',
                      style: const TextStyle(color: TacticalStyles.kTertiary, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    if ((summit['note'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summit['note'],
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TARİH: $dateStr', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        Text(_rankTitle, style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('PAYLAŞ', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final boundary = certKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                    if (boundary == null) return;
                    final img = await boundary.toImage(pixelRatio: 2.0);
                    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
                    img.dispose();
                    if (bytes == null) return;
                    final dir = await getTemporaryDirectory();
                    final file = File('${dir.path}/zirve_sertifikasi.png');
                    await file.writeAsBytes(bytes.buffer.asUint8List());
                    await Share.shareXFiles([XFile(file.path)], text: '${summit['name']} ($altStr) - ROTA+ Zirve Sertifikası');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ZİRVE PASAPORTU PRO',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        onPressed: _capturingGps ? null : _addSummitDialog,
        icon: _capturingGps
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.add_location_alt_rounded),
        label: Text(_capturingGps ? 'GPS ALINIYOR...' : 'ZİRVE KAYDET', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // Pasaport Başlık Kartı
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 16,
                    borderColor: Colors.amber.withOpacity(0.45),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ALPINİST KİMLİĞİ', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(_rankTitle, style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOPLAM ZİRVE', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text('${_summits.length}', style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 22, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('EN YÜKSEK RAKIM', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10)),
                                const SizedBox(height: 2),
                                Text('${_maxAltitude.toInt()} m', style: const TextStyle(color: TacticalStyles.kTertiary, fontSize: 22, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'KAYITLI ZİRVELER & SERTİFİKALAR',
                  style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                if (_summits.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: TacticalStyles.glassCardDecoration(radius: 14),
                    child: const Column(
                      children: [
                        Icon(Icons.landscape_rounded, color: TacticalStyles.kOutline, size: 42),
                        SizedBox(height: 10),
                        Text(
                          'Henüz kayıtlı zirve yok.\nZirveye ulaştığınızda sağ alttan GPS konumunuzla kaydedip sertifika oluşturabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ..._summits.map((s) {
                    final dateStr = (s['date'] ?? '').toString().split('T').first;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: TacticalStyles.glassCardDecoration(radius: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.flag_rounded, color: Colors.amber),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s['name'] ?? '', style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 14, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '${((s['alt'] ?? 0) as num).toInt()} m • $dateStr',
                                  style: const TextStyle(color: TacticalStyles.kTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sertifika Paylaş',
                            icon: const Icon(Icons.card_membership_rounded, color: Colors.amber),
                            onPressed: () => _shareCertificate(s),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
