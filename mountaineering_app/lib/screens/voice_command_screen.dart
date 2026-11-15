import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/tactical_styles.dart';

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Battery _battery = Battery();

  bool _listening = false;
  bool _torchOn = false;
  String _lastHeard = 'Komut bekleniyor...';
  String _lastResponse = 'Örn: "Durum raporu", "Feneri yak", "Acil konum gönder"';

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('tr-TR');
    _tts.setSpeechRate(0.5);
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      setState(() => _lastResponse = 'Mikrofon / ses tanıma başlatılamadı. Aşağıdaki hızlı komutları kullanabilirsiniz.');
      return;
    }

    setState(() {
      _listening = true;
      _lastHeard = 'Dinleniyor...';
    });

    await _speech.listen(
      localeId: 'tr_TR',
      onResult: (result) {
        if (!mounted) return;
        setState(() => _lastHeard = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
          _executeVoiceCommand(result.recognizedWords);
        }
      },
    );
  }

  Future<void> _executeVoiceCommand(String raw) async {
    final cmd = raw.toLowerCase();

    if (cmd.contains('fener') || cmd.contains('ışık') || cmd.contains('isik')) {
      final turnOff = cmd.contains('kapat') || cmd.contains('söndür');
      try {
        if (turnOff) {
          await TorchLight.disableTorch();
          _torchOn = false;
          _respond('Fener kapatıldı.');
        } else {
          await TorchLight.enableTorch();
          _torchOn = true;
          _respond('Fener açıldı.');
        }
      } catch (_) {
        _respond('Bu cihazda kamera flaşı kontrol edilemedi.');
      }
      return;
    }

    if (cmd.contains('acil') || cmd.contains('sos') || cmd.contains('yardım') || cmd.contains('yardim')) {
      _respond('Acil durum konum paketi hazırlanıyor.');
      await _sendEmergencySms();
      return;
    }

    if (cmd.contains('durum') || cmd.contains('rapor') || cmd.contains('neredeyim') || cmd.contains('rakım')) {
      await _speakStatusReport();
      return;
    }

    _respond('Komut anlaşılamadı: "$raw". "Durum raporu", "Feneri yak" veya "Acil konum" diyebilirsiniz.');
  }

  Future<void> _respond(String text) async {
    if (mounted) setState(() => _lastResponse = text);
    await _tts.speak(text);
  }

  Future<void> _speakStatusReport() async {
    int bat = 100;
    try {
      bat = await _battery.batteryLevel;
    } catch (_) {}

    double? heading;
    try {
      heading = (await FlutterCompass.events?.first)?.heading;
    } catch (_) {}

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 6));

      final msg =
          'Rakım ${pos.altitude.toInt()} metre. '
          '${heading != null ? "Yön ${heading.toInt()} derece. " : ""}'
          'Pil yüzde $bat. '
          'Koordinatlar ${pos.latitude.toStringAsFixed(3)} kuzey, ${pos.longitude.toStringAsFixed(3)} doğu.';
      await _respond(msg);
    } catch (_) {
      await _respond('GPS sinyali alınamadı. Pil yüzde $bat.');
    }
  }

  Future<void> _sendEmergencySms() async {
    int bat = 100;
    try {
      bat = await _battery.batteryLevel;
    } catch (_) {}

    String loc = 'Konum alınamadı';
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 6));
      loc = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} '
          '(Rakım: ${pos.altitude.toInt()}m) https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    } catch (_) {}

    final body = '🆘 SESLİ KOMUT ACİL DURUM!\nPil: %$bat\nKonum: $loc';
    final uri = Uri(scheme: 'sms', queryParameters: {'body': body});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Share.share(body);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    TorchLight.disableTorch().catchError((_) {});
    super.dispose();
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
            Icon(Icons.mic_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'SESLİ TELSİZ & KOMUT ASİSTANI',
                style: TextStyle(color: TacticalStyles.kOnSurface, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Büyük Eldiven Dostu Mikrofon Butonu
          GestureDetector(
            onTap: _toggleListen,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 34),
              decoration: TacticalStyles.glassCardDecoration(
                radius: 20,
                borderColor: _listening ? Colors.redAccent : Colors.amber.withOpacity(0.5),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: _listening ? Colors.redAccent : Colors.amber,
                    child: Icon(
                      _listening ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: _listening ? Colors.white : Colors.black,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _listening ? 'DİNLENİYOR... (DURDURMAK İÇİN DOKUN)' : 'BAS & KONUŞ',
                    style: TextStyle(
                      color: _listening ? Colors.redAccent : Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _lastHeard,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: TacticalStyles.kOnSurface, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Yanıt Kutusu
          Container(
            padding: const EdgeInsets.all(14),
            decoration: TacticalStyles.glassCardDecoration(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ASİSTAN YANITI', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(_lastResponse, style: const TextStyle(color: TacticalStyles.kTertiary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'HIZLI SESLİ KOMUTLAR (TEK DOKUNUŞ)',
            style: TextStyle(color: TacticalStyles.kOnSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: TacticalStyles.kSurfaceLow,
              foregroundColor: TacticalStyles.kTertiary,
              side: BorderSide(color: TacticalStyles.kTertiary.withOpacity(0.45)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _speakStatusReport,
            icon: const Icon(Icons.record_voice_over_rounded),
            label: const Text('DURUM RAPORU OKU (RAKIM / GPS / PİL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: TacticalStyles.kSurfaceLow,
              foregroundColor: Colors.amber,
              side: BorderSide(color: Colors.amber.withOpacity(0.45)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _executeVoiceCommand(_torchOn ? 'feneri kapat' : 'feneri yak'),
            icon: Icon(_torchOn ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded),
            label: Text(_torchOn ? 'FENERİ KAPAT' : 'FENERİ YAK', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _executeVoiceCommand('acil konum gönder'),
            icon: const Icon(Icons.sos_rounded),
            label: const Text('ACİL KONUM SMS HAZIRLA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
