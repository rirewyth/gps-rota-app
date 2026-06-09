import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/peak_model.dart';
import '../services/overpass_service.dart';

class PeakARScreen extends StatefulWidget {
  const PeakARScreen({Key? key}) : super(key: key);

  @override
  State<PeakARScreen> createState() => _PeakARScreenState();
}

class _PeakARScreenState extends State<PeakARScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  // Sensör verileri
  double _heading = 0.0;
  double _pitch = 0.0; // yukarı/aşağı eğim
  Position? _currentPosition;

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  List<PeakModel> _peaks = [];
  bool _isLoading = true;

  // Kamera tahmini görüş açıları (Derece)
  final double _fovHorizontal = 60.0;
  final double _fovVertical = 45.0;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    // 1. Kamera Başlat
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Kamera hatası: $e");
    }

    // 2. Konum Al ve Dağları Çek
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        
        // Dağları çek
        final peaks = await OverpassService.getNearbyPeaks(
          _currentPosition!.latitude, 
          _currentPosition!.longitude,
          radius: 40000, // 40km
        );
        
        if (mounted) {
          setState(() {
            _peaks = peaks;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Konum/Dağ çekme hatası: $e");
      setState(() => _isLoading = false);
    }

    // 3. Pusula Dinle
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && mounted) {
        setState(() {
          _heading = event.heading!;
        });
      }
    });

    // 4. İvmeölçer Dinle (Pitch/Tilt bulmak için)
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Y ekseni yerçekimi: Cihaz dik tutulduğunda y=9.8, x=0, z=0
      // Cihazı yukarı eğdiğimizde z azalır, y değişir.
      // Basit pitch hesabı (radyandan dereceye):
      double p = math.atan2(event.z, event.y) * (180 / math.pi);
      // Kamera dik tutulurken pitch ~0 olmalı. 
      // (Burası cihaza göre değişebilir, basit bir kalibrasyon)
      
      if (mounted) {
        setState(() {
          _pitch = p;
        });
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _compassSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  /// İki açı arasındaki en kısa farkı (-180 ile 180 arasında) bulur
  double _getAngleDiff(double a, double b) {
    double diff = a - b;
    while (diff < -180) diff += 360;
    while (diff > 180) diff -= 360;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 16),
              Text('Kamera / Sensörler Başlatılıyor...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kamera Görüntüsü
          SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: CameraPreview(_cameraController!),
          ),

          // Nişangah (Merkez)
          Center(
            child: Container(
              width: 2, height: 20,
              color: Colors.orange.withOpacity(0.5),
            ),
          ),
          Center(
            child: Container(
              width: 20, height: 2,
              color: Colors.orange.withOpacity(0.5),
            ),
          ),

          // Dağ İsimlerini Çiz
          if (_currentPosition != null && _peaks.isNotEmpty)
            ..._peaks.map((peak) {
              // 1. Bearing (Hedef Açı) Hesapla
              double bearing = Geolocator.bearingBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                peak.latitude,
                peak.longitude,
              );
              // Bearing negatifse 0-360 arasına al
              if (bearing < 0) bearing += 360;

              // 2. Yatay Açı Farkı (Cihazın baktığı yön ile dağ yönü)
              double hDiff = _getAngleDiff(bearing, _heading);

              // 3. Hedef Yükseklik Açısı (Pitch) Hesapla
              double distance = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                peak.latitude,
                peak.longitude,
              );
              
              // Basit bir dik üçgen ile yükseklik açısı (dünya eğimi ihmal edilmiştir)
              double currentAlt = _currentPosition!.altitude > 0 ? _currentPosition!.altitude : 100.0;
              double altDiff = peak.elevation - currentAlt;
              double targetPitch = math.atan2(altDiff, distance) * (180 / math.pi);

              // 4. Dikey Açı Farkı
              double vDiff = targetPitch - _pitch;

              // Eğer görüş alanının (FOV) çok dışındaysa hiç çizme (Performans için)
              if (hDiff.abs() > _fovHorizontal || vDiff.abs() > _fovVertical) {
                return const SizedBox();
              }

              // 5. Ekran X, Y Koordinatları
              // Ekranın merkezi (0,0) açı farkıdır.
              double x = (screenSize.width / 2) + (hDiff / (_fovHorizontal / 2)) * (screenSize.width / 2);
              // Y ekseni yukarı doğru negatif, aşağı doğru pozitiftir.
              double y = (screenSize.height / 2) - (vDiff / (_fovVertical / 2)) * (screenSize.height / 2);

              return Positioned(
                left: x - 60, // Ortalama için
                top: y - 20,
                child: Column(
                  children: [
                    Text(
                      '⛰ ${peak.name}',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${peak.elevation}m • ${(distance / 1000).toStringAsFixed(1)}km',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.orangeAccent,
                        fontSize: 10,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Container(
                      width: 2, height: 10,
                      color: Colors.white.withOpacity(0.5),
                    )
                  ],
                ),
              );
            }).toList(),

          // Üst Bilgi Barı
          Positioned(
            top: 50, left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Text(
                    'Pusula: ${_heading.toStringAsFixed(0)}°',
                    style: GoogleFonts.shareTechMono(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Yükleniyor Uyarısı
          if (_isLoading)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text('Çevredeki Zirveler Taranıyor...', style: GoogleFonts.shareTechMono(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            
          // Toplam Dağ Sayısı
          if (!_isLoading && _peaks.isNotEmpty)
             Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_peaks.length} Dağ/Tepe Tespit Edildi', style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
