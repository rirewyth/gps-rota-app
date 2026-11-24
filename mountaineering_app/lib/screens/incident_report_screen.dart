import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/tactical_styles.dart';
import '../storage_helper.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _summaryCtrl = TextEditingController();
  final TextEditingController _districtCtrl = TextEditingController();
  final TextEditingController _neighborhoodCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();

  String _selectedType = 'Deprem';
  String? _selectedProvince;
  String? _imageBase64;
  String _reporterIp = '';
  double? _lat;
  double? _lng;
  bool _locLoading = true;
  bool _submitting = false;
  late DateTime _reportTime;

  static const List<String> _provinces = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya', 'Ankara',
    'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir', 'Bartın', 'Batman',
    'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa',
    'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Düzce', 'Edirne',
    'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun',
    'Gümüşhane', 'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İstanbul', 'İzmir',
    'Kahramanmaraş', 'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri',
    'Kilis', 'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya',
    'Kütahya', 'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
    'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya', 'Samsun',
    'Şanlıurfa', 'Siirt', 'Sinop', 'Şırnak', 'Sivas', 'Tekirdağ', 'Tokat',
    'Trabzon', 'Tunceli', 'Uşak', 'Van', 'Yalova', 'Yozgat', 'Zonguldak',
  ];

  static const List<Map<String, dynamic>> _types = [
    {'label': 'Deprem', 'icon': Icons.waves_rounded, 'color': Colors.redAccent},
    {'label': 'Sel / Su Baskını', 'icon': Icons.water_drop_rounded, 'color': Colors.lightBlueAccent},
    {'label': 'Yangın', 'icon': Icons.local_fire_department_rounded, 'color': Colors.orangeAccent},
    {'label': 'Çığ', 'icon': Icons.ac_unit_rounded, 'color': Colors.cyanAccent},
    {'label': 'Heyelan', 'icon': Icons.landslide_rounded, 'color': Colors.amber},
    {'label': 'Kayıp / Mahsur', 'icon': Icons.person_search_rounded, 'color': Color(0xFFFF6E40)},
    {'label': 'Kaza / Yaralanma', 'icon': Icons.medical_services_rounded, 'color': Colors.pinkAccent},
    {'label': 'Diğer', 'icon': Icons.warning_amber_rounded, 'color': Colors.white70},
  ];

  @override
  void initState() {
    super.initState();
    _reportTime = DateTime.now();
    _loadDefaults();
    _fetchLocation();
    _fetchPublicIp();
  }

  Future<void> _fetchPublicIp() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse('https://api64.ipify.org?format=text'));
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final ip = (await res.transform(utf8.decoder).join()).trim();
        if (ip.isNotEmpty && mounted) {
          setState(() => _reporterIp = ip);
        }
      }
      client.close(force: true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _summaryCtrl.dispose();
    _districtCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _streetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final cUser = FirebaseAuth.instance.currentUser;
    String resolvedName = '';

    if (cUser != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(cUser.uid).get();
        final d = doc.data();
        final fsName = (d?['name'] ?? d?['username'] ?? d?['ad'] ?? '').toString().trim();
        if (fsName.isNotEmpty && fsName.toLowerCase() != 'anonim') {
          resolvedName = fsName;
        }
      } catch (_) {}
    }

    if (resolvedName.isEmpty) {
      final storedName = (await StorageHelper.getUserName() ?? '').trim();
      if (storedName.isNotEmpty && storedName.toLowerCase() != 'anonim') {
        resolvedName = storedName;
      }
    }

    if (resolvedName.isEmpty && cUser != null) {
      final dn = (cUser.displayName ?? '').trim();
      if (dn.isNotEmpty && dn.toLowerCase() != 'anonim') {
        resolvedName = dn;
      } else if ((cUser.email ?? '').contains('@')) {
        resolvedName = cUser.email!.split('@').first;
      }
    }

    final phone = await StorageHelper.getObserverPhone();
    if (!mounted) return;
    if (resolvedName.isNotEmpty) {
      _nameCtrl.text = resolvedName;
    }
    if (phone != null && phone.trim().isNotEmpty) {
      _phoneCtrl.text = phone.trim();
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _locLoading = true);
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _lat = last.latitude;
          _lng = last.longitude;
        });
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 6));
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _locLoading = false);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() => _imageBase64 = base64Encode(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _submitReport() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final summary = _summaryCtrl.text.trim();

    if (name.isEmpty || name.toLowerCase() == 'anonim') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen kendi adınızı ve soyadınızı girin (Anonim ihbar gönderilemez).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geri dönüş için telefon numarası girin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (summary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen olay özetini yazın.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final now = DateTime.now();
      final province = (_selectedProvince ?? '').trim();
      final district = _districtCtrl.text.trim();
      final neighborhood = _neighborhoodCtrl.text.trim();
      final street = _streetCtrl.text.trim();
      final addrParts = <String>[
        if (street.isNotEmpty) street,
        if (neighborhood.isNotEmpty) '$neighborhood Mah.',
        if (district.isNotEmpty && province.isNotEmpty)
          '$district / $province'
        else if (district.isNotEmpty)
          district
        else if (province.isNotEmpty)
          province,
      ];
      final fullAddress = addrParts.join(', ');

      if (_reporterIp.isEmpty) {
        await _fetchPublicIp();
      }
      if (_reporterIp.isNotEmpty) {
        final ipDocId = _reporterIp.replaceAll(':', '_');
        final ipBanDoc = await FirebaseFirestore.instance.collection('banned_ips').doc(ipDocId).get();
        if (ipBanDoc.exists) {
          if (mounted) {
            setState(() => _submitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu IP adresi asılsız ihbar nedeniyle engellenmiştir.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }
      await FirebaseFirestore.instance.collection('disaster_reports').add({
        'reportCategory': 'disaster_report',
        'disasterType': _selectedType,
        'reporterUid': user?.uid ?? '',
        'reporterName': name,
        'reporterPhone': phone,
        'reporterIp': _reporterIp,
        'summary': summary,
        'province': province,
        'district': district,
        'neighborhood': neighborhood,
        'street': street,
        'fullAddress': fullAddress,
        'dateTimeStr': _formatDateTime(now),
        'lat': _lat,
        'lng': _lng,
        'imageBase64': _imageBase64 ?? '',
        'status': 'YENİ',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ İhbarınız Admin Paneli ve ROTA+ NEXUS Komuta Merkezine iletildi!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İhbar gönderilemedi: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'AFET & OLAY İHBARI',
          style: TacticalStyles.headline(color: Colors.white, size: 17, weight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('İHBAR / AFET TÜRÜ', style: TacticalStyles.labelCaps(color: TacticalStyles.kPrimary, size: 11)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final label = t['label'] as String;
                final color = t['color'] as Color;
                final selected = _selectedType == label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.18) : TacticalStyles.kSurfaceLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? color : TacticalStyles.kOutlineVariant,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t['icon'] as IconData, color: color, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            _buildFieldLabel('AD SOYAD'),
            const SizedBox(height: 6),
            _buildInput(_nameCtrl, 'Adınız Soyadınız', Icons.person_outline_rounded),
            const SizedBox(height: 14),

            _buildFieldLabel('TELEFON NUMARASI *'),
            const SizedBox(height: 6),
            _buildInput(
              _phoneCtrl,
              '+90 5XX XXX XXXX',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            _buildFieldLabel('TARİH & SAAT'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: TacticalStyles.recessedDecoration(radius: 12),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: TacticalStyles.kPrimary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    _formatDateTime(_reportTime),
                    style: TacticalStyles.telemetry(color: TacticalStyles.kOnSurface, fontSize: 14),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _reportTime = DateTime.now()),
                    child: Text(
                      'GÜNCELLE',
                      style: TacticalStyles.labelMicro(color: TacticalStyles.kPrimary, size: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _buildFieldLabel('OLAY ÖZETİ *'),
            const SizedBox(height: 6),
            TextField(
              controller: _summaryCtrl,
              maxLines: 4,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Olayın durumu, konum tarifi, yaralı veya tehlike bilgisi...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: TacticalStyles.kSurfaceLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TacticalStyles.kPrimaryContainer),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 14),

            _buildFieldLabel('DETAYLI ADRES (İL / İLÇE / MAHALLE / SOKAK)'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickProvince,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: TacticalStyles.kSurfaceLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_city_rounded, color: TacticalStyles.kPrimaryContainer, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedProvince ?? 'İl Seç',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _selectedProvince != null ? Colors.white : Colors.white38,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    _districtCtrl,
                    'İlçe',
                    Icons.map_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    _neighborhoodCtrl,
                    'Mahalle',
                    Icons.holiday_village_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    _streetCtrl,
                    'Sokak / Cadde / No',
                    Icons.signpost_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildFieldLabel('GPS KONUMU'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: TacticalStyles.recessedDecoration(radius: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: _lat != null ? TacticalStyles.kTertiary : Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _locLoading
                          ? 'GPS konumu alınıyor...'
                          : (_lat != null && _lng != null
                              ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                              : 'Konum alınamadı (İnternet/GPS kontrol edin)'),
                      style: TacticalStyles.telemetry(color: TacticalStyles.kOnSurface, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: TacticalStyles.kPrimary, size: 18),
                    onPressed: _fetchLocation,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildFieldLabel('FOTOĞRAF EKLE (OPSİYONEL)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, color: TacticalStyles.kPrimaryContainer, size: 18),
                    label: const Text('Kamera', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TacticalStyles.kPrimaryContainer.withValues(alpha: 0.55)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, color: TacticalStyles.kPrimary, size: 18),
                    label: const Text('Galeri', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: TacticalStyles.kPrimary.withValues(alpha: 0.55)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
            if (_imageBase64 != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(_imageBase64!),
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageBase64 = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TacticalStyles.kPrimaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _submitting ? 'GÖNDERİLİYOR...' : 'İHBARI GÖNDER',
                  style: TacticalStyles.headline(color: Colors.white, size: 15, weight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _pickProvince() async {
    FocusScope.of(context).unfocus();
    String query = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TacticalStyles.kSurfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _provinces
                .where((p) => p.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (v) => setModalState(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'İl ara...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                        filled: true,
                        fillColor: TacticalStyles.kSurfaceLowest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final city = filtered[i];
                        final isSel = city == _selectedProvince;
                        return ListTile(
                          dense: true,
                          title: Text(
                            city,
                            style: TextStyle(
                              color: isSel ? TacticalStyles.kPrimaryContainer : Colors.white,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSel
                              ? const Icon(Icons.check_rounded, color: TacticalStyles.kPrimaryContainer, size: 18)
                              : null,
                          onTap: () => Navigator.pop(ctx, city),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedProvince = picked);
    }
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: TacticalStyles.labelCaps(color: TacticalStyles.kOnSurfaceVariant, size: 10.5),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: TacticalStyles.recessedDecoration(radius: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          icon: Icon(icon, color: TacticalStyles.kOutline, size: 18),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
