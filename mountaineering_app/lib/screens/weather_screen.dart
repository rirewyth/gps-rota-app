import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../screens/premium_screen.dart';
import '../services/barometer_service.dart';
import '../services/tactical_styles.dart';
import '../storage_helper.dart';

const kBackground = TacticalStyles.kSurface;
const kCardBg = TacticalStyles.kSurfaceContainer;
const kOrange = TacticalStyles.kPrimaryContainer;
const kGreen = TacticalStyles.kTertiary;
const kBlue = TacticalStyles.kSecondaryContainer;

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
  bool _barometerEnabled = false;
  String _locationName = 'Konumum';
  double? _searchAltitude;
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
    _isPremium = true;
    _barometerEnabled = await StorageHelper.getBarometerEnabled();

    if (_barometerEnabled) {
      BarometerService().startMonitoring();
      BarometerService().onStormWarning = (title, desc) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $desc'),
              backgroundColor: TacticalStyles.kErrorContainer,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      };
    }

    setState(() {});
    await _fetchData();
  }

  Future<void> _fetchData({double? lat, double? lng, String? name, double? altitude}) async {
    setState(() {
      _loading = true;
      _errorMsg = '';
      if (name != null) _locationName = name;
    });
    try {
      if (altitude != null) {
        _searchAltitude = altitude;
      }
      if (lat == null || lng == null) {
        bool svc = await Geolocator.isLocationServiceEnabled();
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }

        if (!svc || perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          lat = 41.0082;
          lng = 28.9784;
          _searchAltitude = 39.0;
          _locationName = 'İstanbul (Varsayılan)';
        } else {
          try {
            _pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
            ).timeout(const Duration(seconds: 8));
          } catch (e) {
            _pos = await Geolocator.getLastKnownPosition();
          }
          if (_pos == null) {
            lat = 41.0082;
            lng = 28.9784;
            _searchAltitude = 39.0;
            _locationName = 'İstanbul (Varsayılan)';
          } else {
            lat = _pos!.latitude;
            lng = _pos!.longitude;
            _searchAltitude = _pos!.altitude;
            _locationName = 'Konumum';
          }
        }
      }

      if (_isPremium) {
        _data = await WeatherService.getFullWeatherData(lat, lng, altitudeMeters: _searchAltitude ?? 0);
        if (_data == null) {
          _errorMsg = 'Hava durumu verileri alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
        }
      } else {
        final simple = await WeatherService.checkStormRisk(lat, lng, elevation: _searchAltitude);
        if (simple != null && !simple.isLoading) {
          _data = FullWeatherData(
            current: simple,
            hourly: [],
            daily: [],
            risks: MountainRiskIndex(
              frostbiteRisk: 0,
              lightningRisk: 0,
              avalancheRisk: 0,
              windRisk: 0,
              overallRisk: 0,
              windChill: simple.temperature,
              overallLabel: 'Detay için Premium',
              overallColor: 'green',
            ),
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
          backgroundColor: TacticalStyles.kSurfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: TacticalStyles.kGlassBorder),
          ),
          title: Row(
            children: [
              const Icon(Icons.radar_rounded, color: TacticalStyles.kPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                'BÖLGE / İSTASYON ARA',
                style: TacticalStyles.headline(
                  color: TacticalStyles.kOnSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                style: TacticalStyles.body(color: TacticalStyles.kOnSurface),
                decoration: InputDecoration(
                  hintText: 'Örn: İzmir, Erciyes, Alanya...',
                  hintStyle: TacticalStyles.body(color: TacticalStyles.kOutline),
                  filled: true,
                  fillColor: TacticalStyles.kSurfaceLowest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: kOrange),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search_rounded, color: kOrange),
                          onPressed: () async {
                            if (_searchCtrl.text.isEmpty) return;
                            setDialogState(() => _isSearching = true);
                            final results = await WeatherService.searchLocations(_searchCtrl.text);
                            setDialogState(() {
                              _searchResults = results;
                              _isSearching = false;
                            });
                          },
                        ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TacticalStyles.kGlassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kOrange),
                  ),
                ),
                onSubmitted: (val) async {
                  if (val.isEmpty) return;
                  setDialogState(() => _isSearching = true);
                  final results = await WeatherService.searchLocations(val);
                  setDialogState(() {
                    _searchResults = results;
                    _isSearching = false;
                  });
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                width: double.maxFinite,
                child: _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          'SONUÇ BULUNAMADI',
                          style: TacticalStyles.labelCaps(color: TacticalStyles.kOutline, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final loc = _searchResults[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            title: Text(
                              loc.name,
                              style: TacticalStyles.headline(
                                color: TacticalStyles.kOnSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${loc.admin1}, ${loc.country} • ${loc.elevation.toInt()}m',
                              style: TacticalStyles.labelMicro(
                                color: TacticalStyles.kOnSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _fetchData(
                                lat: loc.lat,
                                lng: loc.lng,
                                name: loc.name,
                                altitude: loc.elevation,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'KAPAT',
                style: TacticalStyles.labelCaps(
                  color: TacticalStyles.kPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
        backgroundColor: TacticalStyles.kSurface.withOpacity(0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: TacticalStyles.kOnSurface),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: TacticalStyles.kTertiary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TacticalStyles.kTertiary.withOpacity(0.30),
                ),
              ),
              child: const Icon(
                Icons.cloud_done_outlined,
                color: TacticalStyles.kTertiary,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'ROTA+',
                        style: TacticalStyles.headline(
                          color: TacticalStyles.kOnSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TacticalStyles.kPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'METEOROLOJİ',
                          style: TacticalStyles.labelMicro(
                            color: TacticalStyles.kPrimary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _locationName,
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kOnSurfaceVariant,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: _showSearchDialog,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TacticalStyles.kSurfaceHigh.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: TacticalStyles.kGlassBorder),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: TacticalStyles.kOnSurfaceVariant,
                  size: 18,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _fetchData(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TacticalStyles.kSurfaceHigh.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: TacticalStyles.kGlassBorder),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: TacticalStyles.kPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
        bottom: _isPremium
            ? PreferredSize(
                preferredSize: const Size.fromHeight(54),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: TacticalStyles.kSurfaceLow.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: TacticalStyles.kGlassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.40),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: TacticalStyles.kSurfaceHigh,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: TacticalStyles.kPrimaryContainer.withOpacity(0.45),
                          width: 1,
                        ),
                      ),
                      labelColor: TacticalStyles.kPrimary,
                      unselectedLabelColor: TacticalStyles.kOnSurfaceVariant,
                      labelStyle: TacticalStyles.labelCaps(
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        letterSpacing: 0.7,
                      ),
                      unselectedLabelStyle: TacticalStyles.labelCaps(
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                      ),
                      tabs: const [
                        Tab(text: 'ANLIK'),
                        Tab(text: 'SAATLİK'),
                        Tab(text: '7 GÜN'),
                        Tab(text: 'DAĞLAR'),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: TacticalStyles.glassCardDecoration(radius: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: TacticalStyles.kOutline, size: 48),
                          const SizedBox(height: 14),
                          Text(
                            'VERİ ALINAMIYOR',
                            style: TacticalStyles.headline(
                              color: TacticalStyles.kOnSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMsg,
                            textAlign: TextAlign.center,
                            style: TacticalStyles.body(
                              color: TacticalStyles.kOnSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'TEKRAR DENE',
                              style: TacticalStyles.labelCaps(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _data == null
                  ? Center(
                      child: Text(
                        'VERİ ALINAMIYOR',
                        style: TacticalStyles.labelCaps(color: TacticalStyles.kOnSurfaceVariant),
                      ),
                    )
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
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildCurrentCard(w),
          const SizedBox(height: 20),
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
        decoration: TacticalStyles.glassCardDecoration(
          radius: 16,
          borderColor: TacticalStyles.kPrimaryContainer.withOpacity(0.45),
        ),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: TacticalStyles.kPrimaryContainer, size: 36),
            const SizedBox(height: 10),
            Text(
              'ROTA+ PRO METEOROLOJİ',
              style: TacticalStyles.headline(
                color: TacticalStyles.kOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Saatlik & 7 günlük tahmin\nDağcılık Risk İndeksi (Çığ · Şimşek · Donma)\nRüzgar Soğuma & İrtifa Analizi',
              textAlign: TextAlign.center,
              style: TacticalStyles.body(
                color: TacticalStyles.kOnSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: TacticalStyles.kPrimaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'PRO\'YA YÜKSELT',
                style: TacticalStyles.labelCaps(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CURRENT tab (Stitch Tactical Liquid Glass) ──────────────────────────────
  Widget _buildCurrentTab() {
    final w = _data!.current;
    final r = _data!.risks;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status Strip (Location + Altitude)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: _showSearchDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: TacticalStyles.capsuleDecoration(
                      backgroundColor: TacticalStyles.kSurfaceHigh.withOpacity(0.90),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulsingStatusIndicator(
                          color: TacticalStyles.kTertiary,
                          size: 8,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _locationName.toUpperCase(),
                            style: TacticalStyles.labelCaps(
                              color: TacticalStyles.kOnSurface,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit_location_alt_outlined,
                            color: TacticalStyles.kPrimary, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              if (_searchAltitude != null && _searchAltitude! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: TacticalStyles.capsuleDecoration(
                    backgroundColor: TacticalStyles.kSurfaceContainer.withOpacity(0.75),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.terrain_rounded,
                          color: TacticalStyles.kTertiary, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'RAKIM: ${_searchAltitude!.toInt()}M',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kTertiary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Hero GÜVENLİ METEOROLOJİ Card (Stitch 1:1)
          _buildCurrentCard(w),

          if (_data!.advancedAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildAdvancedAlerts(_data!.advancedAlerts),
          ],

          const SizedBox(height: 10),

          // 2. Dual Telemetry Hub: Barometre & Rüzgar Vektörü
          _buildDualAtmosphericHub(w, r),

          if (_barometerEnabled) ...[
            const SizedBox(height: 10),
            _buildOfflineBarometerCard(),
          ],

          const SizedBox(height: 10),

          // 3. Operasyonel Dağcılık Risk İndeksi
          _buildRiskIndex(r),

          const SizedBox(height: 10),

          // 4. Atmosferik Detay Telemetri Grid
          _buildDetailGrid(w),

          if (_searchAltitude != null && _searchAltitude! > 0) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'TÜM TELEMETRİ VERİLERİ ${_searchAltitude!.toInt()}M İRTİFAYA GÖRE HESAPLANMIŞTIR',
                textAlign: TextAlign.center,
                style: TacticalStyles.labelMicro(
                  color: TacticalStyles.kOutline,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── HERO TELEMETRY: GÜVENLİ METEOROLOJİ WIDGET (Stitch 1:1) ───────────────
  Widget _buildCurrentCard(WeatherAlertInfo w) {
    final label = WeatherService.weatherLabel(w.weatherCode);
    final bool hazardous = w.isHazardous;
    final Color statusColor =
        hazardous ? TacticalStyles.kPrimaryContainer : TacticalStyles.kTertiary;
    final String titleText =
        hazardous ? 'RİSKLİ METEOROLOJİ' : 'GÜVENLİ METEOROLOJİ';
    final String badgeText = hazardous ? 'DİKKAT' : 'OPTIMAL';
    final String summaryText = w.description.isNotEmpty
        ? '$label • ${w.description}'
        : (hazardous
            ? '$label • Saha koşulları dikkat gerektiriyor'
            : '$label • Hava yürüyüş ve operasyon için uygun');

    final int? pressureVal = (w.pressure ?? w.seaLevelPressure)?.toInt();
    final int? humidityVal = w.humidity?.toInt();
    final int windVal = w.windSpeed.toInt();

    final double pressureFactor = pressureVal != null
        ? ((pressureVal - 960) / 80.0).clamp(0.12, 1.0)
        : 0.0;
    final double humidityFactor = humidityVal != null
        ? (humidityVal / 100.0).clamp(0.08, 1.0)
        : 0.0;
    final double windFactor = (windVal / 60.0).clamp(0.10, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: TacticalStyles.glassCardDecoration(
        radius: 16,
        borderColor: hazardous
            ? TacticalStyles.kPrimaryContainer.withOpacity(0.45)
            : null,
        glowColor: statusColor,
      ),
      child: Column(
        children: [
          Container(
            height: 1.2,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.28),
                  statusColor.withOpacity(0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hazardous
                      ? Icons.thunderstorm_outlined
                      : Icons.cloud_done_outlined,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          titleText,
                          style: TacticalStyles.headline(
                            color: TacticalStyles.kOnSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: TacticalStyles.labelMicro(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summaryText,
                      style: TacticalStyles.body(
                        color: TacticalStyles.kOnSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.north_east_rounded,
                        color: TacticalStyles.kPrimaryContainer,
                        size: 18,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${w.temperature.toStringAsFixed(0)}°',
                        style: TacticalStyles.headline(
                          color: TacticalStyles.kPrimaryContainer,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'ISI İNDEKSİ',
                    style: TacticalStyles.labelMicro(
                      color: TacticalStyles.kOutline,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3 Vector Telemetry Strips (Basınç / Nem / Rüzgar)
          Row(
            children: [
              Expanded(
                child: _buildVectorStrip(
                  label: 'BASINÇ',
                  icon: Icons.speed_rounded,
                  iconColor: TacticalStyles.kTertiary,
                  value: pressureVal != null ? '$pressureVal' : '--',
                  unit: 'hPa',
                  progress: pressureFactor,
                  barColor: TacticalStyles.kTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVectorStrip(
                  label: 'NEM',
                  icon: Icons.water_drop_outlined,
                  iconColor: TacticalStyles.kSecondary,
                  value: humidityVal != null ? '$humidityVal' : '--',
                  unit: '%',
                  progress: humidityFactor,
                  barColor: TacticalStyles.kSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildVectorStrip(
                  label: 'RÜZGAR',
                  icon: Icons.air_rounded,
                  iconColor: TacticalStyles.kPrimary,
                  value: '$windVal',
                  unit: 'km/h',
                  progress: windFactor,
                  barColor: TacticalStyles.kPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVectorStrip({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required double progress,
    required Color barColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TacticalStyles.kSurfaceHigh.withOpacity(0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TacticalStyles.labelMicro(
                  color: TacticalStyles.kOutline,
                  fontSize: 9,
                ),
              ),
              Icon(icon, color: iconColor, size: 14),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TacticalStyles.headline(
                  color: TacticalStyles.kOnSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  unit,
                  style: TacticalStyles.labelMicro(
                    color: TacticalStyles.kOutline,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TacticalAnimatedBar(
            factor: progress,
            color: barColor,
            height: 4.5,
          ),
        ],
      ),
    );
  }

  // ── DUAL ATMOSPHERIC HUB (Barometre & Rüzgar Vektörü) ───────────────────────
  Widget _buildDualAtmosphericHub(WeatherAlertInfo w, MountainRiskIndex r) {
    final int? pressureVal = (w.pressure ?? w.seaLevelPressure)?.toInt();
    final String dirCardinal = _cardinalFromDeg(w.windDirection);

    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 142),
            padding: const EdgeInsets.all(15),
            decoration: TacticalStyles.glassCardDecoration(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BAROMETRE',
                      style: TacticalStyles.labelCaps(
                        color: TacticalStyles.kOutline,
                        fontSize: 10.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TacticalStyles.kSurfaceHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pressureVal != null && pressureVal < 1005 ? 'DÜŞÜŞ' : 'STABİL',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kTertiary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        pressureVal != null ? '$pressureVal' : '--',
                        style: TacticalStyles.displayHero(
                          color: TacticalStyles.kOnSurface,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'hPa',
                        style: TacticalStyles.headline(
                          color: TacticalStyles.kPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSurfaceHigh.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ÇİĞ NOKTASI',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kOutline,
                          fontSize: 8.5,
                        ),
                      ),
                      Text(
                        '${w.dewPoint?.toStringAsFixed(1) ?? '--'}°C',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 142),
            padding: const EdgeInsets.all(15),
            decoration: TacticalStyles.glassCardDecoration(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RÜZGAR YÖNÜ',
                      style: TacticalStyles.labelCaps(
                        color: TacticalStyles.kOutline,
                        fontSize: 10.5,
                      ),
                    ),
                    const Icon(
                      Icons.explore_outlined,
                      color: TacticalStyles.kPrimaryContainer,
                      size: 16,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${w.windDirection.toInt()}°',
                        style: TacticalStyles.displayHero(
                          color: TacticalStyles.kOnSurface,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dirCardinal,
                        style: TacticalStyles.headline(
                          color: TacticalStyles.kPrimaryContainer,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSurfaceHigh.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: TacticalStyles.kPrimaryContainer,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'HİSSEDİLEN',
                            style: TacticalStyles.labelMicro(
                              color: TacticalStyles.kOnSurface,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${r.windChill.toStringAsFixed(1)}°C',
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _cardinalFromDeg(double deg) {
    if (deg > 337.5 || deg <= 22.5) return 'K';
    if (deg > 22.5 && deg <= 67.5) return 'KD';
    if (deg > 67.5 && deg <= 112.5) return 'D';
    if (deg > 112.5 && deg <= 157.5) return 'GD';
    if (deg > 157.5 && deg <= 202.5) return 'G';
    if (deg > 202.5 && deg <= 247.5) return 'GB';
    if (deg > 247.5 && deg <= 292.5) return 'B';
    return 'KB';
  }

  Widget _buildOfflineBarometerCard() {
    return StreamBuilder<double>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => BarometerService().currentPressure),
      builder: (context, snapshot) {
        final val = snapshot.data ?? 0.0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: TacticalStyles.glassCardDecoration(
            radius: 16,
            borderColor: kBlue.withOpacity(0.35),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sensors_rounded, color: kBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CİHAZ BAROMETRE SENSÖRÜ',
                      style: TacticalStyles.labelCaps(
                        color: TacticalStyles.kOnSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Çevrimdışı donanım sensörü okuması',
                      style: TacticalStyles.body(
                        color: TacticalStyles.kOnSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                val > 0 ? val.toStringAsFixed(1) : '--',
                style: TacticalStyles.headline(
                  color: TacticalStyles.kOnSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'hPa',
                style: TacticalStyles.labelMicro(
                  color: TacticalStyles.kOutline,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdvancedAlerts(List<AdvancedAlert> alerts) {
    return Column(
      children: alerts.map((a) {
        final color = a.severity == 'critical'
            ? TacticalStyles.kError
            : (a.severity == 'warning' ? kOrange : kBlue);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: TacticalStyles.glassCardDecoration(
            radius: 14,
            borderColor: color.withOpacity(0.45),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title.toUpperCase(),
                      style: TacticalStyles.labelCaps(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a.message,
                      style: TacticalStyles.body(
                        color: TacticalStyles.kOnSurface,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── DAĞCILIK GÜVENLİK & RİSK İNDEKSİ (Stitch Tactical Overview HUD) ─────────
  Widget _buildRiskIndex(MountainRiskIndex r) {
    final overallColor = r.overallColor == 'red'
        ? TacticalStyles.kError
        : (r.overallColor == 'orange' ? kOrange : kGreen);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TacticalStyles.glassCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  PulsingStatusIndicator(color: overallColor, size: 8),
                  const SizedBox(width: 8),
                  Text(
                    'DAĞCILIK RİSK İNDEKSİ',
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kOnSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: overallColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined, color: overallColor, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      r.overallLabel.toUpperCase(),
                      style: TacticalStyles.labelMicro(
                        color: overallColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRiskBar('DONMA RİSKİ', r.frostbiteRisk, kBlue),
          const SizedBox(height: 10),
          _buildRiskBar('ŞİMŞEK & FIRTINA', r.lightningRisk, TacticalStyles.kPrimary),
          const SizedBox(height: 10),
          _buildRiskBar('ÇIĞ RİSKİ', r.avalancheRisk, TacticalStyles.kOnSurface),
          const SizedBox(height: 10),
          _buildRiskBar('RÜZGAR ŞİDDETİ', r.windRisk, kOrange),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: TacticalStyles.kSurfaceHigh.withOpacity(0.65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.thermostat_rounded,
                        color: TacticalStyles.kSecondaryContainer, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'RÜZGAR SOĞUMASI: ',
                      style: TacticalStyles.labelMicro(
                        color: TacticalStyles.kOutline,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      '${r.windChill.toStringAsFixed(1)}°C',
                      style: TacticalStyles.telemetry(
                        color: TacticalStyles.kOnSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'SKOR: ',
                      style: TacticalStyles.labelMicro(
                        color: TacticalStyles.kOutline,
                        fontSize: 9.5,
                      ),
                    ),
                    Text(
                      '${r.overallRisk}/100',
                      style: TacticalStyles.telemetry(
                        color: overallColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
    final barColor = value >= 70
        ? TacticalStyles.kError
        : (value >= 40 ? kOrange : color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TacticalStyles.labelMicro(
                color: TacticalStyles.kOnSurface,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '%$value',
              style: TacticalStyles.telemetry(
                color: barColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        TacticalAnimatedBar(
          factor: (value / 100).clamp(0.04, 1.0),
          color: barColor,
          height: 5,
        ),
      ],
    );
  }

  Widget _buildDetailGrid(WeatherAlertInfo w) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.15,
      children: [
        _buildGridCard(Icons.wb_sunny_outlined, '${w.uvIndex?.toStringAsFixed(1) ?? '--'}', 'UV İNDEKSİ', TacticalStyles.kPrimary),
        _buildGridCard(Icons.cloud_outlined, '%${w.cloudCover?.toInt() ?? '--'}', 'BULUT ÖRTÜSÜ', TacticalStyles.kOnSurfaceVariant),
        _buildGridCard(Icons.visibility_outlined, '${((w.visibility ?? 0) / 1000).toStringAsFixed(1)} km', 'GÖRÜŞ MESAFESİ', kBlue),
        _buildGridCard(Icons.water_outlined, '${w.precipitation?.toStringAsFixed(1) ?? '0.0'} mm', 'YAĞIŞ MİKTARI', kBlue),
        _buildGridCard(Icons.umbrella_outlined, '%${w.precipitationProbability?.toInt() ?? '--'}', 'YAĞIŞ OLASILIĞI', TacticalStyles.kSecondary),
        _buildGridCard(Icons.speed_rounded, '${w.seaLevelPressure?.toInt() ?? w.pressure?.toInt() ?? '--'} hPa', 'DENİZ BASINCI', kGreen),
      ],
    );
  }

  Widget _buildGridCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: TacticalStyles.glassCardDecoration(radius: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TacticalStyles.labelMicro(
                    color: TacticalStyles.kOutline,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TacticalStyles.headline(
                    color: TacticalStyles.kOnSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HOURLY tab ───────────────────────────────────────────────────────────────
  Widget _buildHourlyTab() {
    final hours = _data!.hourly;
    if (hours.isEmpty) {
      return Center(
        child: Text(
          'SAATLİK VERİ BULUNAMADI',
          style: TacticalStyles.labelCaps(color: TacticalStyles.kOnSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      itemCount: hours.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final h = hours[i];
        final now = DateTime.now();
        final isPast = h.time.isBefore(now.subtract(const Duration(minutes: 59)));
        final timeStr = '${h.time.hour.toString().padLeft(2, '0')}:00';
        final emoji = WeatherService.weatherEmoji(h.weatherCode);
        final isRainy = h.precipitation > 0.5;
        final isWindy = h.windSpeed > 30;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: TacticalStyles.glassCardDecoration(radius: 14),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: TacticalStyles.telemetry(
                        color: isPast ? TacticalStyles.kOutline : TacticalStyles.kOnSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isPast)
                      Text(
                        'GEÇMİŞ',
                        style: TacticalStyles.labelMicro(
                          color: kOrange,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${h.temperature.toStringAsFixed(1)}°C',
                      style: TacticalStyles.headline(
                        color: TacticalStyles.kOnSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      WeatherService.weatherLabel(h.weatherCode),
                      style: TacticalStyles.body(
                        color: TacticalStyles.kOnSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRainy) _buildMiniChip('${h.precipitation.toStringAsFixed(1)}mm', kBlue),
              const SizedBox(width: 6),
              if (isWindy) _buildMiniChip('${h.windSpeed.toInt()} km/h', kOrange),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '%${h.humidity.toInt()}',
                    style: TacticalStyles.telemetry(
                      color: TacticalStyles.kOnSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'ÇN ${h.dewPoint.toStringAsFixed(1)}°',
                    style: TacticalStyles.labelMicro(
                      color: kBlue,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TacticalStyles.labelMicro(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── DAILY tab ────────────────────────────────────────────────────────────────
  Widget _buildDailyTab() {
    final days = _data!.daily;
    if (days.isEmpty) {
      return Center(
        child: Text(
          'GÜNLÜK VERİ BULUNAMADI',
          style: TacticalStyles.labelCaps(color: TacticalStyles.kOnSurfaceVariant),
        ),
      );
    }

    final dayNames = ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = days[i];
        final isToday = i == 0;
        final dayName = isToday ? 'BUGÜN' : dayNames[d.date.weekday - 1];
        final emoji = WeatherService.weatherEmoji(d.weatherCode);
        final hasSnow = d.snowfallSum > 0;
        final hasRain = d.precipitationSum > 0.5;
        final isStormy = [95, 96, 99].contains(d.weatherCode);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: TacticalStyles.glassCardDecoration(
            radius: 14,
            borderColor: isToday
                ? TacticalStyles.kPrimaryContainer.withOpacity(0.45)
                : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      dayName,
                      style: TacticalStyles.labelCaps(
                        color: isToday ? kOrange : TacticalStyles.kOnSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      WeatherService.weatherLabel(d.weatherCode),
                      style: TacticalStyles.body(
                        color: TacticalStyles.kOnSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Text(
                    '${d.tempMin.toInt()}°',
                    style: TacticalStyles.telemetry(
                      color: kBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    ' / ',
                    style: TacticalStyles.telemetry(color: TacticalStyles.kOutline),
                  ),
                  Text(
                    '${d.tempMax.toInt()}°C',
                    style: TacticalStyles.telemetry(
                      color: TacticalStyles.kOnSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (hasRain || hasSnow || isStormy || d.windSpeedMax > 30 || d.uvIndexMax > 6) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (hasRain) _buildMiniChip('YAĞIŞ ${d.precipitationSum.toStringAsFixed(1)}mm', kBlue),
                    if (hasSnow) _buildMiniChip('KAR ${d.snowfallSum.toStringAsFixed(1)}cm', TacticalStyles.kOnSurface),
                    if (d.windSpeedMax > 30) _buildMiniChip('RÜZGAR ${d.windSpeedMax.toInt()}km/h', kOrange),
                    if (d.uvIndexMax > 6) _buildMiniChip('UV ${d.uvIndexMax.toInt()}', TacticalStyles.kPrimary),
                    if (isStormy) _buildMiniChip('FIRTINA UYARISI', TacticalStyles.kError),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      itemCount: mountains.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = mountains[i];
        return Container(
          decoration: TacticalStyles.glassCardDecoration(radius: 14),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kOrange.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.terrain_rounded, color: TacticalStyles.kPrimary, size: 22),
            ),
            title: Text(
              m['name'],
              style: TacticalStyles.headline(
                color: TacticalStyles.kOnSurface,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              '${(m['lat'] as double).toStringAsFixed(4)}°N, ${(m['lng'] as double).toStringAsFixed(4)}°E',
              style: TacticalStyles.telemetry(
                color: TacticalStyles.kOnSurfaceVariant,
                fontSize: 11,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TacticalStyles.kSurfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${m['alt']} M',
                style: TacticalStyles.labelCaps(
                  color: TacticalStyles.kTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            onTap: () {
              _fetchData(
                lat: m['lat'],
                lng: m['lng'],
                name: m['name'],
                altitude: (m['alt'] as num).toDouble(),
              );
              _tabController.animateTo(0);
            },
          ),
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
            const Icon(Icons.error_outline_rounded, color: TacticalStyles.kError, size: 48),
            const SizedBox(height: 16),
            Text(
              '$tabName ekranı yüklenemedi.',
              style: TacticalStyles.body(color: TacticalStyles.kOnSurfaceVariant),
            ),
            TextButton(
              onPressed: _fetchData,
              child: Text(
                'YENİLE',
                style: TacticalStyles.labelCaps(
                  color: kOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
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
