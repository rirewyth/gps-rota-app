// Rota+ SOS Servisi - Otomatik SMS Gönderimi
// another_telephony ile kullanıcı onayı gerekmeden direkt SMS gönderir.

import 'package:another_telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import '../storage_helper.dart';
import '../database_helper.dart';
import 'ai_advisor_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';

class BackgroundSmsService {
  static Telephony? __telephony;
  static Telephony get _telephony {
    if (__telephony == null) {
      if (Platform.isAndroid) {
        __telephony = Telephony.instance;
      } else {
        throw UnsupportedError('Telephony is only supported on Android');
      }
    }
    return __telephony!;
  }

  /// Boş başlatıcı (servis altyapısı için)
  static Future<void> initializeService() async {}

  /// iOS için son derece dayanıklı SMS gönderme fonksiyonu.
  /// Farklı iOS sürümleri ve alıcı numara formatları için tüm olasılıkları dener.
  static Future<bool> _launchIosSms(String phone, String message) async {
    final encodedMessage = Uri.encodeComponent(message);
    
    // Alıcı numarasını iOS SMS protokolü için optimize et:
    // Türkiye numaraları için yerel format ('05xxxxxxxxx') uluslararası formata göre çok daha kararlıdır.
    String cleanPhone = phone;
    if (phone.startsWith('+90') && phone.length == 13) {
      cleanPhone = '0${phone.substring(3)}';
    } else if (phone.startsWith('90') && phone.length == 12) {
      cleanPhone = '0${phone.substring(2)}';
    }

    // iOS SMS şemalarında denenecek tüm olası varyasyonlar (En kararlı olandan başlayarak)
    final List<String> urlsToTry = [
      'sms:$cleanPhone&body=$encodedMessage',    // 1. Tercih: Yerel format + '&' ayırıcı
      'sms:$cleanPhone;body=$encodedMessage',    // 2. Tercih: Yerel format + ';' ayırıcı
      'sms:$phone&body=$encodedMessage',         // 3. Tercih: Orijinal format + '&' ayırıcı
      'sms:$phone;body=$encodedMessage',         // 4. Tercih: Orijinal format + ';' ayırıcı
      'sms:$cleanPhone?body=$encodedMessage',    // 5. Tercih: Yerel format + standart '?' ayırıcı
      'sms:$phone?body=$encodedMessage',         // 6. Tercih: Orijinal format + standart '?' ayırıcı
    ];

    for (final urlStr in urlsToTry) {
      try {
        final uri = Uri.parse(urlStr);
        if (await canLaunchUrl(uri)) {
          final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (success) return true;
        }
      } catch (_) {}
    }

    // Fallback: Yukarıdakiler başarısız olursa sadece SMS uygulamasını alıcı doldurarak açmayı dene
    try {
      final fallbackUri = Uri.parse('sms:$cleanPhone');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Direkt SMS gönderir — iOS'te SMS uygulamasını açar, Android'de otomatik gönderir
  static Future<bool> sendSms(String to, String message) async {
    try {
      final sanitizedTo = _sanitizePhoneNumber(to);
      if (sanitizedTo.isEmpty) return false;

      if (Platform.isIOS) {
        return await _launchIosSms(sanitizedTo, message);
      } else {
        final SmsSendStatusListener listener = (SendStatus status) {};
        _telephony.sendSms(
          to: sanitizedTo,
          message: message,
          statusListener: listener,
          isMultipart: true,
        );
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  /// SOS mesajını otomatik gönderir
  static Future<Map<String, dynamic>> sosMesajiGonder({String? customPrefix, String? overrideMessage}) async {
    try {
      // 1. Gözlemci numarasını al
      String? telefon = await StorageHelper.getObserverPhone();
      if (telefon == null || telefon.trim().isEmpty) {
        return {'basarili': false, 'hata': 'İletişim numarası girilmemiş!'};
      }
      telefon = _sanitizePhoneNumber(telefon);
      if (telefon.isEmpty) {
        return {'basarili': false, 'hata': 'İletişim numarası geçersiz!'};
      }

      // 2. Kullanıcının özel şablonu
      String customSos = overrideMessage ?? (await StorageHelper.getSosMesaji() ?? 'ACİL YARDIM');
      if (customPrefix != null) customSos = '$customPrefix $customSos';

      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      // 3. GPS konumu — kısa timeout ile al, alamazsak son bilinen konumu kullan
      Position? konum;
      try {
        konum = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        try { konum = await Geolocator.getLastKnownPosition(); } catch (_) {}
      }

      String konumMetni = konum != null
          ? 'KONUM:${konum.latitude.toStringAsFixed(5)},${konum.longitude.toStringAsFixed(5)}'
          : 'KONUM_ALINAMADI';
      String gmaps = konum != null
          ? 'https://maps.google.com/?q=${konum.latitude},${konum.longitude}'
          : '';

      // 4. Pil seviyesi
      int batteryLevel = 0;
      try { batteryLevel = await Battery().batteryLevel.timeout(const Duration(seconds: 2)); } catch (_) {}

      // 5. Kan grubu
      final kan = await StorageHelper.getBloodType();
      String saglikBilgisi = (kan != null && kan != 'BİLİNMİYOR') ? 'KAN:$kan ' : '';

      // 6. Rota bilgisi — arka planda, SMS gönderimi bloke etmez
      String rotaBilgisi = '';
      try {
        final aktifRota = await DatabaseHelper.instance.aktifRotaGetir()
            .timeout(const Duration(seconds: 2));
        if (aktifRota != null) rotaBilgisi = 'ROTA:${aktifRota['isim']}';
      } catch (_) {}

      // 7. SMS metnini oluştur
      String fullSms = '[ROTA+ SOS] $customSos | $timeStr | $konumMetni${gmaps.isNotEmpty ? " | GMaps: $gmaps" : ""} | PIL:%$batteryLevel | $saglikBilgisi${rotaBilgisi.isNotEmpty ? rotaBilgisi : ""}';
      fullSms = _turkceKarakterleriCevir(fullSms).replaceAll(RegExp(r'\s+'), ' ').trim();

      // 8. SMS Gönder
      if (Platform.isIOS) {
        final launched = await _launchIosSms(telefon, fullSms);
        return {'basarili': launched, 'mesaj': fullSms, 'telefon': telefon};
      } else {
        // Android: doğrudan otomatik gönder
        final SmsSendStatusListener listener = (SendStatus status) {};
        _telephony.sendSms(
          to: telefon,
          message: fullSms,
          statusListener: listener,
          isMultipart: true,
        );

        // DB kaydı sadece Android için (iOS arka plana düştüğü için kayıt yaptıramayabiliriz)
        try {
          await DatabaseHelper.instance.insertMessage('SOS Gonderildi:\n$fullSms', true, timeStr);
        } catch (_) {}

        return {'basarili': true, 'mesaj': fullSms, 'telefon': telefon};
      }
    } catch (e) {
      return {'basarili': false, 'hata': 'Hata: $e'};
    }
  }

  static String _turkceKarakterleriCevir(String text) {
    return text
        .replaceAll('ı', 'i').replaceAll('İ', 'I')
        .replaceAll('ğ', 'g').replaceAll('Ğ', 'G')
        .replaceAll('ü', 'u').replaceAll('Ü', 'U')
        .replaceAll('ş', 's').replaceAll('Ş', 'S')
        .replaceAll('ö', 'o').replaceAll('Ö', 'O')
        .replaceAll('ç', 'c').replaceAll('Ç', 'C');
  }

  static String _sanitizePhoneNumber(String phone) {
    String sanitized = phone.replaceAll(RegExp(r'[^\d\+]'), '');
    if (sanitized.startsWith('0') && sanitized.length == 11) {
      sanitized = '+90${sanitized.substring(1)}';
    } else if (sanitized.startsWith('5') && sanitized.length == 10) {
      sanitized = '+90$sanitized';
    } else if (sanitized.startsWith('90') && sanitized.length == 12) {
      sanitized = '+$sanitized';
    }
    return sanitized;
  }

  /// Durumu Firestore'da günceller ve ekibe bildirir
  static Future<void> sosDurumunuGuncelle(bool active) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(user.uid).set({
        'is_sos': active,
        'sos_timestamp': active ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));

      if (active) {
        final userDoc = await db.collection('users').doc(user.uid).get();
        final teamId = userDoc.data()?['team_id'] as String?;
        if (teamId != null && teamId.isNotEmpty) {
          final name = userDoc.data()?['name'] ?? 'Kullanıcı';
          await db.collection('teams').doc(teamId).collection('messages').add({
            'senderId': user.uid,
            'senderName': name,
            'text': '🚨 [ACİL DURUM SOS]\nYardıma ihtiyacım var! Konumuma bakın.',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'sos_alert',
          });
        }
      }
    } catch (e) {}
  }
}
