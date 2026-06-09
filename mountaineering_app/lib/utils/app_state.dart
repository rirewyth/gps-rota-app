import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('tr'));

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? true;
    final lang = prefs.getString('lang') ?? 'tr';

    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    localeNotifier.value = Locale(lang);
  }

  static void toggleTheme() async {
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', !isDark);
  }

  static void toggleLanguage() async {
    final isTr = localeNotifier.value.languageCode == 'tr';
    final newLang = isTr ? 'en' : 'tr';
    localeNotifier.value = Locale(newLang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', newLang);
  }

  // Simple static translation helper
  static String tr(String key) {
    if (localeNotifier.value.languageCode == 'tr') return key;

    // English translations for main keywords
    switch (key) {
      // Common & Navigation
      case 'KRİTİK': return 'CRITICAL';
      case 'Rota +': return 'Route +';
      case 'PAYLAŞIM': return 'SHARE';
      case 'Akış': return 'Feed';
      case 'Takip': return 'Track';
      case 'Rota': return 'Route';
      case 'Ekip': return 'Team';
      case 'Profil': return 'Profile';
      case 'AYARLAR': return 'SETTINGS';
      case 'Çıkış Yap': return 'Logout';
      case 'Geri Dön': return 'Go Back';
      case 'KAYDET': return 'SAVE';
      case 'İPTAL': return 'CANCEL';

      // Home & Status
      case 'RAKIM': return 'ALTITUDE';
      case 'İSTİKAMET': return 'HEADING';
      case 'HAREKETSİZLİK SENSÖRÜ': return 'INACTIVITY SENSOR';
      case 'Aktif (15 dk hareketsizlikte durum bildirir)': return 'Active (Shares status after 15m inactivity)';
      case 'Devre dışı bırakıldı': return 'Disabled';
      case 'CANLI TAKİP': return 'LIVE TRACKING';
      case 'Yazı': return 'Text';
      case 'Paylaşım': return 'Post';
      case 'Gönderi': return 'Post';
      case 'Fotoğraflar': return 'Photos';
      case 'FOTO': return 'PHOTOS';
      case 'YAZILAR': return 'POSTS';
      case 'ROTALAR': return 'ROUTES';
      case 'BEĞENİLER': return 'LIKES';
      case 'İSTATİSTİKLER': return 'STATS';
      case 'Takipçi': return 'Followers';
      case 'Takip Edilen': return 'Following';
      case 'Bağlantı Kur': return 'Connect';
      case 'Mesaj Gönder': return 'Send Message';
      case 'Yeni Gönderi': return 'New Post';
      case 'PAYLAŞ': return 'SHARE';
      case 'PAYLAŞIM': return 'POST';
      case 'Beğenilenler': return 'Liked';
      case 'İstatistikler': return 'Stats';
      case 'Takiptesin': return 'Following';
      case 'Takip Et': return 'Follow';
      case 'Mesaj Gönder': return 'Send Message';
      case 'Gönderi': return 'Post';

      // Tactical/Safety
      case 'HAREKETSİZLİK TESPİT EDİLDİ': return 'INACTIVITY DETECTED';
      case 'İYİYİM': return 'I AM OK';
      case 'KM': return 'KM';
      case 'İRTİFA (M)': return 'ELEVATION (M)';
      case 'ADIM': return 'STEPS';
      case 'BAŞLA': return 'START';
      case 'TAKİBİ BİTİR': return 'STOP TRACKING';
      
      // Default
      default: return key;
    }
  }
}
