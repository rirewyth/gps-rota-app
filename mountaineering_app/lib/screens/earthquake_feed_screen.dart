import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mountaineering_app/services/earthquake_service.dart';
import '../services/tactical_styles.dart';

class EarthquakeFeedScreen extends StatefulWidget {
  const EarthquakeFeedScreen({Key? key}) : super(key: key);

  @override
  State<EarthquakeFeedScreen> createState() => _EarthquakeFeedScreenState();
}

class _EarthquakeFeedScreenState extends State<EarthquakeFeedScreen> {
  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kBackground = TacticalStyles.kSurface;

  final EarthquakeService _quakeService = EarthquakeService();
  final TextEditingController _searchController = TextEditingController();
  List<EarthquakeModel> _quakes = [];
  Position? _userPosition;
  bool _isLoading = true;
  double _minMagFilter = 0.0; // 0.0 = Tümü, 3.0, 4.0, 5.0
  bool _sortByMagnitude = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserPosition();
    _fetch();
  }

  Future<void> _loadUserPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() => _userPosition = last);
        return;
      }
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
        if (mounted) setState(() => _userPosition = pos);
      }
    } catch (_) {}
  }

  double? _distanceKm(EarthquakeModel q) {
    if (_userPosition == null || (q.lat == 0 && q.lng == 0)) return null;
    return Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          q.lat,
          q.lng,
        ) /
        1000.0;
  }

  void _showEpicenterSheet(EarthquakeModel q, Color accentColor, double? distKm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.all(16),
        decoration: TacticalStyles.glassCardDecoration(
          radius: 22,
          borderColor: accentColor.withOpacity(0.45),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.45)),
                  ),
                  child: Center(
                    child: Text(
                      q.mag.toStringAsFixed(1),
                      style: TacticalStyles.headline(color: accentColor, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.location,
                        style: TacticalStyles.headline(color: TacticalStyles.kOnSurface, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${q.date}  •  Derinlik: ${q.depth.toStringAsFixed(1)} km${distKm != null ? '  •  ${distKm.toStringAsFixed(0)} km uzakta' : ''}',
                        style: TacticalStyles.body(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: TacticalStyles.kOutline),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(q.lat, q.lng),
                    initialZoom: 8.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rotaplus.mountaineering',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(q.lat, q.lng),
                          width: 46,
                          height: 46,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withOpacity(0.28),
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            child: Center(
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final kandilli = await _quakeService.getRecentEarthquakes(minMag: 0.0);
      final aprs = await _quakeService.getAprsTacticalFeed();
      if (mounted) {
        setState(() {
          _quakes = [...aprs, ...kandilli];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EarthquakeModel> get _filteredQuakes {
    final qLower = _searchQuery.trim().toLowerCase();
    final filtered = _quakes.where((q) {
      if (q.mag < _minMagFilter) return false;
      if (qLower.isNotEmpty && !q.location.toLowerCase().contains(qLower)) {
        return false;
      }
      return true;
    }).toList();

    if (_sortByMagnitude) {
      filtered.sort((a, b) => b.mag.compareTo(a.mag));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final visibleQuakes = _filteredQuakes;
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TacticalStyles.kOnSurface),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: TacticalStyles.kError.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TacticalStyles.kError.withOpacity(0.35)),
              ),
              child: const Icon(Icons.sensors_rounded, color: TacticalStyles.kError, size: 18),
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
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: TacticalStyles.kError.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'DEPREM TAKİBİ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TacticalStyles.labelMicro(
                              color: TacticalStyles.kError,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Kandilli & APRS Canlı Sismik Akış',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kOnSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh_rounded, color: TacticalStyles.kOnSurfaceVariant),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(height: 1, child: ColoredBox(color: TacticalStyles.kOutlineVariant)),
        ),
      ),
      body: Column(
        children: [
          // ── ARAMA VE FİLTRELEME ÇUBUĞU ───────────────────────────────────
          Container(
            color: TacticalStyles.kSurfaceLowest,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Container(
                  decoration: TacticalStyles.recessedDecoration(radius: 14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TacticalStyles.body(color: TacticalStyles.kOnSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Bölge veya şehir ara (örn. Marmara, İzmir)...',
                      hintStyle: TacticalStyles.body(color: TacticalStyles.kOutline, fontSize: 12.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: TacticalStyles.kOnSurfaceVariant, size: 19),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: TacticalStyles.kOutline, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildMagFilterChip('TÜMÜ', 0.0),
                            const SizedBox(width: 6),
                            _buildMagFilterChip('M 3.0+', 3.0),
                            const SizedBox(width: 6),
                            _buildMagFilterChip('M 4.0+', 4.0),
                            const SizedBox(width: 6),
                            _buildMagFilterChip('M 5.0+', 5.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TacticalPressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _sortByMagnitude = !_sortByMagnitude);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _sortByMagnitude
                              ? kOrange.withOpacity(0.16)
                              : TacticalStyles.kSurfaceHigh.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _sortByMagnitude
                                ? kOrange.withOpacity(0.55)
                                : TacticalStyles.kOutlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sortByMagnitude ? Icons.bar_chart_rounded : Icons.schedule_rounded,
                              size: 13,
                              color: _sortByMagnitude ? kOrange : TacticalStyles.kOnSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortByMagnitude ? 'ŞİDDET' : 'SON',
                              style: TacticalStyles.labelMicro(
                                color: _sortByMagnitude ? kOrange : TacticalStyles.kOnSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── LİSTE ALANI ───────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kOrange))
                : visibleQuakes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sensors_off_rounded, color: TacticalStyles.kOutline, size: 42),
                              const SizedBox(height: 12),
                              Text(
                                'Seçili filtreye uygun sismik kayıt bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TacticalStyles.body(color: TacticalStyles.kOnSurfaceVariant, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: visibleQuakes.length,
                        itemBuilder: (context, index) {
                          final q = visibleQuakes[index];
                          final isCritical = q.mag >= 5.0;
                          final isSignificant = q.mag >= 4.0;
                          final accentColor = isCritical
                              ? TacticalStyles.kError
                              : (isSignificant ? kOrange : TacticalStyles.kSecondary);
                          final distKm = _distanceKm(q);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TacticalPressable(
                              onTap: () => _showEpicenterSheet(q, accentColor, distKm),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: TacticalStyles.glassCardDecoration(
                                  radius: 16,
                                  borderColor: isSignificant
                                      ? accentColor.withOpacity(0.40)
                                      : TacticalStyles.kOutlineVariant,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: accentColor.withOpacity(0.40)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          q.mag.toStringAsFixed(1),
                                          style: TacticalStyles.headline(
                                            color: accentColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            q.location,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TacticalStyles.headline(
                                              color: TacticalStyles.kOnSurface,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.schedule_rounded, size: 12, color: TacticalStyles.kOnSurfaceVariant),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    q.date,
                                                    style: TacticalStyles.body(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.layers_outlined, size: 12, color: TacticalStyles.kOnSurfaceVariant),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${q.depth.toStringAsFixed(1)} km',
                                                    style: TacticalStyles.body(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                              if (distKm != null)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.near_me_outlined, size: 12, color: TacticalStyles.kSecondary),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${distKm.toStringAsFixed(0)} km',
                                                      style: TacticalStyles.labelMicro(color: TacticalStyles.kSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: TacticalStyles.kOutline, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMagFilterChip(String label, double minMag) {
    final selected = _minMagFilter == minMag;
    return TacticalPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _minMagFilter = minMag);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kOrange : TacticalStyles.kSurfaceHigh.withOpacity(0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? kOrange : TacticalStyles.kOutlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TacticalStyles.labelMicro(
            color: selected ? Colors.white : TacticalStyles.kOnSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
