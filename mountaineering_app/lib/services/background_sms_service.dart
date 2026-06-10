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
  static final Telephony _telephony = Telephony.instance;

  /// Boş başlatıcı (servis altyapısı için)
  static Future<void> initializeService() async {}

  /// Direkt SMS gönderir — iOS'te SMS uygulamasını açar, Android'de otomatik gönderir
  static Future<bool> sendSms(String to, String message) async {
    try {
      final sanitizedTo = _sanitizePhoneNumber(to);
      if (Platform.isIOS) {
        // iOS: sms: URI şeması ile yerel SMS uygulamasını aç
        final uri = Uri(
          scheme: 'sms',
          path: sanitizedTo,
          queryParameters: <String, String>{'body': message},
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback: smsTo şeması dene
          final fallback = Uri.parse('sms:$sanitizedTo?body=${Uri.encodeComponent(message)}');
          await launchUrl(fallback, mode: LaunchMode.externalApplication);
        }
        return true;
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
        // iOS: yerel SMS uygulamasını metin dolu halde aç — kullanıcı sadece Gönder'e basar
        bool launched = false;
        try {
          final uri = Uri(
            scheme: 'sms',
            path: telefon,
            queryParameters: <String, String>{'body': fullSms},
          );
          if (await canLaunchUrl(uri)) {
            launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}

        if (!launched) {
          try {
            // Fallback URI formatı: sms:NUMARA?body=METIN
            final encoded = Uri.encodeComponent(fullSms);
            final fallback = Uri.parse('sms:$telefon?body=$encoded');
            await launchUrl(fallback, mode: LaunchMode.externalApplication);
            launched = true;
          } catch (_) {}
        }

        // iOS'te SMS kutusu açıldığında başarılı say
        return {'basarili': true, 'mesaj': fullSms, 'telefon': telefon};
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
