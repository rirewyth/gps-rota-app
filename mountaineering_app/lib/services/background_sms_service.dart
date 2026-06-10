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

  /// Direkt SMS gönderir — kullanıcı onayı gerekmez
  static Future<bool> sendSms(String to, String message) async {
    try {
      final sanitizedTo = _sanitizePhoneNumber(to);
      if (Platform.isIOS) {
        final uri = Uri(
          scheme: 'sms',
          path: sanitizedTo,
          queryParameters: <String, String>{
            'body': message,
          },
        );
        await launchUrl(uri);
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

      // 2. GPS konumu al
      Position? konum;
      try {
        bool gpsAcik = await Geolocator.isLocationServiceEnabled();
        if (gpsAcik) {
          try {
            konum = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 3),
              ),
            );
          } catch (_) {
            konum = await Geolocator.getLastKnownPosition();
          }

          if (konum != null) {
            await DatabaseHelper.instance.insertLocation(
              konum.latitude,
              konum.longitude,
              konum.altitude,
              DateTime.now().toIso8601String(),
            );
          }
        }
      } catch (_) {}

      // 3. Aktif rotayı al
      String rotaBilgisi = '';
      String rotaKonumBilgisi = '';

      try {
        final aktifRota = await DatabaseHelper.instance.aktifRotaGetir();
        if (aktifRota != null) {
          final rotaIsmi = aktifRota['isim'] as String;
          final noktalar = aktifRota['noktalar'] as List;
          rotaBilgisi = 'ROTA:$rotaIsmi';

          if (konum != null && noktalar.isNotEmpty) {
            final yakin = DatabaseHelper.enYakinRotaNoktasi(
              konum.latitude,
              konum.longitude,
              noktalar,
            );
            if (yakin != null) {
              final nokta = yakin['index'] as int;
              final toplam = yakin['toplam'] as int;
              final yuzde = ((nokta + 1) / toplam * 100).round();
              rotaKonumBilgisi = ' (%$yuzde)';
            }
          }
        }
      } catch (_) {}

      // 4. Yapay Zeka Notu (log amacıyla kullanılır)
      try {
        final activeRoute = await DatabaseHelper.instance.aktifRotaGetir();
        await AIAdvisorService.generateInsight(
          lat: konum?.latitude ?? 0,
          lng: konum?.longitude ?? 0,
          speed: konum?.speed ?? 0,
          activeRoute: activeRoute,
        );
      } catch (_) {}

      // 5. Ek veriler
      int batteryLevel = 0;
      try {
        final battery = Battery();
        batteryLevel = await battery.batteryLevel;
      } catch (_) {}

      final kan = await StorageHelper.getBloodType();
      String saglikBilgisi = '';
      if (kan != null && kan != 'BİLİNMİYOR') saglikBilgisi += 'KAN:$kan ';

      String konumMetni = konum != null
          ? 'KONUM:${konum.latitude.toStringAsFixed(5)},${konum.longitude.toStringAsFixed(5)} R:${konum.altitude.toInt()}m'
          : 'KONUM_ALINAMADI';

      String gmaps = konum != null
          ? 'https://maps.google.com/?q=${konum.latitude},${konum.longitude}'
          : '';

      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      // Kullanıcının özel şablonu
      String customSos = overrideMessage ?? (await StorageHelper.getSosMesaji() ?? 'ACİL YARDIM');
      if (customPrefix != null) {
        customSos = '$customPrefix $customSos';
      }

      // --- SMS METNİ ---
      String otm = konum != null
          ? 'https://opentopomap.org/#map=17/${konum.latitude}/${konum.longitude}'
          : '';

      String fullSms = '[ROTA+ SOS] $customSos | $timeStr | $konumMetni | GMaps: $gmaps | OTM: $otm | PIL:%$batteryLevel | $saglikBilgisi${rotaBilgisi.isNotEmpty ? "$rotaBilgisi$rotaKonumBilgisi" : ""}';

      fullSms = _turkceKarakterleriCevir(fullSms).replaceAll(RegExp(r'\s+'), ' ').trim();

      // --- Otomatik SMS Gönder ---
      if (Platform.isIOS) {
        final uri = Uri(
          scheme: 'sms',
          path: telefon,
          queryParameters: <String, String>{
            'body': fullSms,
          },
        );
        await launchUrl(uri);
      } else {
        final SmsSendStatusListener listener = (SendStatus status) {};
        _telephony.sendSms(
          to: telefon,
          message: fullSms,
          statusListener: listener,
          isMultipart: true,
        );
      }

      // 7. Mesajı veritabanına kaydet
      await DatabaseHelper.instance.insertMessage(
        'SOS Gonderildi:\n$fullSms',
        true,
        timeStr,
      );

      return {'basarili': true, 'mesaj': fullSms, 'telefon': telefon};
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
