import 'dart:async';
import 'package:torch_light/torch_light.dart';

class MorseService {
  static bool _isPulsing = false;
  static Timer? _pulseTimer;

  static const Map<String, String> morseAlphabet = {
    'S': '...',
    'O': '---',
    'A': '.-',
    'B': '-...',
    'C': '-.-.',
    'D': '-..',
    'E': '.',
    // Gerekirse diğer harfler eklenebilir
  };

  /// Mesajı Morse koduna çevirir ve flaşı yakıp söndürür
  static Future<void> playSos() async {
    if (_isPulsing) return;
    _isPulsing = true;
    
    while (_isPulsing) {
      await _playPattern('...'); // S
      await Future.delayed(const Duration(milliseconds: 300));
      await _playPattern('---'); // O
      await Future.delayed(const Duration(milliseconds: 300));
      await _playPattern('...'); // S
      await Future.delayed(const Duration(seconds: 2)); // Mesaj arası bekleme
    }
  }

  static Future<void> stop() async {
    _isPulsing = false;
    _pulseTimer?.cancel();
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
  }

  static Future<void> torchOn() async {
    try {
      await TorchLight.enableTorch();
    } catch (_) {}
  }

  static Future<void> _playPattern(String pattern) async {
    for (int i = 0; i < pattern.length; i++) {
      if (!_isPulsing) break;
      
      String char = pattern[i];
      if (char == '.') {
        await _flash(200); // Kısa ışık
      } else if (char == '-') {
        await _flash(600); // Uzun ışık
      }
      await Future.delayed(const Duration(milliseconds: 200)); // Harf içi boşluk
    }
  }

  static Future<void> _flash(int durationMs) async {
    try {
      await TorchLight.enableTorch();
      await Future.delayed(Duration(milliseconds: durationMs));
      await TorchLight.disableTorch();
    } catch (_) {}
  }
  
  static bool get isPulsing => _isPulsing;
}
