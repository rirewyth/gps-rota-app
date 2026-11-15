import 'dart:async';
import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import '../services/tactical_styles.dart';

class TacticalBeaconScreen extends StatefulWidget {
  const TacticalBeaconScreen({super.key});

  @override
  State<TacticalBeaconScreen> createState() => _TacticalBeaconScreenState();
}

class _TacticalBeaconScreenState extends State<TacticalBeaconScreen> {
  static const Map<String, String> _morseMap = {
    'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
    'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
    'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
    'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
    'Y': '-.--', 'Z': '--..',
    '0': '-----', '1': '.----', '2': '..---', '3': '...--', '4': '....-',
    '5': '.....', '6': '-....', '7': '--...', '8': '---..', '9': '----.',
  };

  final TextEditingController _msgCtrl = TextEditingController(text: 'SOS');
  bool _isTransmitting = false;
  bool _lightOn = false;
  bool _loopRepeat = true;
  bool _screenNightRed = false;
  bool _screenWhiteStrobe = false;
  String _currentSymbol = '';

  String get _encodedMorse {
    final upper = _msgCtrl.text.toUpperCase()
        .replaceAll('Ç', 'C')
        .replaceAll('Ğ', 'G')
        .replaceAll('İ', 'I')
        .replaceAll('Ö', 'O')
        .replaceAll('Ş', 'S')
        .replaceAll('Ü', 'U');
    return upper.split('').map((ch) {
      if (ch == ' ') return '/';
      return _morseMap[ch] ?? '';
    }).where((s) => s.isNotEmpty).join(' ');
  }

  Future<void> _setTorch(bool on) async {
    if (mounted) setState(() => _lightOn = on);
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
    } catch (_) {}
  }

  Future<void> _startMorseBroadcast() async {
    if (_isTransmitting) {
      setState(() {
        _isTransmitting = false;
        _currentSymbol = '';
      });
      await _setTorch(false);
      return;
    }

    final code = _encodedMorse;
    if (code.isEmpty) return;

    setState(() => _isTransmitting = true);

    do {
      for (int i = 0; i < code.length; i++) {
        if (!mounted || !_isTransmitting) break;
        final ch = code[i];
        setState(() => _currentSymbol = ch);

        if (ch == '.') {
          await _setTorch(true);
          await Future.delayed(const Duration(milliseconds: 180));
          await _setTorch(false);
          await Future.delayed(const Duration(milliseconds: 180));
        } else if (ch == '-') {
          await _setTorch(true);
          await Future.delayed(const Duration(milliseconds: 540));
          await _setTorch(false);
          await Future.delayed(const Duration(milliseconds: 180));
        } else if (ch == ' ') {
          await Future.delayed(const Duration(milliseconds: 360));
        } else if (ch == '/') {
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }
      if (_loopRepeat && _isTransmitting) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } while (_loopRepeat && _isTransmitting && mounted);

    if (mounted) {
      setState(() {
        _isTransmitting = false;
        _currentSymbol = '';
      });
      await _setTorch(false);
    }
  }

  @override
  void dispose() {
    _isTransmitting = false;
    _msgCtrl.dispose();
    TorchLight.disableTorch().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screenNightRed || _screenWhiteStrobe) {
      return GestureDetector(
        onTap: () => setState(() {
          _screenNightRed = false;
          _screenWhiteStrobe = false;
        }),
        child: Scaffold(
          backgroundColor: _screenNightRed ? const Color(0xFF9E0000) : Colors.white,
          body: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'KAPATMAK İÇİN DOKUNUN',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.flashlight_on_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'MORS & SİNYAL İSTASYONU PRO',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Canlı Sinyal Göstergesi
          AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _lightOn ? Colors.amber.withOpacity(0.28) : TacticalStyles.kSurfaceLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _lightOn ? Colors.amber : TacticalStyles.kOutlineVariant,
                width: _lightOn ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _lightOn ? Icons.wb_sunny_rounded : Icons.wifi_tethering_rounded,
                  color: _lightOn ? Colors.amber : TacticalStyles.kOnSurfaceVariant,
                  size: 46,
                ),
                const SizedBox(height: 10),
                Text(
                  _isTransmitting
                      ? (_lightOn ? 'SİNYAL GÖNDERİLİYOR ($_currentSymbol)' : 'BEKLEME ARALIĞI')
                      : 'MORS FENERİ HAZIR',
                  style: TextStyle(
                    color: _lightOn ? Colors.amber : TacticalStyles.kOnSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _encodedMorse.isEmpty ? '---' : _encodedMorse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TacticalStyles.kTertiary, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Özel Mesaj Girişi
          TextField(
            controller: _msgCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: TacticalStyles.kOnSurface, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Mors Kodu Mesajı',
              labelStyle: const TextStyle(color: TacticalStyles.kOnSurfaceVariant),
              filled: true,
              fillColor: TacticalStyles.kSurfaceLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 10),

          // Hızlı Mesaj Şablonları
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['SOS', 'YARDIM', 'SU', 'KIRIK', 'KAMP'].map((preset) {
              return ActionChip(
                backgroundColor: TacticalStyles.kSurfaceLow,
                side: const BorderSide(color: TacticalStyles.kOutlineVariant),
                label: Text(preset, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                onPressed: () {
                  _msgCtrl.text = preset;
                  setState(() {});
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          SwitchListTile(
            value: _loopRepeat,
            activeColor: Colors.amber,
            title: const Text('Sürekli Döngüde Yayınla', style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 13, fontWeight: FontWeight.w600)),
            onChanged: (v) => setState(() => _loopRepeat = v),
          ),

          const SizedBox(height: 8),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTransmitting ? Colors.redAccent : Colors.amber,
              foregroundColor: _isTransmitting ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _startMorseBroadcast,
            icon: Icon(_isTransmitting ? Icons.stop_rounded : Icons.flash_on_rounded),
            label: Text(
              _isTransmitting ? 'MORS YAYININI DURDUR' : 'FLAŞ İLE MORS YAYINLA',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),

          const SizedBox(height: 16),

          // Ekran Feneri Modları
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _screenNightRed = true),
                  icon: const Icon(Icons.nightlight_round, size: 18),
                  label: const Text('KIRMIZI FENER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _screenWhiteStrobe = true),
                  icon: const Icon(Icons.light_mode_rounded, size: 18),
                  label: const Text('TAM BEYAZ FENER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
