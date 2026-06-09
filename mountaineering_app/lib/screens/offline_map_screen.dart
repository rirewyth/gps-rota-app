import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import '../services/offline_map_manager.dart';
import '../services/premium_service.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kOrange = Color(0xFFFF6B00);
const Color kHeaderBg = Colors.black;

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({Key? key}) : super(key: key);

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  fm.MapController _mapController = fm.MapController();
  mbx.MapboxMap? _mapboxMap;
  bool _isDownloading = false;
  double _progress = 0;
  String _statusTxt = "Ekranda gördüğünüz bölgeyi indirebilirsiniz.";

  Future<void> _startDownload() async {
    final isPrem = await PremiumService.isPremium();
    if (!isPrem) {
      if (!mounted) return;
      PremiumService.showPremiumRequired(context, 'Çevrimdışı Harita İndirme');
      return;
    }

    // Mapbox Offline Manager entegrasyonu gelecek
    // Şimdilik bounds alma simülasyonu
    final cameraState = await _mapboxMap?.getCameraState();
    if (cameraState == null) return;
    
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _statusTxt = "İndirme başlıyor...";
    });
    
    await OfflineMapManager.preCacheArea(
      minLat: cameraState.center.coordinates.lat?.toDouble() ?? 39.0, // Örnek
      maxLat: (cameraState.center.coordinates.lat?.toDouble() ?? 39.0) + 0.1,
      minLng: cameraState.center.coordinates.lng?.toDouble() ?? 35.0,
      maxLng: (cameraState.center.coordinates.lng?.toDouble() ?? 35.0) + 0.1,
      minZoom: 11,
      maxZoom: 15,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _progress = done / total;
          _statusTxt = "%${(_progress * 100).toInt()} ($done / $total)";
        });
      }
    );
    
    if (!mounted) return;
    setState(() {
      _isDownloading = false;
      _progress = 1.0;
      _statusTxt = "İndirme Tamamlandı! Harita Çevrimdışı Çalışacak.";
    });
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Bölge çevrimdışı kullanım için kalıcı olarak kaydedildi!'),
      backgroundColor: Colors.green.shade800,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Çevrimdışı Harita Yönetimi', style: GoogleFonts.outfit(color: kOrange, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: kHeaderBg,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          mbx.MapWidget(
            key: const ValueKey("offline_mapbox"),
            onMapCreated: (map) => _mapboxMap = map,
            styleUri: mbx.MapboxStyles.OUTDOORS,
            cameraOptions: mbx.CameraOptions(
              center: mbx.Point(coordinates: mbx.Position(35.0, 39.0)),
              zoom: 6.0,
            ),
          ),
          // İndirilecek hedef bölge overlay
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  border: Border.all(color: kOrange, width: 3),
                  color: kOrange.withOpacity(0.05),
                ),
              ),
            ),
          ),
          
          if (_isDownloading)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(value: _progress, color: kOrange, backgroundColor: Colors.white24),
                      const SizedBox(height: 20),
                      Text("Harita İndiriliyor...", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_statusTxt, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
            
          if (!_isDownloading)
            Positioned(
              bottom: 30, left: 20, right: 20,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 8,
                ),
                onPressed: _startDownload,
                icon: const Icon(Icons.file_download, size: 24),
                label: const Text(
                  'BAKIŞ AÇISINDAKİ ALANI İNDİR',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                ),
              ),
            ),
            
          if (!_isDownloading)
            Positioned(
              top: 10, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  "Turuncu çerçevenin içindeki bölge seçilecektir. Aşırı yakınlaştırma çok fazla yer kaplayabilir.",
                  style: GoogleFonts.shareTechMono(color: Colors.amber, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
