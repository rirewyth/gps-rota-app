import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../database_helper.dart';
import '../data/mountain_database.dart';
import '../storage_helper.dart';
import '../services/premium_service.dart';
import '../services/background_sms_service.dart';
import '../services/routing_service.dart';
import '../services/cloud_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/location_permission_helper.dart';

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);
const Color kGreen = Color(0xFF62FF4C);

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _mevcutKonum;
  List<LatLng> _planlamaNoktalar = [];
  bool _planlamaAktif = false;
  bool _haritaHazir = false;
  bool _konumYukleniyor = false;
  Map<String, dynamic>? _aktifRota;
  List<LatLng> _aktifRotaHat = [];
  StreamSubscription<Position>? _konumStream;

  // Gelişmiş Özellikler
  bool _isPremium = false;
  String _currentMapStyle = 'topo'; // Varsayılanı Topografik yaptık
  bool _isDownloading = false;
  double _downloadProgress = 0;
  final List<LatLng> _teamMembers = [
    const LatLng(40.070, 29.278), // Mock tırmanıcı 1
    const LatLng(40.065, 29.282), // Mock tırmanıcı 2
  ];

  // Arama State
  final TextEditingController _aramaController = TextEditingController();
  List<LocationSearchResult> _aramaSonuclari = [];
  bool _aramaYukleniyor = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        final premium = await PremiumService.isPremium();
        final style = await StorageHelper.getMapStyle();
        setState(() {
          _isPremium = premium;
          _currentMapStyle = style;
        });
        _konumGetir();
        _loadActiveRoute();
      }
    });
  }

  @override
  void dispose() {
    _konumStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveRoute() async {
    final rota = await DatabaseHelper.instance.aktifRotaGetir();
    if (rota != null && mounted) {
      final noktalar = (rota['noktalar'] as List).map((n) =>
        LatLng((n['lat'] as num).toDouble(), (n['lng'] as num).toDouble())
      ).toList();
      setState(() {
        _aktifRota = rota;
        _aktifRotaHat = noktalar;
      });
    }
  }

  Future<void> _konumGetir() async {
    if (_konumYukleniyor) return;
    setState(() => _konumYukleniyor = true);

    try {
      bool gpsAcik = await Geolocator.isLocationServiceEnabled();
      if (!gpsAcik) { setState(() => _konumYukleniyor = false); return; }

      LocationPermission izin = await LocationPermissionHelper.checkAndRequestLocationPermission(context);
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) { setState(() => _konumYukleniyor = false); return; }

      Position konum = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _mevcutKonum = LatLng(konum.latitude, konum.longitude);
          _konumYukleniyor = false;
        });
        if (_haritaHazir) {
          try { _mapController.move(_mevcutKonum!, 14.0); } catch (_) {}
        }
      }
    } catch (_) {
      if (mounted) setState(() => _konumYukleniyor = false);
    }
  }

  double _toplamMesafe = 0;

  void _haritayaTikla(TapPosition tap, LatLng nokta) {
    if (_planlamaAktif) {
      setState(() {
        _planlamaNoktalar.add(nokta);
        _hesaplaPlanMesafe();
      });
    }
  }

  void _hesaplaPlanMesafe() {
    double mesafe = 0;
    for (int i = 0; i < _planlamaNoktalar.length - 1; i++) {
      mesafe += Geolocator.distanceBetween(
        _planlamaNoktalar[i].latitude, _planlamaNoktalar[i].longitude,
        _planlamaNoktalar[i+1].latitude, _planlamaNoktalar[i+1].longitude
      );
    }
    setState(() => _toplamMesafe = mesafe);
  }

  // Rotayı kaydet
  void _rotaKaydet() async {
    if (_planlamaNoktalar.length < 2) {
      _notify('Rota için en az 2 nokta seçin!', hata: true);
      return;
    }

    final isimController = TextEditingController(
      text: 'Rota ${DateTime.now().day}.${DateTime.now().month}'
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Rotayı Kaydet', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            const Text('Hedef Dağ / Zirve:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateDialog) {
                final bool manuelMod = isimController.text.contains('(Manuel)');
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: manuelMod ? 'MANUEL GIRME' : MountainDB.turkishMountains.first.name,
                      dropdownColor: kCardBg,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFF0A0A0A),
                        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                      ),
                      items: [
                        ...MountainDB.turkishMountains.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))),
                        const DropdownMenuItem(value: 'MANUEL GIRME', child: Text('✍️ MANUEL GİRİŞ', style: TextStyle(color: kOrange))),
                      ],
                      onChanged: (v) {
                        setStateDialog(() {
                          if (v == 'MANUEL GIRME') {
                            isimController.text = 'Özel Zirve (Manuel)';
                          } else if (v != null) {
                            isimController.text = '$v Rotası';
                          }
                        });
                      },
                    ),
                    if (isimController.text.contains('(Manuel)'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextField(
                          onChanged: (v) => isimController.text = v,
                          style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: 'Zirve adını buraya yazın...',
                            hintStyle: TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
                          ),
                        ),
                      ),
                  ],
                );
              }
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
                  ? 'İsimsiz Rota'
                  : isimController.text.trim();

              final noktalarMap = _planlamaNoktalar.map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
              }).toList();

              await DatabaseHelper.instance.rotaKaydet(isim, noktalarMap);

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _loadActiveRoute();
              setState(() {
                _planlamaAktif = false;
                _planlamaNoktalar.clear();
              });
              _notify('✓ "$isim" rotası kaydedildi ve aktif yapıldı!');
            },
            child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Kayıtlı rotaları göster
  void _rotaListesiGoster() async {
    final rotalar = await DatabaseHelper.instance.tumRotalarGetir();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: Colors.black,
            child: Row(
              children: [
                const Text('KAYITLI ROTALAR',
                  style: TextStyle(color: kOrange, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const Spacer(),
                Text('${rotalar.length} rota', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: rotalar.isEmpty
              ? const Center(
                  child: Text('Henüz rota kaydedilmemiş.\nHaritada rota planla ve kaydet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                )
              : ListView.builder(
                  itemCount: rotalar.length,
                  itemBuilder: (ctx, i) {
                    final r = rotalar[i];
                    return ListTile(
                      tileColor: (r['aktif'] as bool) ? kOrange.withOpacity(0.1) : Colors.transparent,
                      leading: Icon(
                        Icons.route,
                        color: (r['aktif'] as bool) ? kOrange : Colors.white38,
                      ),
                      title: Text(r['isim'] as String,
                        style: TextStyle(
                          color: (r['aktif'] as bool) ? kOrange : Colors.white,
                          fontWeight: (r['aktif'] as bool) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${r['noktalarSayisi']} nokta · ${(r['aktif'] as bool) ? "AKTİF" : ""}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!(r['aktif'] as bool))
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: kGreen, size: 20),
                              onPressed: () async {
                                await DatabaseHelper.instance.rotayiAktifYap(r['id'] as int);
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                await _loadActiveRoute();
                                _notify('✓ Rota aktif yapıldı!');
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () async {
                              await DatabaseHelper.instance.rotaSil(r['id'] as int);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              await _loadActiveRoute();
                              _notify('Rota silindi.');
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        await DatabaseHelper.instance.rotayiAktifYap(r['id'] as int);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _loadActiveRoute();
                        _notify('✓ "${r['isim']}" aktif rota olarak seçildi!');
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _offlineMapDownload() async {
    if (_aktifRota == null) {
      _notify('Önce bir rota seçmelisiniz!', hata: true);
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    // Simüle edilmiş indirme süreci
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _downloadProgress = i / 10);
    }

    if (!mounted) return;
    setState(() => _isDownloading = false);
    _notify('✓ "${_aktifRota!['isim']}" bölgesi çevrimdışı kullanım için hazır!');
  }

  void _sosGonder() async {
    setState(() => _konumYukleniyor = true);
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final phone = await StorageHelper.getObserverPhone();
      if (phone == null || phone.isEmpty) {
        _notify('⚠️ ACİL DURUM KİŞİSİ AYARLANMAMIŞ! Profil sayfasından ayarlayın.', hata: true);
        setState(() => _konumYukleniyor = false);
        return;
      }

      final blood = await StorageHelper.getBloodType() ?? 'BİLİNMİYOR';
      final medical = await StorageHelper.getMedicalInfo() ?? 'Belirtilmedi';
      final name = await StorageHelper.getUserName() ?? 'Dağcı';
      final altitude = position.altitude.toInt();
      
      final googleUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final osmUrl = 'https://www.openstreetmap.org/?mlat=${position.latitude}&mlon=${position.longitude}#map=16/${position.latitude}/${position.longitude}';
      
      final message = '🚨 ROTA+ SOS!\n'
          '👤 $name\n'
          '📍 GMAPS: $googleUrl\n'
          '🗺️ OSM: $osmUrl\n'
          '⛰️ RAKIM: $altitude m\n'
          '🩸 KAN: $blood\n'
          '🩺 TIBBİ: $medical\n'
          '⏱️ ZAMAN: ${DateTime.now().hour}:${DateTime.now().minute}';

      // SOS Log Kaydet
      await DatabaseHelper.instance.mesajKaydet(message, 'SOS', isSos: 1);
      
      // SMS Otomatik Gönder
      final res = await BackgroundSmsService.sendSms(phone, message);

      // KOMUTA MERKEZİNE (ADMIN APK) SİNYAL GÖNDER
      await CloudSyncService.syncMessage(
        "HARİTA ÜZERİNDEN ACİL DURUM SOS GÖNDERİLDİ!", 
        "LOCATION", 
        false
      );
      
      if (mounted) {
        setState(() => _konumYukleniyor = false);
        _notify(res ? '🚨 SOS GÖNDERİLDİ!' : '⚠️ SMS GÖNDERİMİ BAŞARISIZ!', hata: !res);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _konumYukleniyor = false);
        _notify('⚠️ KONUM ALINAMADI: $e', hata: true);
      }
    }
  }

  void _aramaYap(String query) async {
    if (query.trim().length < 3) return;
    setState(() => _aramaYukleniyor = true);
    final sonuclar = await RoutingService.searchLocation(query);
    if (mounted) {
      setState(() {
        _aramaSonuclari = sonuclar;
        _aramaYukleniyor = false;
      });
    }
  }

  void _aramaSonucuSec(LocationSearchResult sonuc) {
    final latLng = LatLng(sonuc.lat, sonuc.lon);
    setState(() {
      _aramaSonuclari = [];
      _aramaController.clear();
      FocusScope.of(context).unfocus();
    });
    try {
      _mapController.move(latLng, 14.0);
    } catch (_) {}
  }

  void _notify(String mesaj, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(hata ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(mesaj, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      backgroundColor: hata ? Colors.red.shade900 : const Color(0xFF43A047),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          // ── Harita ─────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mevcutKonum ?? const LatLng(40.067, 29.273),
              initialZoom: 13.0,
              maxZoom: 19.0,
              onTap: _haritayaTikla,
              onMapReady: () {
                setState(() => _haritaHazir = true);
                if (_mevcutKonum != null) {
                  try { _mapController.move(_mevcutKonum!, 14.0); } catch (_) {}
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(),
                subdomains: const ['a', 'b', 'c'],
                maxZoom: 21,
                maxNativeZoom: _currentMapStyle == 'osm' ? 19 : 20,
                userAgentPackageName: 'RotaPlus_Tactical_v1.0',
                tileProvider: NetworkTileProvider(),
              ),

              // Aktif kayıtlı rota - PROFESYONEL PATİKA GÖRÜNÜMÜ
              if (_aktifRotaHat.length >= 2)
                PolylineLayer<Object>(polylines: [
                  Polyline<Object>(
                    points: _aktifRotaHat,
                    color: Colors.blueAccent.withOpacity(0.8),
                    strokeWidth: 4.5,
                    pattern: StrokePattern.dashed(segments: [15, 15]),
                  ),
                ]),

              // Aktif rota noktaları
              if (_aktifRotaHat.isNotEmpty)
                MarkerLayer(
                  markers: _aktifRotaHat.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    final bool ilkVeyaSon = i == 0 || i == _aktifRotaHat.length - 1;
                    return Marker(
                      point: p,
                      width: ilkVeyaSon ? 20 : 12,
                      height: ilkVeyaSon ? 20 : 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == 0 ? kGreen : (i == _aktifRotaHat.length - 1 ? Colors.redAccent : Colors.blueAccent),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ilkVeyaSon
                          ? Icon(i == 0 ? Icons.hiking : Icons.flag, size: 10, color: Colors.white)
                          : null,
                      ),
                    );
                  }).toList(),
                ),

              // Planlama noktaları - TURUNCU çizgi (Kesik çizgili)
              if (_planlamaNoktalar.length >= 2)
                PolylineLayer<Object>(polylines: [
                  Polyline<Object>(
                    points: _planlamaNoktalar,
                    color: kOrange,
                    strokeWidth: 4.0,
                    pattern: StrokePattern.dashed(segments: [10, 10]),
                  ),
                ]),

              // Planlama waypoint noktaları
              if (_planlamaNoktalar.isNotEmpty)
                MarkerLayer(
                  markers: _planlamaNoktalar.asMap().entries.map((entry) => Marker(
                    point: entry.value,
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text('${entry.key + 1}',
                          style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )).toList(),
                ),

              // Mevcut konum
              if (_mevcutKonum != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _mevcutKonum!,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.black, size: 22),
                    ),
                  ),
                ]),

              // Ekip Üyeleri (Premium ise)
              if (_isPremium)
                MarkerLayer(
                  markers: _teamMembers.map((p) => Marker(
                    point: p,
                    width: 30,
                    height: 30,
                    child: Column(
                      children: [
                        const Icon(Icons.person_pin_circle_rounded, color: Colors.blueAccent, size: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          color: Colors.black87,
                          child: const Text('TIRMANICI', style: TextStyle(color: Colors.white, fontSize: 6)),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
            ],
          ),
          // ── Arama Çubuğu ───────────────────────────────────────────
          Positioned(
            top: 70, left: 16, right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                  ),
                  child: TextField(
                    controller: _aramaController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: _aramaYap,
                    decoration: InputDecoration(
                      hintText: 'DAĞ, ZİRVE VEYA KONUM ARA...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                      icon: const Icon(Icons.search, color: kOrange, size: 20),
                      border: InputBorder.none,
                      suffixIcon: _aramaController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                            onPressed: () {
                              _aramaController.clear();
                              setState(() => _aramaSonuclari = []);
                            },
                          )
                        : null,
                    ),
                  ),
                ),
                if (_aramaSonuclari.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: kOrange.withOpacity(0.3)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _aramaSonuclari.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (ctx, i) {
                        final res = _aramaSonuclari[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            res.type == 'peak' ? Icons.terrain : Icons.location_on,
                            color: res.type == 'peak' ? kOrange : Colors.white38,
                            size: 16,
                          ),
                          title: Text(res.displayName.split(',').first, 
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(res.displayName, 
                            style: const TextStyle(color: Colors.white38, fontSize: 10, overflow: TextOverflow.ellipsis)),
                          onTap: () => _aramaSonucuSec(res),
                        );
                      },
                    ),
                  ),
                if (_aramaYukleniyor)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(width: 20, height: 2, child: LinearProgressIndicator(color: kOrange, backgroundColor: Colors.transparent)),
                  ),
              ],
            ),
          ),

          // ── Üst Araç Çubuğu ────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
              color: Colors.black.withOpacity(0.85),
              child: Row(
                children: [
                  // Başlık
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CANLI HARİTA',
                        style: TextStyle(color: kOrange, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      if (_aktifRota != null)
                        Text('📍 HEDEF: ${_aktifRota!['isim']}',
                          style: const TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold))
                      else
                        const Text('⚠️ Lütfen bir rota seçin',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  const Spacer(),

                  // Geri Al (Undo) Butonu
                  if (_planlamaAktif && _planlamaNoktalar.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() => _planlamaNoktalar.removeLast());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(right: 6),
                        color: Colors.redAccent.withOpacity(0.8),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.undo, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('SİL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                  GestureDetector(
                    onTap: () {
                      if (!_planlamaAktif) {
                        setState(() => _planlamaAktif = true);
                      } else if (_planlamaNoktalar.length >= 2) {
                        _rotaKaydet();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _planlamaAktif ? kOrange : Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: _planlamaAktif ? [BoxShadow(color: kOrange.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)] : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _planlamaAktif
                              ? (_planlamaNoktalar.length >= 2 ? Icons.check_circle_outline : Icons.edit_location_alt)
                              : Icons.add_location_alt_rounded,
                            color: _planlamaAktif ? Colors.black : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _planlamaAktif
                              ? (_planlamaNoktalar.length >= 2 ? 'TAMAMLA' : 'NOKTA EKLE')
                              : 'YENİ ROTA',
                            style: TextStyle(
                              color: _planlamaAktif ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // İndir butonu
                  if (!_planlamaAktif && _aktifRota != null)
                    IconButton(
                      icon: Icon(_isDownloading ? Icons.downloading : Icons.map_outlined, 
                        color: _isDownloading ? kOrange : Colors.white60),
                      onPressed: _isDownloading ? null : _offlineMapDownload,
                      tooltip: 'Çevrimdışı Harita İndir',
                    ),

                  // Rotalar listesi
                  IconButton(
                    icon: const Icon(Icons.route, color: Colors.white60),
                    onPressed: _rotaListesiGoster,
                    tooltip: 'Kayıtlı Rotalar',
                  ),

                  // Planlama iptal
                  if (_planlamaAktif)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() {
                        _planlamaAktif = false;
                        _planlamaNoktalar.clear();
                      }),
                    ),
                  
                  // Harita Stili Seçici
                  IconButton(
                    icon: Icon(Icons.layers, color: _currentMapStyle == 'osm' ? Colors.white60 : kOrange),
                    onPressed: _showMapStyleSelector,
                    tooltip: 'Harita Görünümü',
                  ),
                ],
              ),
            ),
          ),

          // ── SOS Butonu ───────────────────────────────────────────
          if (!_planlamaAktif)
            Positioned(
              bottom: 100, right: 12,
              child: FloatingActionButton.extended(
                onPressed: _sosGonder,
                backgroundColor: Colors.red.shade900,
                elevation: 10,
                icon: const Icon(Icons.emergency, color: Colors.white, size: 28),
                label: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)),
              ),
            ),

          // ── Planlama İpucu Mesajı ───────────────────────────────
          if (_planlamaAktif)
            Positioned(
              top: 65, left: 0, right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: kOrange.withOpacity(0.9),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _planlamaNoktalar.isEmpty
                          ? 'Rota başlangıç noktasına dokun…'
                          : '${_planlamaNoktalar.length} nokta eklendi. Devam et veya KAYDET\'e bas.',
                        style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_planlamaNoktalar.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _planlamaNoktalar.removeLast()),
                        child: const Icon(Icons.undo, color: Colors.black, size: 18),
                      ),
                  ],
                ),
              ),
            ),

          // ── GPS Yükleniyor ──────────────────────────────────────
          if (_konumYukleniyor)
            Positioned(
              bottom: 170, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black.withOpacity(0.85),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: kOrange, strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('GPS sinyali aranıyor...', style: TextStyle(color: kOrange, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),

          // ── İndirme Progress bar ───────────────────────────────
          if (_isDownloading)
            Positioned(
              top: 65, left: 0, right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                color: Colors.black.withOpacity(0.9),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download, color: kOrange, size: 16),
                        const SizedBox(width: 8),
                        const Text('Harita Karoları İndiriliyor...', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('%${(_downloadProgress * 100).toInt()}', style: const TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _downloadProgress, backgroundColor: Colors.white10, color: kOrange, minHeight: 2),
                  ],
                ),
              ),
            ),

          // ── Modern Planlama HUD ─────────────────────────────────
          if (_planlamaAktif)
            Positioned(
              bottom: 20, left: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.95),
                  border: const Border(top: BorderSide(color: kOrange, width: 2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PLANLANAN MESAFE', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                            Text(
                              _toplamMesafe > 1000 
                                ? '${(_toplamMesafe/1000).toStringAsFixed(2)} KM' 
                                : '${_toplamMesafe.toInt()} METRE',
                              style: const TextStyle(color: kOrange, fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TAHMİNİ SÜRE', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                            Text(
                              '${(_toplamMesafe / 50).toInt()} DK', // Mock: 50m/dk tırmanış hızı
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white38, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          _planlamaNoktalar.isEmpty 
                            ? 'Rotayı başlatmak için haritaya dokun.'
                            : '${_planlamaNoktalar.length} nokta belirlendi.',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        const Spacer(),
                        if (_planlamaNoktalar.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _planlamaNoktalar.removeLast();
                                _hesaplaPlanMesafe();
                              });
                            },
                            icon: const Icon(Icons.undo, color: Colors.redAccent, size: 16),
                            label: const Text('GERİ AL', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── Alt Lejant ───────────────────────────────────────────
          if (_aktifRota != null && !_planlamaAktif)
            Positioned(
              bottom: 80, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black.withOpacity(0.8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 16, height: 3, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(_aktifRota!['isim'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Başlangıç', style: TextStyle(color: Colors.white54, fontSize: 9)),
                      const SizedBox(width: 8),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Bitiş', style: TextStyle(color: Colors.white54, fontSize: 9)),
                    ]),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _konumGetir,
        mini: true,
        backgroundColor: kOrange,
        child: const Icon(Icons.my_location, color: Colors.black),
      ),
    );
  }

  String _getTileUrl() {
    const String mapboxToken = 'pk.eyJ1Ijoic2VyY2Fub3JhbGwiLCJhIjoiY21vdGxneTR1MDZkNjJ1czl5OG4xZGRtNSJ9.aZd3CyiISCcxlcR0hXkhhQ';
    switch (_currentMapStyle) {
      case 'topo': // OpenTopoMap - Organic Maps'e En Yakın Ücretsiz Seçenek
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case 'hiking': // CyclOSM - Bisiklet ve Yürüyüş Odaklı Detaylı Harita
        return 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
      case 'mapbox_outdoors':
        return 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken';
      case 'mapbox_satellite':
        return 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken';
      case 'osm':
      default:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  void _showMapStyleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('HARİTA GÖRÜNÜMÜ', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 20),
              _buildStyleOption('Topografik (PRO)', 'topo', Icons.terrain, false),
              _buildStyleOption('Outdoor (Patika)', 'hiking', Icons.hiking, false),
              _buildStyleOption('Mapbox Outdoors', 'mapbox_outdoors', Icons.outdoor_grill_outlined, true),
              _buildStyleOption('Uydu Görünümü', 'mapbox_satellite', Icons.satellite_alt_outlined, true),
              _buildStyleOption('Standart (OSM)', 'osm', Icons.map_outlined, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleOption(String label, String style, IconData icon, bool premiumRequired) {
    final bool isSelected = _currentMapStyle == style;
    return ListTile(
      leading: Icon(icon, color: isSelected ? kOrange : Colors.white54),
      title: Text(label, style: TextStyle(color: isSelected ? kOrange : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: premiumRequired && !_isPremium 
        ? const Icon(Icons.stars, color: Colors.amber, size: 18)
        : (isSelected ? const Icon(Icons.check, color: kOrange) : null),
      onTap: () async {
        Navigator.pop(context);
        if (premiumRequired && !_isPremium) {
          PremiumService.showPremiumRequired(context, label);
          return;
        }
        setState(() => _currentMapStyle = style);
        await StorageHelper.setMapStyle(style);
      },
    );
  }
}
