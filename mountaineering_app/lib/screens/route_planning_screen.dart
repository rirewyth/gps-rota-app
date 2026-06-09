import 'dart:async';
import 'package:mountaineering_app/screens/route_flyover_screen.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

import '../database_helper.dart';
import '../utils/location_permission_helper.dart';
import '../data/mountain_database.dart';
import '../services/routing_service.dart';
import '../services/premium_service.dart';
import '../main.dart';
import 'dart:math';

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);
const Color kGreen = Color(0xFF62FF4C);

class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({Key? key}) : super(key: key);

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late TabController _tabController;

  // Rota planlama
  List<LatLng> _planNoktalar = [];
  bool _planlamaAktif = false;
  double _toplamMesafe = 0;
  bool _haritaHazir = false;

  // Baslangic / Bitis secimi
  List<Map<String, dynamic>> _waypoints = [
    {'name': '', 'konum': null},
    {'name': '', 'konum': null},
  ];
  int _secilenIndex = 0;
  
  double _elevationGain = 0;
  double _maxElevation = 0;
  double _averageElevation = 0; // true = baslangic, false = bitis

  // Mevcut konum
  LatLng? _mevcutKonum;
  bool _konumYukleniyor = false;

  // Kayitli rotalar
  List<Map<String, dynamic>> _kayitliRotalar = [];
  bool _rotaYukleniyor = false;

  // Arama state'i
  List<LocationSearchResult> _aramaSonuclari = [];
  bool _aramaYukleniyor = false;
  final TextEditingController _aramaController = TextEditingController();

  // Premium Harita Katmanları
  String _selectedMapLayer = 'Topografik';
  String _mapTileUrl = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _konumGetir();
    _rotaListesiYukle();
    DatabaseHelper.rotaUpdateNotifier.addListener(_onRotaUpdate);
  }

  void _onRotaUpdate() {
    if (mounted) _rotaListesiYukle();
  }

  @override
  void dispose() {
    DatabaseHelper.rotaUpdateNotifier.removeListener(_onRotaUpdate);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _konumGetir() async {
    setState(() => _konumYukleniyor = true);
    try {
      bool gpsAcik = await Geolocator.isLocationServiceEnabled();
      if (!gpsAcik) {
        setState(() => _konumYukleniyor = false);
        return;
      }
      LocationPermission izin = await LocationPermissionHelper.checkAndRequestLocationPermission(context);
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        setState(() => _konumYukleniyor = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _mevcutKonum = LatLng(pos.latitude, pos.longitude);
          _konumYukleniyor = false;
        });
        if (_haritaHazir) {
          try {
            _mapController.move(_mevcutKonum!, 13.0);
          } catch (_) {}
        }
      }
    } catch (_) {
      if (mounted) setState(() => _konumYukleniyor = false);
    }
  }

  Future<void> _rotaListesiYukle() async {
    setState(() => _rotaYukleniyor = true);
    final rotalar = await DatabaseHelper.instance.tumRotalarGetir();
    if (mounted) {
      setState(() {
        _kayitliRotalar = rotalar;
        _rotaYukleniyor = false;
      });
    }
  }

  void _haritaTiklandi(TapPosition tap, LatLng nokta) {
    if (!_planlamaAktif) return;
    setState(() {
      _waypoints[_secilenIndex]['konum'] = nokta;
      _waypoints[_secilenIndex]['name'] = '${nokta.latitude.toStringAsFixed(4)}, ${nokta.longitude.toStringAsFixed(4)}';
      
      if (_secilenIndex < _waypoints.length - 1) {
        _secilenIndex++;
        _notify('${_secilenIndex}. nokta belirlendi. Şimdi sonraki noktayı seçin.');
      } else {
        _rotaHesaplaVeCiz();
      }
    });
  }

  Future<void> _rotaHesaplaVeCiz() async {
    // Check if at least 2 waypoints are set
    final validWaypoints = _waypoints.where((w) => w['konum'] != null).map((w) => w['konum'] as LatLng).toList();
    if (validWaypoints.length < 2) {
      setState(() {
        _planNoktalar = [];
        _toplamMesafe = 0;
        _elevationGain = 0;
        _maxElevation = 0;
        _averageElevation = 0;
      });
      return;
    }
    
    // Geçici olarak düz çizgi göster
    setState(() {
      _planNoktalar = validWaypoints;
      _hesaplaMesafe();
    });

    final routeData = await RoutingService.getRoute(validWaypoints);
    
    if (mounted) {
      setState(() {
        if (routeData != null) {
          _planNoktalar = routeData.coordinates;
          _toplamMesafe = routeData.distance;
          _elevationGain = routeData.elevationGain;
          _maxElevation = routeData.maxElevation;
          _averageElevation = routeData.averageElevation;
          _notify('Yol tarifi başarıyla oluşturuldu.');
        } else {
          _planNoktalar = validWaypoints;
          _hesaplaMesafe();
        }
        _planlamaAktif = false;
        _secilenIndex = 0;
      });
      if (routeData != null && _haritaHazir && validWaypoints.isNotEmpty) {
        try {
          _mapController.move(validWaypoints.first, 12.0);
        } catch (_) {}
      }
    }
  }

  void _hesaplaMesafe() {
    double mesafe = 0;
    for (int i = 0; i < _planNoktalar.length - 1; i++) {
      mesafe += Geolocator.distanceBetween(
        _planNoktalar[i].latitude, _planNoktalar[i].longitude,
        _planNoktalar[i + 1].latitude, _planNoktalar[i + 1].longitude,
      );
    }
    setState(() => _toplamMesafe = mesafe);
  }

  void _dagSecKonum(Mountain dag) {
    final latLng = LatLng(dag.lat, dag.lng);
    setState(() {
      _waypoints[_secilenIndex]['konum'] = latLng;
      _waypoints[_secilenIndex]['name'] = dag.name;
      
      if (_secilenIndex < _waypoints.length - 1) {
        _secilenIndex++;
      } else {
        _rotaHesaplaVeCiz();
      }
    });
    try {
      _mapController.move(latLng, 11.0);
    } catch (_) {}
    Navigator.pop(context);
  }

  void _konumSecSonuc(LocationSearchResult sonuc) {
    final latLng = LatLng(sonuc.lat, sonuc.lon);
    setState(() {
      _waypoints[_secilenIndex]['konum'] = latLng;
      _waypoints[_secilenIndex]['name'] = sonuc.displayName.split(',').first;
      
      if (_secilenIndex < _waypoints.length - 1) {
        _secilenIndex++;
      } else {
        _rotaHesaplaVeCiz();
      }
    });
    try {
      _mapController.move(latLng, 13.0);
    } catch (_) {}
    Navigator.pop(context);
  }

  void _mevcutKonumuKullan() {
    if (_mevcutKonum == null) {
      _notify('GPS konumu henüz alınamadı!', hata: true);
      return;
    }
    setState(() {
      _waypoints[_secilenIndex]['konum'] = _mevcutKonum;
      _waypoints[_secilenIndex]['name'] = 'Mevcut Konumum';
      
      if (_secilenIndex < _waypoints.length - 1) {
        _secilenIndex++;
      } else {
        _rotaHesaplaVeCiz();
      }
    });
    Navigator.pop(context);
  }

  void _rotaKaydet() async {
    final validWaypoints = _waypoints.where((w) => w['konum'] != null).toList();
    if (validWaypoints.length < 2) {
      _notify('En az 2 nokta (başlangıç ve bitiş) seçin!', hata: true);
      return;
    }

    // PREMIUM KONTROL - 10 Rota Sınırı
    final isPrem = await PremiumService.isPremium();
    if (!isPrem && _kayitliRotalar.length >= 10) {
      if (!mounted) return;
      PremiumService.showPremiumRequired(context, 'Limitsiz Rota Kaydedici (Şu an max 10 rota)');
      return;
    }

    final String bAdi = validWaypoints.first['name'];
    final String bBiti = validWaypoints.last['name'];

    final isimController = TextEditingController(
      text: bAdi.isNotEmpty && bBiti.isNotEmpty
          ? '$bAdi → $bBiti'
          : 'Rota ${DateTime.now().day}.${DateTime.now().month}',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Rotayı Kaydet',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black38,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.trip_origin, color: kGreen, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(bAdi,
                        style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  ]),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.more_vert, color: Colors.white24, size: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.flag, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(bBiti,
                        style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Rota Adı:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: isimController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF0A0A0A),
                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mesafe: ${_toplamMesafe > 1000 ? '${(_toplamMesafe / 1000).toStringAsFixed(2)} km' : '${_toplamMesafe.toInt()} m'}',
              style: const TextStyle(color: kOrange, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () async {
              final isim = isimController.text.trim().isEmpty
                  ? '$bAdi → $bBiti'
                  : isimController.text.trim();

              final noktalarMap = _planNoktalar.map((p) => {
                    'lat': p.latitude,
                    'lng': p.longitude,
                  }).toList();

              await DatabaseHelper.instance.rotaKaydet(
                isim,
                noktalarMap,
                baslangicAdi: bAdi,
                bitisAdi: bBiti,
                distance: _toplamMesafe,
                durationSeconds: 0,
                elevationGain: _elevationGain,
                maxAltitude: _maxElevation,
                steps: 0,
                source: 'planned',
              );
              // Yeni kaydedilen rotayı aktif yap
              final rotalar = await DatabaseHelper.instance.tumRotalarGetir();
              if (rotalar.isNotEmpty) {
                await DatabaseHelper.instance.rotayiAktifYap(rotalar.first['id']);
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final List<Map<String, dynamic>> coords = _planNoktalar.length > 150
                      ? List.generate(150, (i) {
                          final idx = (i * (_planNoktalar.length - 1) / 149).round();
                          return {'lat': _planNoktalar[idx].latitude, 'lng': _planNoktalar[idx].longitude};
                        })
                      : _planNoktalar.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();

                  await FirebaseFirestore.instance
                      .collection('users').doc(user.uid).collection('routes').add({
                    'name': isim,
                    'from': bAdi,
                    'to': bBiti,
                    'distance': _toplamMesafe,
                    'coordinates': coords,
                    'pointCount': _planNoktalar.length,
                    'elevation_gain': _elevationGain,
                    'max_altitude': _maxElevation,
                    'duration_seconds': 0,
                    'steps': 0,
                    'source': 'planned',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
              } catch (_) {} 

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _rotaListesiYukle();
              _notify('✓ "$isim" rotasi kaydedildi!');
            },
            child: const Text('KAYDET',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _rotaSil(int id) async {
    // Eğer silinen rota aktifse, notifier'u tetikle
    final rota = _kayitliRotalar.firstWhere(
      (r) => r['id'] == id,
      orElse: () => {},
    );
    await DatabaseHelper.instance.rotaSil(id);
    if (rota['aktif'] == true) {
      DatabaseHelper.rotaUpdateNotifier.value++;
    }
    await _rotaListesiYukle();
    _notify('Rota silindi.');
  }

  void _showMapLayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Harita Katmanı Seçimi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildLayerOption('Topografik (PRO)', 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', Icons.terrain, false),
              const SizedBox(height: 8),
              _buildLayerOption('Outdoor (Patika)', 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png', Icons.hiking, false),
              const SizedBox(height: 8),
              _buildLayerOption('Uydu Görünümü', 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', Icons.satellite_alt, true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerOption(String name, String url, IconData icon, bool requiresPremium) {
    bool isSelected = _selectedMapLayer == name;
    return ListTile(
      tileColor: isSelected ? kOrange.withOpacity(0.1) : Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? kOrange : Colors.white10),
      ),
      leading: Icon(icon, color: isSelected ? kOrange : Colors.white54),
      title: Text(name, style: TextStyle(color: isSelected ? kOrange : Colors.white, fontWeight: FontWeight.bold)),
      trailing: requiresPremium
          ? const Icon(Icons.stars, color: Colors.amber, size: 20)
          : null,
      onTap: () async {
        Navigator.pop(context);
        if (requiresPremium) {
          final isPrem = await PremiumService.isPremium();
          if (!isPrem) {
             if (!mounted) return;
             PremiumService.showPremiumRequired(context, 'Gelişmiş İzohips ve Uydu Katmanları');
             return;
          }
        }
        setState(() {
          _selectedMapLayer = name;
          _mapTileUrl = url;
        });
      },
    );
  }

  Future<void> _shareRouteToFeed(Map<String, dynamic> rota) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _notify('Paylasmak icin giris yapin!', hata: true); return; }

    final nameCtrl = TextEditingController(text: rota['isim'] ?? '');
    final descCtrl = TextEditingController();
    
    final double distanceVal = (rota['distance'] ?? 0.0).toDouble();
    final distStr = distanceVal > 1000
        ? '${(distanceVal / 1000).toStringAsFixed(2)} km'
        : '${distanceVal.toInt()} m';

    final List pointsList = rota['noktalar'] is List ? rota['noktalar'] : [];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.route, color: kGreen, size: 22),
          SizedBox(width: 8),
          Text('Rotayi Paylas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGreen.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((rota['baslangic_adi'] ?? '').isNotEmpty)
                Row(children: [const Icon(Icons.trip_origin, color: kGreen, size: 12), const SizedBox(width: 6),
                  Expanded(child: Text(rota['baslangic_adi'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))]),
              if ((rota['bitis_adi'] ?? '').isNotEmpty) ...[const SizedBox(height: 4),
                Row(children: [const Icon(Icons.flag, color: Colors.redAccent, size: 12), const SizedBox(width: 6),
                  Expanded(child: Text(rota['bitis_adi'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))])],
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _buildRouteStat('Mesafe', distStr, Icons.straighten),
                _buildRouteStat('Waypoint', '${pointsList.length}', Icons.location_on),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _buildRouteStat('Rakım K.', '+${(rota['elevation_gain'] ?? 0.0).toInt()}m', Icons.trending_up),
                _buildRouteStat('Max İrt.', '${(rota['max_altitude'] ?? 0.0).toInt()}m', Icons.landscape),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Rota Adi (ör: Bolu Ormani Turu)',
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true, fillColor: Colors.black,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kOrange)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Aciklama ekle... (istege bagli)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: Colors.black,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kGreen)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('IPTAL', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('PAYLAS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Kullanici';
      final userEmail = userDoc.data()?['email'] ?? '';
      final isPremium = userDoc.data()?['is_premium'] ?? false;

      final List<Map<String, dynamic>> coords = pointsList.length > 100
          ? List.generate(100, (i) {
              final idx = (i * (pointsList.length - 1) / 99).round();
              final pt = pointsList[idx];
              return {'lat': pt['lat'], 'lng': pt['lng']};
            })
          : pointsList.map((pt) => {'lat': pt['lat'], 'lng': pt['lng']}).toList();

      final routeName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : (rota['isim'] ?? 'Rota');

      await FirebaseFirestore.instance.collection('posts').add({
        'user': userName, 'userEmail': userEmail, 'userId': user.uid, 'isPremium': isPremium,
        'desc': descCtrl.text.trim(), 'imageUrl': '', 'likes': [], 'postType': 'route',
        'routeData': {
          'name': routeName,
          'from': rota['baslangic_adi'] ?? '',
          'to': rota['bitis_adi'] ?? '',
          'distance': distanceVal,
          'pointCount': pointsList.length,
          'coordinates': coords,
          'duration_seconds': rota['duration_seconds'] ?? 0,
          'elevation_gain': rota['elevation_gain'] ?? 0.0,
          'max_altitude': rota['max_altitude'] ?? 0.0,
          'steps': rota['steps'] ?? 0,
          'source': rota['source'] ?? '',
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      _notify('Rota akisa paylasildi!');
    } catch (e) {
      _notify('Hata: $e', hata: true);
    }
  }

  Widget _buildRouteStat(String label, String value, IconData icon) {
    return Column(children: [
      Icon(icon, color: kGreen, size: 16),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }

  void _rotayiAktifYap(int id, String isim) async {
    await DatabaseHelper.instance.rotayiAktifYap(id);
    await _rotaListesiYukle();
    _notify('✓ "$isim" aktif rota olarak seçildi!');
  }

  void _notify(String msg, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(hata ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: hata ? Colors.red.shade900 : const Color(0xFF43A047),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // Aktif filtre kategorisi
  String _aktifFiltre = 'TÜMÜ';

  String _sonucKategorisi(sonuc) {
    if (sonuc.type == 'peak' || sonuc.type == 'mountain' || sonuc.type == 'hill' ||
        sonuc.type == 'ridge' || sonuc.type == 'volcano' || sonuc.type == 'cliff' ||
        sonuc.type == 'saddle' || sonuc.type == 'glacier') return 'ZİRVE';
    if (sonuc.type == 'forest' || sonuc.type == 'wood' || sonuc.type == 'national_park' ||
        sonuc.type == 'nature_reserve' || sonuc.category == 'natural' && sonuc.type != 'peak') return 'DOĞA';
    if (sonuc.type == 'village' || sonuc.type == 'hamlet' || sonuc.type == 'town' ||
        sonuc.type == 'city' || sonuc.type == 'suburb') return 'YERLEŞİM';
    if (sonuc.type == 'alpine_hut' || sonuc.type == 'camp_site' || sonuc.type == 'viewpoint' ||
        sonuc.type == 'wilderness_hut') return 'KAMP';
    if (sonuc.type == 'lake' || sonuc.type == 'river' || sonuc.type == 'waterfall' ||
        sonuc.type == 'spring') return 'SU';
    return 'DİĞER';
  }

  void _konumSecDiyalogu() {
    _aramaController.clear();
    _aramaSonuclari = [];
    _aramaYukleniyor = false;
    _aktifFiltre = 'TÜMÜ';

    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Filtrelenmiş sonuçlar
          final filtrelenmis = _aktifFiltre == 'TÜMÜ'
              ? _aramaSonuclari
              : _aramaSonuclari.where((s) => _sonucKategorisi(s) == _aktifFiltre).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (ctx, sc) => Column(
              children: [
                // ── Başlık ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      bottom: BorderSide(
                        color: _secilenIndex == 0 ? kGreen : (_secilenIndex == _waypoints.length - 1 ? Colors.redAccent : kOrange),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_secilenIndex == 0 ? kGreen : (_secilenIndex == _waypoints.length - 1 ? Colors.redAccent : kOrange)).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _secilenIndex == 0 ? Icons.trip_origin : (_secilenIndex == _waypoints.length - 1 ? Icons.flag : Icons.location_on),
                          color: _secilenIndex == 0 ? kGreen : (_secilenIndex == _waypoints.length - 1 ? Colors.redAccent : kOrange),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _secilenIndex == 0 ? 'BAŞLANGIÇ NOKTASI' : (_secilenIndex == _waypoints.length - 1 ? 'HEDEF NOKTA' : 'ARA NOKTA ${_secilenIndex}'),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            _secilenIndex == 0 ? 'Nereden çıkacaksınız?' : 'Hedefiniz neresi?',
                            style: TextStyle(
                              color: _secilenIndex == 0 ? kGreen : (_secilenIndex == _waypoints.length - 1 ? Colors.redAccent : kOrange),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // ── Arama Çubuğu ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  color: const Color(0xFF111111),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kOrange.withOpacity(0.4)),
                          ),
                          child: TextField(
                            controller: _aramaController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            autofocus: false,
                            onChanged: (val) async {
                              if (val.length > 2) {
                                setModalState(() {
                                  _aramaYukleniyor = true;
                                  _aktifFiltre = 'TÜMÜ';
                                });
                                final sonuclar = await RoutingService.searchLocation(val);
                                setModalState(() {
                                  _aramaSonuclari = sonuclar;
                                  _aramaYukleniyor = false;
                                });
                              } else if (val.isEmpty) {
                                setModalState(() {
                                  _aramaSonuclari = [];
                                  _aramaYukleniyor = false;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Dağ, zirve, köy veya konum ara...',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                              prefixIcon: _aramaYukleniyor
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18, height: 18,
                                        child: CircularProgressIndicator(color: kOrange, strokeWidth: 2),
                                      ),
                                    )
                                  : const Icon(Icons.search, color: kOrange, size: 22),
                              suffixIcon: _aramaController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                      onPressed: () => setModalState(() {
                                        _aramaController.clear();
                                        _aramaSonuclari = [];
                                      }),
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Filtre Etiketleri ────────────────────────────────
                if (_aramaSonuclari.isNotEmpty)
                  Container(
                    height: 40,
                    color: const Color(0xFF111111),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final filtre in ['TÜMÜ', 'ZİRVE', 'DOĞA', 'YERLEŞİM', 'KAMP', 'SU', 'DİĞER'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setModalState(() => _aktifFiltre = filtre),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _aktifFiltre == filtre ? kOrange : Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _aktifFiltre == filtre ? kOrange : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  filtre,
                                  style: TextStyle(
                                    color: _aktifFiltre == filtre ? Colors.black : Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // ── Liste ──────────────────────────────────────────
                Expanded(
                  child: ListView(
                    controller: sc,
                    padding: EdgeInsets.zero,
                    children: [
                      // Arama Sonuçları
                      if (filtrelenmis.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            children: [
                              const Text('SONUÇLAR',
                                  style: TextStyle(color: kOrange, fontSize: 10,
                                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              const Spacer(),
                              Text('${filtrelenmis.length} yer bulundu',
                                  style: const TextStyle(color: Colors.white24, fontSize: 10)),
                            ],
                          ),
                        ),
                        ...filtrelenmis.map((sonuc) {
                          final kategori = _sonucKategorisi(sonuc);
                          IconData ikon;
                          Color ikonRenk;
                          Color badgeRenk;

                          switch (kategori) {
                            case 'ZİRVE':
                              ikon = Icons.landscape;
                              ikonRenk = kOrange;
                              badgeRenk = kOrange;
                              break;
                            case 'DOĞA':
                              ikon = Icons.park_outlined;
                              ikonRenk = kGreen;
                              badgeRenk = kGreen;
                              break;
                            case 'YERLEŞİM':
                              ikon = Icons.location_city_outlined;
                              ikonRenk = Colors.lightBlueAccent;
                              badgeRenk = Colors.lightBlueAccent;
                              break;
                            case 'KAMP':
                              ikon = Icons.festival_outlined;
                              ikonRenk = Colors.amberAccent;
                              badgeRenk = Colors.amberAccent;
                              break;
                            case 'SU':
                              ikon = Icons.water_outlined;
                              ikonRenk = Colors.cyan;
                              badgeRenk = Colors.cyan;
                              break;
                            default:
                              ikon = Icons.place_outlined;
                              ikonRenk = Colors.white38;
                              badgeRenk = Colors.white24;
                          }
                          
                          return ListTile(
                            onTap: () => _konumSecSonuc(sonuc),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (sonuc.category == 'google' ? Colors.blue : (sonuc.category == 'yandex' ? Colors.red : ikonRenk)).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                sonuc.category == 'google' ? Icons.search : (sonuc.category == 'yandex' ? Icons.location_searching : ikon),
                                color: sonuc.category == 'google' ? Colors.blueAccent : (sonuc.category == 'yandex' ? Colors.redAccent : ikonRenk),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sonuc.displayName.split(',').first,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (sonuc.category == 'google')
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('GOOGLE', style: TextStyle(color: Colors.blueAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                                  )
                                else if (sonuc.category == 'yandex')
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('YANDEX', style: TextStyle(color: Colors.redAccent, fontSize: 7, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              sonuc.displayName.split(',').skip(1).join(',').trim(),
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (sonuc.category == 'google' ? Colors.blue : (sonuc.category == 'yandex' ? Colors.red : badgeRenk)).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: (sonuc.category == 'google' ? Colors.blue : (sonuc.category == 'yandex' ? Colors.red : badgeRenk)).withOpacity(0.3)),
                              ),
                              child: Text(
                                sonuc.category == 'google' ? 'LOKASYON' : (sonuc.category == 'yandex' ? 'BÖLGE' : kategori),
                                style: TextStyle(color: sonuc.category == 'google' ? Colors.blueAccent : (sonuc.category == 'yandex' ? Colors.redAccent : badgeRenk), fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }),
                        const Divider(color: Colors.white10),
                      ] else if (_aramaSonuclari.isNotEmpty && filtrelenmis.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.filter_list_off, color: Colors.white24, size: 40),
                                const SizedBox(height: 8),
                                Text('"$_aktifFiltre" kategorisinde sonuç yok.',
                                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                TextButton(
                                  onPressed: () => setModalState(() => _aktifFiltre = 'TÜMÜ'),
                                  child: const Text('Tüm sonuçları göster', style: TextStyle(color: kOrange)),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Hızlı Erişim ───────────────────────────────
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.flash_on, color: kOrange, size: 14),
                            SizedBox(width: 6),
                            Text('HIZLI ERİŞİM',
                                style: TextStyle(color: Colors.white38, fontSize: 10,
                                    fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ],
                        ),
                      ),

                      // Mevcut konum butonu
                      InkWell(
                        onTap: () => _mevcutKonumuKullan(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: kOrange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kOrange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: kOrange.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.my_location, color: kOrange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('📍 Mevcut Konumumu Kullan',
                                        style: TextStyle(color: Colors.white,
                                            fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(
                                      _mevcutKonum != null
                                          ? '${_mevcutKonum!.latitude.toStringAsFixed(5)}, ${_mevcutKonum!.longitude.toStringAsFixed(5)}'
                                          : 'GPS bekleniyor...',
                                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: kOrange, size: 20),
                            ],
                          ),
                        ),
                      ),

                      // ── Türkiye'nin Dağları ─────────────────────────
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.landscape, color: kOrange, size: 14),
                            SizedBox(width: 6),
                            Text('TÜRKİYE\'NİN EN YÜKSEK ZIRVELERI',
                                style: TextStyle(color: Colors.white38, fontSize: 10,
                                    fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      ...MountainDB.turkishMountains.asMap().entries.map((e) {
                        final dag = e.value;
                        final sira = e.key + 1;
                        return InkWell(
                          onTap: () => _dagSecKonum(dag),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                              color: sira <= 3 ? kOrange.withOpacity(0.03) : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: sira <= 3 ? kOrange.withOpacity(0.2) : Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: sira <= 3
                                        ? Text(['🥇', '🥈', '🥉'][sira - 1], style: const TextStyle(fontSize: 16))
                                        : Text('#$sira',
                                            style: const TextStyle(color: Colors.white38,
                                                fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dag.name,
                                          style: TextStyle(
                                            color: sira <= 3 ? kOrange : Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          )),
                                      Text('⛰️ ${dag.altitude} m irtifa',
                                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ROTA+ ',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
              ),
              TextSpan(
                text: 'ROTA PLANLAMA',
                style: TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 20, fontStyle: FontStyle.italic, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.black,
            child: TabBar(
              controller: _tabController,
              indicatorColor: kOrange,
              labelColor: kOrange,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              tabs: const [
                Tab(icon: Icon(Icons.add_location_alt, size: 18), text: 'YENİ ROTA'),
                Tab(icon: Icon(Icons.list_alt, size: 18), text: 'KAYITLI ROTALAR'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildYeniRotaTab(),
                _buildKayitliRotalarTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYeniRotaTab() {
    final validWaypoints = _waypoints.where((w) => w['konum'] != null).toList();
    final bool rotaHazir = validWaypoints.length >= 2;

    final String tahminiSure = _toplamMesafe > 0
        ? (_toplamMesafe / 1000 / 4 * 60).round().toString() + ' dk' // ~4 km/sa yürüyüş
        : '--';
    final String mesafeMetni = _toplamMesafe > 1000
        ? '${(_toplamMesafe / 1000).toStringAsFixed(2)} km'
        : _toplamMesafe > 0 ? '${_toplamMesafe.toInt()} m' : '--';

    return Column(
      children: [
        // ── Rota Planlama Paneli ─────────────────────────────────
        Container(
          color: const Color(0xFF0E0E0E),
          child: Column(
            children: [
              for (int i = 0; i < _waypoints.length; i++) ...[
                _buildKonumSatiri(
                  ikon: i == 0 ? Icons.trip_origin : (i == _waypoints.length - 1 ? Icons.flag_rounded : Icons.location_on),
                  ikonRenk: i == 0 ? kGreen : (i == _waypoints.length - 1 ? Colors.redAccent : kOrange),
                  etiket: i == 0 ? 'NEREDEN' : (i == _waypoints.length - 1 ? 'NEREYE' : 'ARA NOKTA $i'),
                  deger: _waypoints[i]['name'].isEmpty ? (i == 0 ? 'Başlangıç noktası seçin...' : (i == _waypoints.length - 1 ? 'Hedef noktası seçin...' : 'Ara nokta seçin...')) : _waypoints[i]['name'],
                  degerRenk: _waypoints[i]['name'].isEmpty ? Colors.white24 : Colors.white,
                  onTap: () {
                    _secilenIndex = i;
                    _konumSecDiyalogu();
                  },
                  onHaritaTap: () {
                    setState(() {
                      _planlamaAktif = true;
                      _secilenIndex = i;
                    });
                    _notify('Haritada noktaya dokunun.');
                  },
                  onDelete: () async {
                    if (i != 0 && i != _waypoints.length - 1) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: kCardBg,
                          title: const Text('Ara Noktayı Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: const Text('Bu ara noktayı silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SİL', style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                    }

                    setState(() {
                      if (_waypoints.length > 2 && i != 0 && i != _waypoints.length - 1) {
                        _waypoints.removeAt(i);
                      } else {
                        _waypoints[i] = {'name': '', 'konum': null};
                      }
                      _rotaHesaplaVeCiz();
                    });
                  },
                  secildi: _waypoints[i]['konum'] != null,
                ),
                if (i < _waypoints.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Container(width: 2, height: 8, color: Colors.white12),
                            Icon(Icons.more_vert, color: Colors.white12, size: 14),
                            Container(width: 2, height: 8, color: Colors.white12),
                          ],
                        ),
                        if (rotaHazir && i == _waypoints.length - 2) ...
                          [
                            const SizedBox(width: 12),
                            Icon(Icons.route, color: kOrange.withOpacity(0.4), size: 14),
                            const SizedBox(width: 4),
                            Text(mesafeMetni,
                                style: TextStyle(color: kOrange.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                          ]
                      ],
                    ),
                  ),
              ],
              
              if (_waypoints.length < 5)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange.withOpacity(0.1),
                        foregroundColor: kOrange,
                        side: BorderSide(color: kOrange.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _waypoints.insert(_waypoints.length - 1, {'name': '', 'konum': null});
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Ara Nokta Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),

              // ── İstatistik Şeridi ────────────────────────────────
              if (rotaHazir)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: kOrange.withOpacity(0.08),
                    border: const Border(
                      top: BorderSide(color: Colors.white10),
                      bottom: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(Icons.straighten, mesafeMetni, 'MESAFE'),
                      Container(width: 1, height: 30, color: Colors.white12),
                      _buildStatItem(Icons.timer_outlined, tahminiSure, 'TAHMINI SÜRE'),
                      Container(width: 1, height: 30, color: Colors.white12),
                      _buildStatItem(Icons.terrain_outlined, '${_planNoktalar.length}', 'NOKTA'),
                      Container(width: 1, height: 30, color: Colors.white12),
                      _buildStatItem(
                        Icons.signal_cellular_alt,
                        _toplamMesafe < 5000 ? 'KOLAY' : _toplamMesafe < 15000 ? 'ORTA' : 'ZOR',
                        'ZORLuk',
                        renk: _toplamMesafe < 5000 ? kGreen : _toplamMesafe < 15000 ? kOrange : Colors.redAccent,
                      ),
                    ],
                  ),
                )
              else if (_waypoints[0]['konum'] != null && _waypoints.last['konum'] == null)
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_downward, color: kOrange, size: 14),
                      const SizedBox(width: 6),
                      Text('Şimdi hedef/bitiş noktasını seçin',
                          style: TextStyle(color: kOrange.withOpacity(0.7), fontSize: 11)),
                    ],
                  ),
                )
              else if (_waypoints[0]['konum'] == null)
                Container(
                  padding: const EdgeInsets.all(10),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, color: Colors.white24, size: 14),
                      SizedBox(width: 6),
                      Text('Başlangıç ve hedef noktası seçerek rota planlayın',
                          style: TextStyle(color: Colors.white24, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Harita Dokunma İpucu ─────────────────────────────────
        if (_planlamaAktif)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: kOrange,
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _secilenIndex == 0
                        ? 'Haritaya dokunarak BAŞLANGIÇ noktası belirleyin'
                        : (_secilenIndex == _waypoints.length - 1 ? 'Haritaya dokunarak HEDEF noktası belirleyin' : 'Haritaya dokunarak ARA NOKTA belirleyin'),
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _planlamaAktif = false),
                  child: const Icon(Icons.close, color: Colors.black54, size: 20),
                ),
              ],
            ),
          ),

        // ── Harita ────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mevcutKonum ?? const LatLng(39.0, 35.0),
                  initialZoom: 7.0,
                  maxZoom: 18.0,
                  onTap: (tapPosition, point) => _haritaTiklandi(tapPosition, point),
                  onMapReady: () {
                    setState(() => _haritaHazir = true);
                    if (_mevcutKonum != null) {
                      try { _mapController.move(_mevcutKonum!, 12); } catch (_) {}
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _mapTileUrl,
                    subdomains: const ['a', 'b', 'c'],
                    maxZoom: 22,
                    maxNativeZoom: 19,
                    userAgentPackageName: 'com.rota_plus.mountaineering_app',
                  ),
                  if (_planNoktalar.length >= 2) ...[
                    // Gölge çizgi (kalın, koyu)
                    PolylineLayer<Object>(polylines: [
                      Polyline<Object>(
                        points: _planNoktalar,
                        color: Colors.black.withOpacity(0.4),
                        strokeWidth: 7.0,
                      ),
                    ]),
                    // Ana çizgi (turuncu) - KESİK ÇİZGİLİ PROFESYONEL GÖRÜNÜM
                    PolylineLayer<Object>(polylines: [
                      Polyline<Object>(
                        points: _planNoktalar,
                        color: kOrange,
                        strokeWidth: 4.5,
                      ),
                    ]),
                  ],
                  // Markers for waypoints
                  for (int i = 0; i < _waypoints.length; i++)
                    if (_waypoints[i]['konum'] != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _waypoints[i]['konum']!,
                          width: 42,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == 0 ? kGreen : (i == _waypoints.length - 1 ? Colors.redAccent : kOrange),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: (i == 0 ? kGreen : (i == _waypoints.length - 1 ? Colors.redAccent : kOrange)).withOpacity(0.5), blurRadius: 12, spreadRadius: 2)],
                            ),
                            child: Icon(i == 0 ? Icons.trip_origin : (i == _waypoints.length - 1 ? Icons.flag_rounded : Icons.location_on), color: i == 0 ? Colors.black : Colors.white, size: 22),
                          ),
                        ),
                      ]),
                  if (_mevcutKonum != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _mevcutKonum!,
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.my_location, color: Colors.black, size: 18),
                        ),
                      ),
                    ]),
                ],
              ),
              // Harita Katman Değiştirici Buton
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'layerBtn2_stack',
                  mini: true,
                  backgroundColor: kCardBg,
                  child: const Icon(Icons.layers, color: Colors.white, size: 20),
                  onPressed: _showMapLayerSelector,
                ),
              ),
              // Harita zoom kontrolleri
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  children: [
                    _buildMapButton(Icons.add, () {
                      try { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); } catch (_) {}
                    }),
                    const SizedBox(height: 6),
                    _buildMapButton(Icons.remove, () {
                      try { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); } catch (_) {}
                    }),
                    const SizedBox(height: 6),
                    _buildMapButton(Icons.my_location, () {
                      if (_mevcutKonum != null) {
                        try { _mapController.move(_mevcutKonum!, 13); } catch (_) {}
                      } else {
                        _konumGetir();
                      }
                    }, renk: kOrange),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Alt Aksiyon Paneli ────────────────────────────────────
        if (rotaHazir)
          Container(
            color: const Color(0xFF0E0E0E),
            child: Column(
              children: [
                const Divider(height: 1, color: Colors.white10),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Planner Butonu
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => _showExpeditionPlanner(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kOrange),
                            backgroundColor: kOrange.withOpacity(0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Icon(Icons.analytics_outlined, color: kOrange, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Kaydet
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _rotaKaydet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kOrange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.save_outlined, color: Colors.black, size: 20),
                          label: const Text('KAYDET',
                              style: TextStyle(color: Colors.black,
                                  fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Temizle
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _planNoktalar.clear();
                              _waypoints = [
                                {'name': '', 'konum': null},
                                {'name': '', 'konum': null},
                              ];
                              _secilenIndex = 0;
                              _toplamMesafe = 0;
                              _elevationGain = 0;
                              _maxElevation = 0;
                              _averageElevation = 0;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(IconData ikon, String deger, String etiket, {Color? renk}) {
    return Expanded(
      child: Column(
        children: [
          Icon(ikon, color: renk ?? kOrange, size: 14),
          const SizedBox(height: 2),
          Text(deger, style: TextStyle(color: renk ?? Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(etiket, style: const TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  void _showExpeditionPlanner() async {
    final isPrem = await PremiumService.isPremium();
    if (!isPrem) {
      if (!mounted) return;
      PremiumService.showPremiumRequired(context, 'Expedition Planner (Ekipman ve Kalori)');
      return;
    }

    if (_toplamMesafe == 0) return;

    double waterNeeds = (_toplamMesafe / 1000) * 0.5; // Her km için yarım litre yaklaşık
    if (waterNeeds < 1.0) waterNeeds = 1.0;
    
    double calories = (_toplamMesafe / 1000) * 65.0; // Her km yaklaşık 65 kcal
    
    int durationMins = (_toplamMesafe / 1000 / 4 * 60).round();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, color: kOrange),
                  const SizedBox(width: 10),
                  const Text('EXPEDITION PLANNER', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 20),
              _buildPlannerItem(Icons.local_fire_department, 'Yakılacak Kalori', '${calories.toInt()} kcal', Colors.redAccent),
              const SizedBox(height: 12),
              _buildPlannerItem(Icons.water_drop, 'Gerekli Su Miktarı', '${waterNeeds.toStringAsFixed(1)} Litre', Colors.lightBlue),
              const SizedBox(height: 12),
              _buildPlannerItem(Icons.timer, 'Tahmini Süre', '$durationMins dakika', Colors.amber),
              const SizedBox(height: 12),
              _buildPlannerItem(Icons.backpack, 'Tavsiye Edilen Yük', 'Maks. 12 kg', Colors.brown),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('KAPAT', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlannerItem(IconData icon, String title, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white70))),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildMapButton(IconData ikon, VoidCallback onTap, {Color? renk}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(ikon, color: renk ?? Colors.white54, size: 18),
      ),
    );
  }

  Widget _buildKonumSatiri({
    required IconData ikon,
    required Color ikonRenk,
    required String etiket,
    required String deger,
    required Color degerRenk,
    required VoidCallback onTap,
    required VoidCallback onHaritaTap,
    VoidCallback? onDelete,
    bool secildi = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: secildi ? ikonRenk : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ikonRenk.withOpacity(secildi ? 0.2 : 0.07),
                  shape: BoxShape.circle,
                ),
                child: Icon(ikon, color: ikonRenk, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiket,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9,
                            fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 2),
                    Text(deger,
                        style: TextStyle(
                            color: degerRenk, fontSize: 13,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Haritadan seç butonu
              GestureDetector(
                onTap: onHaritaTap,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.white38, size: 16),
                ),
              ),
              const SizedBox(width: 6),
              // Arama butonu
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ikonRenk.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.search, color: ikonRenk, size: 16),
                ),
              ),
              if (onDelete != null && secildi) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKayitliRotalarTab() {
    if (_rotaYukleniyor) {
      return const Center(child: CircularProgressIndicator(color: kOrange));
    }
    if (_kayitliRotalar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.route_outlined, color: Colors.white10, size: 64),
            const SizedBox(height: 16),
            const Text('Henüz kaydedilmiş rota bulunamadı.',
                style: TextStyle(color: Colors.white30)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kayitliRotalar.length,
      itemBuilder: (ctx, i) {
        final r = _kayitliRotalar[i];
        final aktif = r['aktif'] == true;
        final baslangicAdi = (r['baslangic_adi'] as String? ?? '');
        final bitisAdi = (r['bitis_adi'] as String? ?? '');
        final double distM = (r['distance'] as num?)?.toDouble() ?? 0.0;
        final int durSec = (r['duration_seconds'] as num?)?.toInt() ?? 0;
        final double elevGain = (r['elevation_gain'] as num?)?.toDouble() ?? 0.0;
        final double maxAlt = (r['max_altitude'] as num?)?.toDouble() ?? 0.0;
        final List noktalar = r['noktalar'] is List ? r['noktalar'] : [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: aktif ? kOrange.withOpacity(0.5) : Colors.white10,
              width: aktif ? 1.5 : 1,
            ),
            boxShadow: [
              if (aktif)
                BoxShadow(
                  color: kOrange.withOpacity(0.1),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (aktif ? kOrange : Colors.white).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        color: aktif ? kOrange : Colors.white70,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['isim'] as String,
                            style: TextStyle(
                              color: aktif ? kOrange : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${noktalar.length} nokta  ·  ${baslangicAdi.isNotEmpty ? baslangicAdi : "Belirsiz Başlangıç"}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (distM > 0 || elevGain > 0) ...[const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            if (distM > 0) _buildMiniStatChip(
                              Icons.straighten,
                              distM >= 1000 ? '${(distM/1000).toStringAsFixed(1)} km' : '${distM.toInt()} m',
                              const Color(0xFF62FF4C),
                            ),
                            if (durSec > 0) _buildMiniStatChip(
                              Icons.timer_outlined,
                              durSec >= 3600 ? '${(durSec~/3600)}s ${((durSec%3600)~/60)}d' : '${durSec~/60} dk',
                              Colors.amberAccent,
                            ),
                            if (elevGain > 0) _buildMiniStatChip(
                              Icons.trending_up,
                              '+${elevGain.toInt()} m',
                              Colors.lightBlueAccent,
                            ),
                            if (maxAlt > 0) _buildMiniStatChip(
                              Icons.landscape,
                              '${maxAlt.toInt()} m',
                              Colors.deepPurpleAccent,
                            ),
                          ])],
                        ],
                      ),
                    ),
                    if (aktif)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AKTİF',
                          style: TextStyle(
                            color: kOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Orta Bölüm: Yol Tarifi (Varsa)
              if (baslangicAdi.isNotEmpty && bitisAdi.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trip_origin, color: kGreen, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$baslangicAdi → $bitisAdi',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 12),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.white10),

              // Alt Bölüm: Butonlar
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // TAKİBİ BAŞLAT
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await DatabaseHelper.instance.rotayiAktifYap(r['id'] as int);
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Takip başlatılıyor... Lütfen GPS sinyalini bekleyin.'),
                                  backgroundColor: Color(0xFF43A047),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              Navigator.pushAndRemoveUntil(
                                ctx,
                                MaterialPageRoute(builder: (_) => const MainAppScreen()),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGreen,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text(
                              'TAKİBİ BAŞLAT',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // SİL
                        SizedBox(
                          width: 100,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (dialogCtx) => AlertDialog(
                                  backgroundColor: kCardBg,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Rotayı Sil',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  content: const Text(
                                      'Bu rota kalıcı olarak silinecek. Emin misiniz?',
                                      style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx, false),
                                      child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx, true),
                                      child: const Text('SİL',
                                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) _rotaSil(r['id'] as int);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent, width: 1.5),
                              foregroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text(
                              'SİL',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // FLYOVER
                    if (noktalar.length >= 2) SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RouteFlyoverScreen(
                            routeName: r['isim'] as String? ?? 'Rota',
                            noktalar: noktalar,
                            distance: distM,
                            durationSeconds: durSec,
                            elevationGain: elevGain,
                            maxAltitude: maxAlt,
                          ),
                        )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A2E),
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                        label: const Text(
                          'ROTA OYNATICI (FLYOVER)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // PAYLAŞ
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _shareRouteToFeed(r),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: kGreen.withOpacity(0.5)),
                          foregroundColor: kGreen,
                          backgroundColor: kGreen.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text(
                          'ROTAYI EKİP AKIŞINDA PAYLAŞ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildMiniStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildTacticalStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
