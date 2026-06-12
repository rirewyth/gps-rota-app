import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../services/premium_service.dart';
import '../screens/premium_screen.dart';
import '../services/barometer_service.dart';
import '../storage_helper.dart';
import '../utils/location_permission_helper.dart';

const kBackground = Color(0xFF0A0A0A);
const kCardBg = Color(0xFF141414);
const kOrange = Color(0xFFFF6B00);
const kGreen = Color(0xFF62FF4C);
const kBlue = Color(0xFF00E5FF);



class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with TickerProviderStateMixin {
  FullWeatherData? _data;
  bool _loading = true;
  bool _isPremium = false;
  Position? _pos;
  late TabController _tabController;
  String _errorMsg = '';
  double _devicePressure = 0.0;
  bool _barometerEnabled = false;
  String _locationName = 'Konumum';
  final TextEditingController _searchCtrl = TextEditingController();
  List<LocationResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _isPremium = await PremiumService.isPremium();
    _barometerEnabled = await StorageHelper.getBarometerEnabled();
    
    if (_barometerEnabled) {
      BarometerService().startMonitoring();
      BarometerService().onStormWarning = (title, desc) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $desc'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      };
    }

    setState(() {});
    await _fetchData();
  }

  Future<void> _fetchData({double? lat, double? lng, String? name}) async {
    setState(() { _loading = true; _errorMsg = ''; if (name != null) _locationName = name; });
    try {
      if (lat == null || lng == null) {
        bool svc = await Geolocator.isLocationServiceEnabled();
        if (!svc) { setState(() { _loading = false; _errorMsg = 'GPS kapalı.'; }); return; }
        var perm = await LocationPermissionHelper.checkAndRequestLocationPermission(context);
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          setState(() { _loading = false; _errorMsg = 'Konum izni reddedildi.'; });
          return;
        }
        try {
          _pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium)).timeout(const Duration(seconds: 8));
        } catch (e) {
          _pos = await Geolocator.getLastKnownPosition();
        }
        if (_pos == null) {
          setState(() { _loading = false; _errorMsg = 'Konum tespit edilemedi.'; });
          return;
        }
        lat = _pos!.latitude;
        lng = _pos!.longitude;
        _locationName = 'Konumum';
      }

      if (_isPremium) {
        _data = await WeatherService.getFullWeatherData(lat, lng, altitudeMeters: _pos?.altitude ?? 0);
        if (_data == null) {
          _errorMsg = 'Hava durumu verileri alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
        }
      } else {
        final simple = await WeatherService.checkStormRisk(lat, lng);
        if (simple != null && !simple.isLoading) {
          _data = FullWeatherData(
            current: simple,
            hourly: [],
            daily: [],
            risks: MountainRiskIndex(frostbiteRisk: 0, lightningRisk: 0, avalancheRisk: 0, windRisk: 0, overallRisk: 0, windChill: simple.temperature, overallLabel: 'Detay için Premium', overallColor: 'green'),
            advancedAlerts: [],
          );
        } else if (simple != null && simple.isLoading) {
          _errorMsg = simple.description;
        } else {
          _errorMsg = 'Hava durumu verileri alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
        }
      }
    } catch (e) {
      _errorMsg = 'Veri alınamadı: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          title: Text('Şehir / İlçe Ara', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Örn: İstanbul, Alanya...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  suffixIcon: _isSearching ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: kOrange))) : IconButton(icon: const Icon(Icons.search, color: kOrange), onPressed: () async {
                    if (_searchCtrl.text.isEmpty) return;
                    setDialogState(() => _isSearching = true);
                    final results = await WeatherService.searchLocations(_searchCtrl.text);
                    setDialogState(() { _searchResults = results; _isSearching = false; });
                  }),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kOrange)),
                ),
                onSubmitted: (val) async {
                  if (val.isEmpty) return;
                  setDialogState(() => _isSearching = true);
                  final results = await WeatherService.searchLocations(val);
                  setDialogState(() { _searchResults = results; _isSearching = false; });
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                width: double.maxFinite,
                child: _searchResults.isEmpty 
                  ? const Center(child: Text('Sonuç yok', style: TextStyle(color: Colors.white24, fontSize: 12)))
                  : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, i) {
                      final loc = _searchResults[i];
                      return ListTile(
                        title: Text(loc.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: Text('${loc.admin1}, ${loc.country}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          _fetchData(lat: loc.lat, lng: loc.lng, name: loc.name);
                        },
                      );
                    },
                  ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT', style: TextStyle(color: Colors.white38))),
          ],
        ),
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
          text: const TextSpan(children: [
            TextSpan(text: 'ROTA+ ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
            TextSpan(text: 'METEOROLOJİ', style: TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
          ]),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white70), onPressed: _showSearchDialog),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => _fetchData()),
        ],
        bottom: _isPremium ? TabBar(
          controller: _tabController,
          indicatorColor: kOrange,
          labelColor: kOrange,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
          tabs: const [
            Tab(icon: Icon(Icons.cloud, size: 16), text: 'ANLIK'),
            Tab(icon: Icon(Icons.access_time, size: 16), text: 'SAATLİK'),
            Tab(icon: Icon(Icons.calendar_today, size: 16), text: '7 GÜN'),
            Tab(icon: Icon(Icons.landscape, size: 16), text: 'DAĞLAR'),
          ],
        ) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : _errorMsg.isNotEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, color: Colors.white24, size: 64),
                  const SizedBox(height: 16),
                  Text(_errorMsg, style: const TextStyle(color: Colors.white38)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _fetchData, style: ElevatedButton.styleFrom(backgroundColor: kOrange), child: const Text('Tekrar Dene', style: TextStyle(color: Colors.black))),
                ]))
              : _data == null
                  ? const Center(child: Text('Veri yok', style: TextStyle(color: Colors.white38)))
                  : _isPremium
                        ? TabBarView(
                            controller: _tabController,
                            children: [
                              _KeepAliveWrapper(child: _safeTabWrapper(() => _buildCurrentTab(), 'Anlık')),
                              _KeepAliveWrapper(child: _safeTabWrapper(() => _buildHourlyTab(), 'Saatlik')),
                              _KeepAliveWrapper(child: _safeTabWrapper(() => _buildDailyTab(), '7 Gün')),
                              _KeepAliveWrapper(child: _safeTabWrapper(() => _buildMountainsTab(), 'Dağlar')),
                            ],
                          )
                      : _buildFreemiumView(),
    );
  }

  // ─── FREE view ───────────────────────────────────────────────────────────────
  Widget _buildFreemiumView() {
    final w = _data!.current;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCurrentCard(w),
          const SizedBox(height: 24),
          _buildPremiumUpsell(),
        ],
      ),
    );
  }

  Widget _buildPremiumUpsell() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())).then((_) => _init()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [kOrange.withOpacity(0.8), kOrange.withOpacity(0.3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: kOrange, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.stars, color: Colors.white, size: 36),
            const SizedBox(height: 10),
            Text('PREMIUM METEROLOJİ', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            const Text('Saatlik & 7 günlük tahmin\nDağcılık Risk İndeksi (Çığ · Şimşek · Donma)\nRüzgar Soğuma & İrtifa Analizi',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.6)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
              child: const Text('ŞİMDİ YÜKSELT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CURRENT tab ─────────────────────────────────────────────────────────────
  Widget _buildCurrentTab() {
    final w = _data!.current;
    final r = _data!.risks;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: kOrange, size: 14),
              const SizedBox(width: 4),
              Text(_locationName.toUpperCase(), style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          _buildCurrentCard(w),
          if (_data!.advancedAlerts.isNotEmpty) ...[
             const SizedBox(height: 16),
             _buildAdvancedAlerts(_data!.advancedAlerts),
          ],
          const SizedBox(height: 16),
          if (_barometerEnabled) ...[
             _buildOfflineBarometerCard(),
             const SizedBox(height: 16),
          ],
          _buildRiskIndex(r),
          const SizedBox(height: 16),
          _buildDetailGrid(w),
          if (_pos != null) ...[
            const SizedBox(height: 16),
            _buildAltitudeTempCard(w.temperature, _pos!.altitude),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineBarometerCard() {
    return StreamBuilder<double>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => BarometerService().currentPressure),
      builder: (context, snapshot) {
        final val = snapshot.data ?? 0.0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBlue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sensors, color: kBlue, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CİHAZ BAROMETRE SENSÖRÜ', style: GoogleFonts.shareTechMono(color: kBlue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Text('Çevrimdışı / Gerçek Zamanlı Veri', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              Text('${val > 0 ? val.toStringAsFixed(1) : '--'}', style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Text('hPa', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCurrentCard(WeatherAlertInfo w) {
    final emoji = WeatherService.weatherEmoji(w.weatherCode);
    final label = WeatherService.weatherLabel(w.weatherCode);
    final alertColor = w.isHazardous ? Colors.redAccent : kGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: w.isHazardous
              ? [const Color(0xFF3A0000), const Color(0xFF1A0000)]
              : [const Color(0xFF001A0A), const Color(0xFF0A0A0A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: alertColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${w.temperature.toStringAsFixed(1)}°C',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
                    Text(label, style: TextStyle(color: alertColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    if (_pos != null)
                      Text('${_pos!.altitude.toInt()} m irtifa', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.1),
                  border: Border.all(color: alertColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(w.isHazardous ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: alertColor, size: 20),
                    const SizedBox(height: 4),
                    Text(w.isHazardous ? 'TEHLİKE' : 'GÜVENLİ', style: TextStyle(color: alertColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          if (w.isHazardous) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
              child: Text(w.description, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatChip(Icons.wind_power, '${w.windSpeed.toInt()} km/h', 'RÜZGAR', kOrange),
              _buildStatChip(Icons.water_drop, '%${w.humidity?.toInt() ?? '--'}', 'NEM', Colors.lightBlue),
              _buildStatChip(Icons.thermostat, '${w.dewPoint?.toStringAsFixed(1) ?? '--'}°', 'ÇİĞ NOKT.', kBlue),
              _buildStatChip(Icons.speed, '${w.seaLevelPressure?.toInt() ?? '--'} mbar', 'BASINÇ (MSL)', Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedAlerts(List<AdvancedAlert> alerts) {
    return Column(
      children: alerts.map((a) {
        final color = a.severity == 'critical' ? Colors.redAccent : (a.severity == 'warning' ? kOrange : kBlue);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(a.icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(a.message, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRiskIndex(MountainRiskIndex r) {
    final overallColor = r.overallColor == 'red' ? Colors.redAccent : (r.overallColor == 'orange' ? kOrange : kGreen);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: overallColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terrain, color: overallColor, size: 20),
              const SizedBox(width: 8),
              Text('DAĞCILIK RİSK İNDEKSİ', style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: overallColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: overallColor.withOpacity(0.4))),
                child: Text(r.overallLabel, style: TextStyle(color: overallColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRiskBar('❄️ Donma / Frostbite', r.frostbiteRisk, Colors.lightBlue),
          const SizedBox(height: 10),
          _buildRiskBar('⚡ Şimşek / Fırtına', r.lightningRisk, Colors.yellowAccent),
          const SizedBox(height: 10),
          _buildRiskBar('🏔️ Çığ / Avalanche', r.avalancheRisk, Colors.white),
          const SizedBox(height: 10),
          _buildRiskBar('💨 Rüzgar / Wind', r.windRisk, kOrange),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hissedilen Sıcaklık (Wind Chill)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text('${r.windChill.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Toplam Risk Skoru', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text('${r.overallRisk}/100', style: TextStyle(color: overallColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBar(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('$value%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              value >= 70 ? Colors.redAccent : (value >= 40 ? kOrange : color),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGrid(WeatherAlertInfo w) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _buildGridCard(Icons.wb_sunny, '${w.uvIndex?.toStringAsFixed(1) ?? '--'}', 'UV İNDEKSİ', Colors.yellowAccent),
        _buildGridCard(Icons.cloud, '${w.cloudCover?.toInt() ?? '--'}%', 'BULUT ÖRTÜSÜ', Colors.blueGrey),
        _buildGridCard(Icons.visibility, '${((w.visibility ?? 0) / 1000).toStringAsFixed(1)} km', 'GÖRÜŞ MESAFESİ', Colors.cyanAccent),
        _buildGridCard(Icons.water, '${w.precipitation?.toStringAsFixed(1) ?? '0.0'} mm', 'YAĞIŞ MİKTARI', Colors.lightBlue),
        _buildGridCard(Icons.umbrella, '%${w.precipitationProbability?.toInt() ?? '--'}', 'YAĞIŞ OLASILIĞI', Colors.blueAccent),
        _buildGridCard(Icons.speed, '${w.pressure?.toInt() ?? '--'} hPa', 'YÜZEY BASINCI', Colors.purpleAccent),
        _buildGridCard(Icons.explore, '${w.windDirection.toInt()}°', 'RÜZGAR YÖNÜ', kOrange),
      ],
    );
  }

  Widget _buildGridCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAltitudeTempCard(double surfaceTemp, double altMeters) {
    // Lapse rate: -6.5°C per 1000m
    final adjustedTemp = surfaceTemp - (altMeters / 1000 * 6.5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.landscape, color: Colors.purpleAccent, size: 18),
            const SizedBox(width: 8),
            Text('İRTİFA SICAKLIK ANALİZİ', style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(children: [
                const Text('Yüzey', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text('${surfaceTemp.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const Icon(Icons.arrow_forward, color: Colors.white24),
              Column(children: [
                Text('${altMeters.toInt()} m İrtifa', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)),
                Text('${adjustedTemp.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          const Text('* Her 1000m için ~6.5°C düşüş (kuru adiabatik)',
            style: TextStyle(color: Colors.white24, fontSize: 9)),
        ],
      ),
    );
  }

  // ─── HOURLY tab ───────────────────────────────────────────────────────────────
  Widget _buildHourlyTab() {
    final hours = _data!.hourly;
    if (hours.isEmpty) {
      return const Center(child: Text('Saatlik veri yok', style: TextStyle(color: Colors.white38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: hours.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (_, i) {
        final h = hours[i];
        final now = DateTime.now();
        final isPast = h.time.isBefore(now.subtract(const Duration(minutes: 59)));
        final timeStr = '${h.time.hour.toString().padLeft(2, '0')}:00';
        final emoji = WeatherService.weatherEmoji(h.weatherCode);
        final isRainy = h.precipitation > 0.5;
        final isWindy = h.windSpeed > 30;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 44, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeStr, style: TextStyle(color: isPast ? Colors.white24 : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (isPast) const Text('GEÇMİŞ', style: TextStyle(color: kOrange, fontSize: 7, fontWeight: FontWeight.bold)),
                ],
              )),
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${h.temperature.toStringAsFixed(1)}°C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(WeatherService.weatherLabel(h.weatherCode), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
              if (isRainy) _buildMiniChip('💧 ${h.precipitation.toStringAsFixed(1)}mm', Colors.lightBlue),
              const SizedBox(width: 6),
              if (isWindy) _buildMiniChip('💨 ${h.windSpeed.toInt()}', kOrange),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('%${h.humidity.toInt()}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('DP ${h.dewPoint.toStringAsFixed(1)}°', style: const TextStyle(color: kBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.4))),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  // ─── DAILY tab ────────────────────────────────────────────────────────────────
  Widget _buildDailyTab() {
    final days = _data!.daily;
    if (days.isEmpty) return const Center(child: Text('Günlük veri yok', style: TextStyle(color: Colors.white38)));

    final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = days[i];
        final isToday = i == 0;
        final dayName = isToday ? 'Bugün' : dayNames[d.date.weekday - 1];
        final emoji = WeatherService.weatherEmoji(d.weatherCode);
        final hasSnow = d.snowfallSum > 0;
        final hasRain = d.precipitationSum > 0.5;
        final isStormy = [95, 96, 99].contains(d.weatherCode);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isToday ? kOrange.withOpacity(0.08) : kCardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isToday ? kOrange.withOpacity(0.3) : Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(width: 48, child: Text(dayName, style: TextStyle(color: isToday ? kOrange : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))),
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(WeatherService.weatherLabel(d.weatherCode), style: const TextStyle(color: Colors.white54, fontSize: 11))),
                  Text('${d.tempMin.toInt()}°', style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(' / ', style: const TextStyle(color: Colors.white24)),
                  Text('${d.tempMax.toInt()}°C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              if (hasRain || hasSnow || isStormy || d.windSpeedMax > 30 || d.uvIndexMax > 6) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (hasRain) _buildMiniChip('💧 ${d.precipitationSum.toStringAsFixed(1)}mm', Colors.lightBlue),
                    if (hasSnow) _buildMiniChip('❄️ ${d.snowfallSum.toStringAsFixed(1)}cm', Colors.white),
                    if (d.windSpeedMax > 30) _buildMiniChip('💨 ${d.windSpeedMax.toInt()}km/h', kOrange),
                    if (d.uvIndexMax > 6) _buildMiniChip('☀️ UV${d.uvIndexMax.toInt()}', Colors.yellowAccent),
                    if (isStormy) _buildMiniChip('⚡ Fırtına', Colors.redAccent),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMountainsTab() {
    final List<Map<String, dynamic>> mountains = [
      {'name': 'Ağrı Dağı', 'lat': 39.7025, 'lng': 44.2990, 'alt': 5137},
      {'name': 'Erciyes Dağı', 'lat': 38.5303, 'lng': 35.4475, 'alt': 3917},
      {'name': 'Süphan Dağı', 'lat': 38.9250, 'lng': 42.8250, 'alt': 4058},
      {'name': 'Kaçkar Dağı', 'lat': 40.8361, 'lng': 41.1611, 'alt': 3932},
      {'name': 'Uludağ', 'lat': 40.0658, 'lng': 29.2158, 'alt': 2543},
      {'name': 'Hasan Dağı', 'lat': 38.1256, 'lng': 34.1658, 'alt': 3268},
      {'name': 'Demirkazık Dağı', 'lat': 37.7997, 'lng': 35.1558, 'alt': 3756},
      {'name': 'Aladağlar', 'lat': 37.8183, 'lng': 35.1583, 'alt': 3756},
      {'name': 'Ilgaz Dağı', 'lat': 41.0717, 'lng': 33.7258, 'alt': 2587},
      {'name': 'Bozdağlar', 'lat': 38.3589, 'lng': 28.1189, 'alt': 2159},
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mountains.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = mountains[i];
        return ListTile(
          tileColor: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.white10)),
          leading: const Icon(Icons.terrain, color: kOrange, size: 30),
          title: Text(m['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('Rakım: ${m['alt']} m', style: const TextStyle(color: Colors.white54)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () {
            _fetchData(lat: m['lat'], lng: m['lng'], name: m['name']);
            _tabController.animateTo(0);
          },
        );
      },
    );
  }

  Widget _safeTabWrapper(Widget Function() builder, String tabName) {
    try {
      return builder();
    } catch (e) {
      debugPrint('Error in tab $tabName: $e');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text('$tabName ekranı yüklenemedi.', style: const TextStyle(color: Colors.white70)),
            TextButton(onPressed: _fetchData, child: const Text('Yenile', style: TextStyle(color: kOrange))),
          ],
        ),
      );
    }
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 0.5)),
      ],
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});
  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}
class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
  @override
  bool get wantKeepAlive => true;
}
