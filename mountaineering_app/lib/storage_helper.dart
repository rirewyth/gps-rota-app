import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static const String _sosActiveKey = 'sos_active';
  static const String _observerPhoneKey = 'observer_phone';

  static Future<bool> isSosActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sosActiveKey) ?? false;
  }

  static Future<void> setSosActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sosActiveKey, active);
  }

  // Ayarlar - Yeni eklenen kalıcı değişkenler
  static const String _uyduBaglantisiKey = 'uydu_baglantisi';
  static const String _bataryaTasarrufuKey = 'batarya_tasarrufu';
  static const String _gpsModKey = 'gps_mod';
  static const String _sosMesajiKey = 'sos_mesaji';
  static const String _smsSikligiKey = 'sms_sikligi';
  static const String _inactivitySensorKey = 'inactivity_sensor';
  static const String _voiceSosKey = 'voice_sos';
  static const String _geofencingKey = 'geofencing';
  static const String _earlyWarningKey = 'early_warning_enabled';
  static const String _aprsApiKeyKey = 'aprs_api_key';
  static const String _heightKey = 'user_height';
  static const String _weightKey = 'user_weight';
  static const String _ageKey = 'user_age';
  static const String _eqMinMagKey = 'eq_min_mag';
  static const String _eqMaxDistKey = 'eq_max_dist';
  static const String _eqGeneralNotifKey = 'eq_general_notif';
  static const String _barometerEnabledKey = 'barometer_enabled';
  static const String _pressureHistoryKey = 'pressure_history';

  static Future<bool> getEarlyWarningEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_earlyWarningKey) ?? false;
  }

  static Future<void> setEarlyWarningEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_earlyWarningKey, val);
  }

  static Future<String> getAprsApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aprsApiKeyKey) ?? '227698.AfUTYsSYmLKaOtt';
  }

  static Future<void> setAprsApiKey(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aprsApiKeyKey, val);
  }

  static Future<String?> getHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_heightKey);
  }

  static Future<void> setHeight(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_heightKey, val);
  }

  static Future<String?> getWeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_weightKey);
  }

  static Future<void> setWeight(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weightKey, val);
  }

  static Future<String?> getAge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ageKey);
  }

  static Future<void> setAge(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ageKey, val);
  }

  static Future<double> getEqMinMag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_eqMinMagKey) ?? 4.0;
  }

  static Future<void> setEqMinMag(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_eqMinMagKey, val);
  }

  static Future<double> getEqMaxDist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_eqMaxDistKey) ?? 500.0;
  }

  static Future<void> setEqMaxDist(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_eqMaxDistKey, val);
  }

  static Future<bool> getEqGeneralNotif() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_eqGeneralNotifKey) ?? false;
  }

  static Future<void> setEqGeneralNotif(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eqGeneralNotifKey, val);
  }

  static Future<bool> getBarometerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_barometerEnabledKey) ?? true;
  }

  static Future<void> setBarometerEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_barometerEnabledKey, val);
  }

  static Future<String?> getPressureHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pressureHistoryKey);
  }

  static Future<void> setPressureHistory(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pressureHistoryKey, val);
  }

  static Future<bool> getUyduBaglantisi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_uyduBaglantisiKey) ?? true;
  }

  static Future<void> setUyduBaglantisi(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_uyduBaglantisiKey, val);
  }

  static Future<bool> getBataryaTasarrufu() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bataryaTasarrufuKey) ?? false;
  }

  static Future<void> setBataryaTasarrufu(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bataryaTasarrufuKey, val);
  }

  static Future<String> getGpsMod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gpsModKey) ?? 'YuksekHassasiyet';
  }

  static Future<void> setGpsMod(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gpsModKey, val);
  }

  static Future<String?> getSosMesaji() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sosMesajiKey);
  }

  static Future<void> setSosMesaji(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sosMesajiKey, val);
  }

  static Future<int> getSmsSikligi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_smsSikligiKey) ?? 5;
  }

  static Future<void> setSmsSikligi(int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_smsSikligiKey, val);
  }

  static Future<bool> getInactivitySensor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_inactivitySensorKey) ?? true;
  }

  static Future<void> setInactivitySensor(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_inactivitySensorKey, val);
  }

  static Future<bool> getVoiceSos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceSosKey) ?? false;
  }

  static Future<void> setVoiceSos(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceSosKey, val);
  }

  static Future<bool> getGeofencing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_geofencingKey) ?? true;
  }

  static Future<void> setGeofencing(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_geofencingKey, val);
  }

  static Future<String?> getObserverPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_observerPhoneKey);
  }

  static Future<void> setObserverPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_observerPhoneKey, phone);
  }

  static const String _userLoggedInKey = 'user_logged_in';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userUidKey = 'user_firebase_uid';

  static Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userLoggedInKey) ?? false;
  }

  static Future<void> setUserLoggedIn(bool loggedIn, {String? userName, String? userEmail, String? userUid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userLoggedInKey, loggedIn);
    if (userName != null) {
      await prefs.setString(_userNameKey, userName);
    }
    if (userEmail != null) {
      await prefs.setString(_userEmailKey, userEmail);
    }
    if (userUid != null) {
      await prefs.setString(_userUidKey, userUid);
    }
  }

  static Future<String?> getUserUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userUidKey);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Medikal Bilgiler
  static const String _bloodTypeKey = 'blood_type';
  static const String _medicalInfoKey = 'medical_info';

  static Future<String?> getBloodType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bloodTypeKey);
  }

  static Future<void> setBloodType(String blood) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bloodTypeKey, blood);
  }

  static Future<String?> getMedicalInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_medicalInfoKey);
  }

  static Future<void> setMedicalInfo(String info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_medicalInfoKey, info);
  }

  // Premium Durumu
  static const String _isPremiumKey = 'is_premium';
  
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPremiumKey) ?? false;
  }

  static Future<void> setPremium(bool premium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, premium);
  }

  // Kullanici ID (SQLite'da kullanıcı satır ID'si)
  static const String _userIdKey = 'user_db_id';

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<void> setUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, id);
  }

  // Tum oturum verilerini temizle (cikis)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userLoggedInKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_isPremiumKey);
    await prefs.remove(_sosActiveKey);
    await prefs.remove(_mapStyleKey);
  }

  // Harita Stili
  static const String _mapStyleKey = 'map_style';

  static Future<String> getMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mapStyleKey) ?? 'osm';
  }

  static Future<void> setMapStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapStyleKey, style);
  }
}
