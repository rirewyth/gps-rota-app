import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tactical_styles.dart';

class GearPlannerScreen extends StatefulWidget {
  const GearPlannerScreen({super.key});

  @override
  State<GearPlannerScreen> createState() => _GearPlannerScreenState();
}

class _GearPlannerScreenState extends State<GearPlannerScreen> {
  static const String _storageKey = 'pro_gear_planner_v1';

  String _tripType = 'kamp'; // gunubirlik | kamp | kis
  String _altitudeTier = 'orta'; // dusuk | orta | yuksek
  int _hours = 8;
  int _people = 1;

  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _tripType = decoded['tripType'] ?? 'kamp';
        _altitudeTier = decoded['altitudeTier'] ?? 'orta';
        _hours = decoded['hours'] ?? 8;
        _people = decoded['people'] ?? 1;
        final List saved = decoded['items'] ?? [];
        _items
          ..clear()
          ..addAll(saved.map((e) => Map<String, dynamic>.from(e)));
      } catch (_) {
        _generatePresetItems();
      }
    } else {
      _generatePresetItems();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'tripType': _tripType,
        'altitudeTier': _altitudeTier,
        'hours': _hours,
        'people': _people,
        'items': _items,
      }),
    );
  }

  void _generatePresetItems() {
    final list = <Map<String, dynamic>>[
      {'id': '1', 'cat': 'GÜVENLİK', 'name': 'İlk Yardım & Termal Battaniye', 'grams': 320, 'done': false},
      {'id': '2', 'cat': 'GÜVENLİK', 'name': 'Kafa Lambası + Yedek Pil', 'grams': 140, 'done': false},
      {'id': '3', 'cat': 'GÜVENLİK', 'name': 'Düdük & Powerbank (20.000 mAh)', 'grams': 410, 'done': false},
      {'id': '4', 'cat': 'GİYİM', 'name': 'Su Geçirmez Gore-Tex Ceket', 'grams': 460, 'done': false},
      {'id': '5', 'cat': 'GİYİM', 'name': 'Termal İçlik & Polar Orta Katman', 'grams': 540, 'done': false},
      {'id': '6', 'cat': 'BESLENME', 'name': 'Matara / Hidrasyon Torbası', 'grams': 220, 'done': false},
      {'id': '7', 'cat': 'BESLENME', 'name': 'Yüksek Kalorili Enerji Barları', 'grams': 350, 'done': false},
    ];

    if (_tripType == 'kamp' || _tripType == 'kis') {
      list.addAll([
        {'id': '8', 'cat': 'KAMP', 'name': '4 Mevsim Çadır & Kazıklar', 'grams': 2200, 'done': false},
        {'id': '9', 'cat': 'KAMP', 'name': 'Uyku Tulumu (-10°C Konfor)', 'grams': 1350, 'done': false},
        {'id': '10', 'cat': 'KAMP', 'name': 'Şişme Mat & Ocak + Kartuş', 'grams': 890, 'done': false},
      ]);
    }

    if (_tripType == 'kis' || _altitudeTier == 'yuksek') {
      list.addAll([
        {'id': '11', 'cat': 'TEKNİK', 'name': 'Krampon & Kazma', 'grams': 1450, 'done': false},
        {'id': '12', 'cat': 'TEKNİK', 'name': 'Kask & Emniyet Kemeri', 'grams': 780, 'done': false},
        {'id': '13', 'cat': 'GİYİM', 'name': 'Kaz Tüyü Mont & Kar Eldiveni', 'grams': 820, 'done': false},
      ]);
    } else if (_altitudeTier == 'orta') {
      list.add({
        'id': '14',
        'cat': 'TEKNİK',
        'name': 'Karbon Trekking Batonu (Çift)',
        'grams': 440,
        'done': false,
      });
    }

    _items
      ..clear()
      ..addAll(list);
    _saveState();
  }

  double get _waterLiters {
    final base = _hours * 0.45;
    final altMult = _altitudeTier == 'yuksek' ? 1.3 : (_altitudeTier == 'orta' ? 1.15 : 1.0);
    return base * altMult * _people;
  }

  int get _caloriesKcal {
    final perHour = _tripType == 'kis' ? 420 : (_tripType == 'kamp' ? 350 : 290);
    final altMult = _altitudeTier == 'yuksek' ? 1.25 : 1.0;
    return (_hours * perHour * altMult * _people).round();
  }

  double get _totalWeightKg {
    final totalGrams = _items.fold<int>(0, (sum, item) => sum + ((item['grams'] ?? 0) as int));
    return (totalGrams / 1000.0) + _waterLiters;
  }

  double get _completionRatio {
    if (_items.isEmpty) return 0;
    final doneCount = _items.where((e) => e['done'] == true).length;
    return doneCount / _items.length;
  }

  void _addCustomItemDialog() {
    final nameCtrl = TextEditingController();
    final gramCtrl = TextEditingController(text: '250');
    String cat = 'TEKNİK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: TacticalStyles.kSurfaceLow,
          title: const Text('Özel Ekipman Ekle', style: TextStyle(color: TacticalStyles.kOnSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: TacticalStyles.kOnSurface),
                decoration: const InputDecoration(
                  labelText: 'Ekipman Adı',
                  labelStyle: TextStyle(color: TacticalStyles.kOnSurfaceVariant),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gramCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: TacticalStyles.kOnSurface),
                decoration: const InputDecoration(
                  labelText: 'Ağırlık (gram)',
                  labelStyle: TextStyle(color: TacticalStyles.kOnSurfaceVariant),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: cat,
                dropdownColor: TacticalStyles.kSurfaceLow,
                style: const TextStyle(color: TacticalStyles.kOnSurface),
                items: ['GÜVENLİK', 'TEKNİK', 'GİYİM', 'KAMP', 'BESLENME']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDlg(() => cat = v ?? 'TEKNİK'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final grams = int.tryParse(gramCtrl.text.trim()) ?? 200;
                setState(() {
                  _items.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'cat': cat,
                    'name': name,
                    'grams': grams,
                    'done': false,
                  });
                });
                _saveState();
                Navigator.pop(ctx);
              },
              child: const Text('Ekle', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
            Icon(Icons.backpack_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'EKİPMAN & KALORİ PRO',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Listeyi Sıfırla',
            icon: const Icon(Icons.refresh_rounded, color: TacticalStyles.kOnSurfaceVariant),
            onPressed: () {
              setState(_generatePresetItems);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        onPressed: _addCustomItemDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('EKİPMAN EKLE', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // Konfigürasyon Kartı
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 16,
                    borderColor: Colors.amber.withOpacity(0.3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EKSPEDİSYON PARAMETRELERİ',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildChip('Günübirlik', 'gunubirlik', _tripType, (v) {
                            setState(() {
                              _tripType = v;
                              _generatePresetItems();
                            });
                          }),
                          const SizedBox(width: 6),
                          _buildChip('Çok Gün Kamp', 'kamp', _tripType, (v) {
                            setState(() {
                              _tripType = v;
                              _generatePresetItems();
                            });
                          }),
                          const SizedBox(width: 6),
                          _buildChip('Kış / Buzul', 'kis', _tripType, (v) {
                            setState(() {
                              _tripType = v;
                              _generatePresetItems();
                            });
                          }),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildChip('<2000m', 'dusuk', _altitudeTier, (v) {
                            setState(() {
                              _altitudeTier = v;
                              _generatePresetItems();
                            });
                          }),
                          const SizedBox(width: 6),
                          _buildChip('2000-3500m', 'orta', _altitudeTier, (v) {
                            setState(() {
                              _altitudeTier = v;
                              _generatePresetItems();
                            });
                          }),
                          const SizedBox(width: 6),
                          _buildChip('3500m+', 'yuksek', _altitudeTier, (v) {
                            setState(() {
                              _altitudeTier = v;
                              _generatePresetItems();
                            });
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Süre: $_hours saat', style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            onPressed: _hours > 2 ? () { setState(() => _hours -= 2); _saveState(); } : null,
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.amber, size: 20),
                          ),
                          IconButton(
                            onPressed: () { setState(() => _hours += 2); _saveState(); },
                            icon: const Icon(Icons.add_circle_outline, color: Colors.amber, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Kişi: $_people', style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            onPressed: _people > 1 ? () { setState(() => _people--); _saveState(); } : null,
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.amber, size: 20),
                          ),
                          IconButton(
                            onPressed: () { setState(() => _people++); _saveState(); },
                            icon: const Icon(Icons.add_circle_outline, color: Colors.amber, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Özet Metrikler
                Row(
                  children: [
                    Expanded(child: _buildMetricBox('TOPLAM YÜK', '${_totalWeightKg.toStringAsFixed(1)} kg', TacticalStyles.kPrimary)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricBox('SU İHTİYACI', '${_waterLiters.toStringAsFixed(1)} L', TacticalStyles.kSecondaryContainer)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMetricBox('ENERJİ', '$_caloriesKcal kcal', TacticalStyles.kTertiary)),
                  ],
                ),

                const SizedBox(height: 12),

                // İlerleme Çubuğu
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: TacticalStyles.glassCardDecoration(radius: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ÇANTA HAZIRLIK DURUMU', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700)),
                          Text('${(_completionRatio * 100).round()}%', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _completionRatio,
                          minHeight: 7,
                          backgroundColor: TacticalStyles.kSurfaceLowest,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Ekipman Listesi
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final done = item['done'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: TacticalStyles.glassCardDecoration(
                      radius: 12,
                      borderColor: done ? TacticalStyles.kTertiary.withOpacity(0.4) : TacticalStyles.kOutlineVariant,
                    ),
                    child: CheckboxListTile(
                      value: done,
                      activeColor: TacticalStyles.kTertiary,
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setState(() => _items[idx]['done'] = val ?? false);
                        _saveState();
                      },
                      title: Text(
                        item['name'] ?? '',
                        style: TextStyle(
                          color: done ? TacticalStyles.kOnSurfaceVariant : TacticalStyles.kOnSurface,
                          decoration: done ? TextDecoration.lineThrough : null,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${item['cat']} • ${item['grams']} g',
                        style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 11),
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline, color: TacticalStyles.kOutline, size: 18),
                        onPressed: () {
                          setState(() => _items.removeAt(idx));
                          _saveState();
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildChip(String label, String val, String groupVal, ValueChanged<String> onTap) {
    final selected = val == groupVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.amber.withOpacity(0.18) : TacticalStyles.kSurfaceLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.amber : TacticalStyles.kOutlineVariant),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.amber : TacticalStyles.kOnSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: TacticalStyles.glassCardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
