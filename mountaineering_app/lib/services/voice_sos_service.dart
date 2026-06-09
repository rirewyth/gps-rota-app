import 'package:speech_to_text/speech_to_text.dart';
import 'background_sms_service.dart';
import 'dart:async';

class VoiceSosService {
  static final SpeechToText _speech = SpeechToText();
  static bool _isListening = false;
  static Function(String)? onSosTriggered;

  static Future<bool> init() async {
    try {
      return await _speech.initialize(
        onError: (error) {
          _isListening = false;
        },
        onStatus: (status) {
          if (_isListening && (status == 'done' || status == 'notListening')) {
            // Restart listening automatically when it stops
            _listen();
          }
        },
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> start() async {
    if (_isListening) return;
    final available = await init();
    if (!available) return;
    _isListening = true;
    _listen();
  }

  static void stop() {
    _isListening = false;
    _speech.stop();
  }

  static void _listen() async {
    if (!_isListening) return;
    
    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase();
          // Keyword detection
          if (words.contains('yardım') || 
              words.contains('help') || 
              words.contains('sos') || 
              words.contains('imdat')) {
            _triggerSos();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      // If listening fails to start, try again after a short delay
      if (_isListening) {
        Future.delayed(const Duration(seconds: 2), () => _listen());
      }
    }
  }

  static void _triggerSos() {
    onSosTriggered?.call('Sesle SOS tetiklendi');
    BackgroundSmsService.sosMesajiGonder(customPrefix: '🔴 SES KOMUTU:');
  }
}
