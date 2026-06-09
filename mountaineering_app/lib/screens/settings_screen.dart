import 'package:flutter/material.dart';
import 'package:mountaineering_app/storage_helper.dart';
import '../database_helper.dart';
import 'login_screen.dart';
import 'offline_map_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/night_ops_service.dart';
import '../services/premium_service.dart';
import 'package:mountaineering_app/services/earthquake_service.dart';
import 'package:geolocator/geolocator.dart';
import 'about_screen.dart';
import '../services/cloud_sync_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kCardBg = Color(0xFF141414);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kGreen = Color(0xFF62FF4C);

  // Baglanti ayarlari
  bool _uyduBaglantisi = true;
  bool _bataryaTasarrufu = false;
  String _gpsMod = 'YuksekHassasiyet';
  bool _voiceSos = false;
  bool _geofencing = true;

  // Kullanici bilgileri (DB'den)
  String _userName = '';
  String _userEmail = '';
  String _kanGrubu = '';
  String _tibbiInfo = '';
  String _acilKisi = '';
  String _acilTel = '';

  // Deprem ayarları
  bool _earlyWarning = false;
  double _eqMinMag = 4.0;
  double _eqMaxDist = 500.0;
  bool _eqGeneralNotif = false;
  bool _barometerEnabled = true;

  String _aprsKey = '';
  bool _aprsKeyVisible = false;
  bool _isAprsLocked = true;
  String _boy = '';
  String _kilo = '';
  String _yas = '';
  String _appVersion = 'v1.0.5+13';

  // SOS mesaji
  final TextEditingController _sosMesajiController = TextEditingController();
  final TextEditingController _aprsKeyController = TextEditingController();
  final TextEditingController _boyController = TextEditingController();
  final TextEditingController _kiloController = TextEditingController();
  final TextEditingController _yasController = TextEditingController();
  int _smsSikligi = 5;

  bool _isLoading = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _sosMesajiController.dispose();
    _aprsKeyController.dispose();
    _boyController.dispose();
    _kiloController.dispose();
    _yasController.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final name = await StorageHelper.getUserName();
    final email = await StorageHelper.getUserEmail();
    final kanGrubu = await StorageHelper.getBloodType();
    final tibbiInfo = await StorageHelper.getMedicalInfo();
    final acilTel = await StorageHelper.getObserverPhone();
    
    final uyduBaglantisi = await StorageHelper.getUyduBaglantisi();
    final bataryaTasarrufu = await StorageHelper.getBataryaTasarrufu();
    final gpsMod = await StorageHelper.getGpsMod();
    final sosMesaji = await StorageHelper.getSosMesaji();
    final smsSikligi = await StorageHelper.getSmsSikligi();

    final earlyWarning = await StorageHelper.getEarlyWarningEnabled();
    final aprsKey = await StorageHelper.getAprsApiKey();
    final boy = await StorageHelper.getHeight();
    final kilo = await StorageHelper.getWeight();
    final yas = await StorageHelper.getAge();

    // From DB for emergency contact and medical info
    String mAcilKisi = '';
    String mAcilTel = acilTel ?? '';
    String mKanGrubu = kanGrubu ?? '';
    String mTibbiInfo = tibbiInfo ?? '';
    
    if (email != null && email.isNotEmpty) {
      final user = await DatabaseHelper.instance.kullaniciBul(email);
      if (user != null) {
        mAcilKisi = user['acil_kisi'] ?? '';
        mAcilTel = user['acil_tel'] ?? mAcilTel;
        mKanGrubu = user['kan_grubu'] ?? mKanGrubu;
        mTibbiInfo = user['tibbi_bilgi'] ?? mTibbiInfo;
      }
    }

    final eqMinMag = await StorageHelper.getEqMinMag();
    final eqMaxDist = await StorageHelper.getEqMaxDist();
    final eqGeneralNotif = await StorageHelper.getEqGeneralNotif();
    final barometerEnabled = await StorageHelper.getBarometerEnabled();

    if (mounted) {
      setState(() {
        _userName = name ?? '';
        _userEmail = email ?? '';
        _kanGrubu = mKanGrubu;
        _tibbiInfo = mTibbiInfo;
        _acilKisi = mAcilKisi;
        _acilTel = mAcilTel;
        _sosMesajiController.text = (sosMesaji != null && sosMesaji.isNotEmpty) ? sosMesaji : 
            'ROTA+ DURUM BİLGİSİ! Koordinatlar: [GPS] Kan: ${_kanGrubu.isEmpty ? "Belirtilmedi" : _kanGrubu}';
        
        _uyduBaglantisi = uyduBaglantisi;
        _bataryaTasarrufu = bataryaTasarrufu;
        _gpsMod = gpsMod;
        _smsSikligi = smsSikligi;

        _earlyWarning = earlyWarning;
        _eqMinMag = eqMinMag;
        _eqMaxDist = eqMaxDist;
        _eqGeneralNotif = eqGeneralNotif;
        _barometerEnabled = barometerEnabled;

        _aprsKey = aprsKey;
        _aprsKeyController.text = aprsKey;
        _isAprsLocked = aprsKey.isNotEmpty;
        _boy = boy ?? '';
        _boyController.text = _boy;
        _kilo = kilo ?? '';
        _kiloController.text = _kilo;
        _yas = yas ?? '';
        _yasController.text = _yas;
      });
    }

    final voiceSos = await StorageHelper.getVoiceSos();
    final geofencing = await StorageHelper.getGeofencing();
    final packageInfo = await PackageInfo.fromPlatform();

    if (mounted) {
      final isPremium = await PremiumService.isPremium();
      setState(() {
        _voiceSos = voiceSos;
        _geofencing = geofencing;
        _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
        _isPremium = isPremium;
        _isLoading = false;
      });
    }
  }

  Future<void> _kaydet() async {
    await StorageHelper.setBloodType(_kanGrubu);
    await StorageHelper.setMedicalInfo(_tibbiInfo);
    await StorageHelper.setObserverPhone(_acilTel);

    await StorageHelper.setUyduBaglantisi(_uyduBaglantisi);
    await StorageHelper.setBataryaTasarrufu(_bataryaTasarrufu);
    await StorageHelper.setGpsMod(_gpsMod);
    await StorageHelper.setSosMesaji(_sosMesajiController.text);
    await StorageHelper.setSmsSikligi(_smsSikligi);
    await StorageHelper.setVoiceSos(_voiceSos);
    await StorageHelper.setGeofencing(_geofencing);

    await StorageHelper.setEarlyWarningEnabled(_earlyWarning);
    await StorageHelper.setEqMinMag(_eqMinMag);
    await StorageHelper.setEqMaxDist(_eqMaxDist);
    await StorageHelper.setEqGeneralNotif(_eqGeneralNotif);
    await StorageHelper.setBarometerEnabled(_barometerEnabled);

    await StorageHelper.setAprsApiKey(_aprsKeyController.text);
    await StorageHelper.setHeight(_boyController.text);
    await StorageHelper.setWeight(_kiloController.text);
    await StorageHelper.setAge(_yasController.text);

    // Servis durumunu güncelle
    if (_earlyWarning) {
      final pos = await Geolocator.getCurrentPosition();
      EarthquakeService().startMonitoring(currentPos: pos);
    } else {
      EarthquakeService().stopMonitoring();
    }

    if (_barometerEnabled) {
      // BarometerService().startMonitoring(); // Will implement in main/weather screen
    }

    final userId = await StorageHelper.getUserId();
    if (userId != null) {
      await DatabaseHelper.instance.kullaniciGuncelle(userId, {
        'kan_grubu': _kanGrubu,
        'tibbi_bilgi': _tibbiInfo,
        'acil_kisi': _acilKisi,
        'acil_tel': _acilTel,
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Ayarlar kaydedildi'),
        backgroundColor: Color(0xFF43A047),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Launch URL error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ROTA+',
            style: TextStyle(
                color: kOrange, fontWeight: FontWeight.w900, letterSpacing: 2)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _kaydet,
            child: const Text('KAYDET',
                style: TextStyle(
                    color: kOrange, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text('AYARLAR',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900)),
                  Container(
                      height: 4,
                      width: 60,
                      color: kOrange,
                      margin: const EdgeInsets.only(top: 4)),
                  const SizedBox(height: 40),

                  if (_isPremium)
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [kGreen.withOpacity(0.2), Colors.transparent]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, color: kGreen, size: 24),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PREMIUM ÜYESİNİZ', style: GoogleFonts.shareTechMono(color: kGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Tüm taktiksel özellikler aktif.', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // BÖLÜM 1: BAĞLANTI
                  _buildSectionHeader('BÖLÜM 1: BAĞLANTI AYARLARI', 'PROTOKOL V.4.8'),
                  ListenableBuilder(
                    listenable: NightOpsService(),
                    builder: (context, _) {
                      return _buildSwitchTile(
                        icon: Icons.track_changes,
                        title: 'Night Ops (Taktiksel Kırmızı)',
                        subtitle: _isPremium ? 'GECE GÖRÜŞÜNÜ KORUR (Aktif)' : 'GECE GÖRÜŞÜNÜ KORUR (Premium)',
                        value: NightOpsService().isEnabled,
                        onChanged: (v) async {
                          final isPrem = await PremiumService.isPremium();
                          if (isPrem) {
                            NightOpsService().toggle();
                          } else {
                            if (mounted) {
                              PremiumService.showPremiumRequired(context, 'Night Ops (Gece Görüşü Modu)');
                            }
                          }
                        },
                      );
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.satellite_alt,
                    title: 'Uydu Bağlantısı',
                    subtitle: 'KÜRESEL KAPSAMA',
                    value: _uyduBaglantisi,
                    onChanged: (v) => setState(() => _uyduBaglantisi = v),
                  ),
                  _buildArrowTile(
                    icon: Icons.gps_fixed,
                    title: 'GPS Hassasiyeti',
                    subtitle: _gpsMod == 'YuksekHassasiyet' ? 'YÜKSEK — <3m hata' : 'ORTA — <10m hata',
                    onTap: () => _gpsModSecDiyalogu(),
                  ),
                  _buildArrowTile(
                    icon: Icons.map,
                    title: 'Çevrimdışı Harita Yönetimi',
                    subtitle: 'Haritaları cihaza indirerek internetsiz navigasyon sağlayın',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineMapScreen()));
                    },
                  ),
                  const SizedBox(height: 30),

                  // BÖLÜM DEPREM: ARKA PLAN TAKİBİ
                  _buildSectionHeader('BÖLÜM 2: DEPREM ERKEN UYARI', 'KRİTİK GÜVENLİK', headerColor: Colors.blueAccent),
                  _buildSwitchTile(
                    icon: Icons.notifications_active,
                    title: '7/24 Erken Uyarı Sistemi',
                    subtitle: 'ARKA PLANDA DEPREM TAKİBİ YAPAR',
                    value: _earlyWarning,
                    onChanged: (v) => setState(() => _earlyWarning = v),
                  ),
                  if (_earlyWarning) ...[
                    _buildSliderTile(
                      icon: Icons.waves,
                      title: 'Minimum Şiddet Eşiği',
                      subtitle: 'M ${_eqMinMag.toStringAsFixed(1)} ve üzeri depremleri bildir',
                      value: _eqMinMag,
                      min: 1.0,
                      max: 8.0,
                      onChanged: (v) => setState(() => _eqMinMag = v),
                    ),
                    _buildSliderTile(
                      icon: Icons.straighten,
                      title: 'Maksimum Mesafe Eşiği',
                      subtitle: '${_eqMaxDist.toInt()} km yakındaki depremleri bildir',
                      value: _eqMaxDist,
                      min: 50.0,
                      max: 1000.0,
                      onChanged: (v) => setState(() => _eqMaxDist = v),
                    ),
                  ],
                  _buildSwitchTile(
                    icon: Icons.rss_feed,
                    title: 'Tüm Deprem Bildirimleri',
                    subtitle: 'TÜRKİYE GENELİNDEKİ TÜM VERİLERİ BİLDİR (OPSİYONEL)',
                    value: _eqGeneralNotif,
                    onChanged: (v) => setState(() => _eqGeneralNotif = v),
                  ),

                  const SizedBox(height: 30),
                  // BÖLÜM: ARKAPLAN SÜREKLİLİĞİ
                  _buildSectionHeader('BÖLÜM 3: ARKAPLAN SÜREKLİLİĞİ', 'KESİNTİSİZ ÇALIŞMA', headerColor: Colors.orangeAccent),
                  _buildArrowTile(
                    icon: Icons.battery_charging_full,
                    title: 'Pil Optimizasyonundan Muaf Tut',
                    subtitle: 'Uygulamanın arkaplanda kapanmasını engelle (Önerilir)',
                    onTap: () async {
                       final status = await Permission.ignoreBatteryOptimizations.status;
                       if (status.isDenied) {
                         await Permission.ignoreBatteryOptimizations.request();
                       } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('✓ Zaten muaf tutulmuş.'))
                         );
                       }
                    },
                  ),
                  _buildArrowTile(
                    icon: Icons.settings_power,
                    title: 'Otomatik Başlatma İzni',
                    subtitle: 'Xiaomi, Samsung vb. cihazlarda manuel izin gerekebilir',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: kCardBg,
                          title: const Text('Otomatik Başlatma', style: TextStyle(color: kOrange)),
                          content: const Text(
                            'Cihazınızın (Xiaomi, Huawei, Oppo vb.) "Otomatik Başlatma" (Auto-start) ayarlarından Rota+ uygulamasına izin vermeniz, telefon kapansa dahi uygulamanın çalışmaya devam etmesini sağlar.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANLADIM', style: TextStyle(color: kOrange))),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),

                    _buildEditTile(
                      icon: Icons.key,
                      title: 'Taktiksel Veri Anahtarı',
                      subtitle: _aprsKeyController.text.isEmpty 
                          ? 'Girilmedi' 
                          : (_aprsKeyVisible ? _aprsKeyController.text : '••••••••••••••••'),
                      trailingIcon: _isAprsLocked ? Icons.lock_outline : Icons.edit,
                      trailingColor: _isAprsLocked ? Colors.redAccent : kOrange,
                      onTap: () => _aprsKeyDuzenle(),
                    ),
                  const SizedBox(height: 30),

                  // BÖLÜM HAVA DURUMU: BAROMETRE
                  _buildSectionHeader('BÖLÜM 3: ÇEVRİMDIŞI BAROMETRE', 'GÜVENLİ TAKİP', headerColor: Colors.cyanAccent),
                  _buildSwitchTile(
                    icon: Icons.speed,
                    title: 'Cihaz Barometre Sensörü',
                    subtitle: 'İNTERNETSİZ BASINÇ VE FIRTINA TAKİBİ',
                    value: _barometerEnabled,
                    onChanged: (v) => setState(() => _barometerEnabled = v),
                  ),
                  const SizedBox(height: 30),

                  // BÖLÜM 2: GÜVENLİK
                  _buildSectionHeader(
                      'BÖLÜM 3: GÜVENLİK PROTOKOLÜ', 'DURUM PAYLAŞIMI',
                      headerColor: Colors.deepOrange),
                  _buildEditTile(
                    icon: Icons.help_outline,
                    title: 'Durum Paylaşım Mesajı',
                    subtitle: _sosMesajiController.text.isEmpty
                        ? 'HENÜZ AYARLANMADI'
                        : _sosMesajiController.text,
                    onTap: () => _sosMesajiDuzenle(),
                  ),
                  _buildArrowTile(
                    icon: Icons.timer,
                    title: 'SMS Aralığı',
                    subtitle: 'Her ${_smsSikligi} dakikada bir sinyal',
                    onTap: () => _smsSikligiDuzenle(),
                  ),
                  _buildSwitchTile(
                    icon: Icons.battery_saver,
                    title: 'Ekstrem Güç Tasarrufu',
                    subtitle: 'PİL ÖMRÜNÜ UZATIR',
                    value: _bataryaTasarrufu,
                    onChanged: (v) => setState(() => _bataryaTasarrufu = v),
                  ),
                  _buildSwitchTile(
                    icon: Icons.mic,
                    title: 'Sesle Yardım Aktivasyonu',
                    subtitle: '"YARDIM" veya "DESTEK" kelimelerini algılar',
                    value: _voiceSos,
                    onChanged: (v) => setState(() => _voiceSos = v),
                  ),
                  _buildSwitchTile(
                    icon: Icons.groups_2,
                    title: 'Grup Mesafe Takibi',
                    subtitle: 'Ekip üyeleri uzaklaştığında uyar',
                    value: _geofencing,
                    onChanged: (v) => setState(() => _geofencing = v),
                  ),
                  const SizedBox(height: 30),

                  // BÖLÜM 3: KAN GRUBU & TIBBİ
                  _buildSectionHeader('BÖLÜM 4: TIBBİ BİLGİLER', ''),
                  _buildArrowTile(
                    icon: Icons.bloodtype,
                    title: 'Kan Grubu',
                    subtitle: _kanGrubu.isEmpty ? 'HENÜZ SEÇİLMEDİ' : _kanGrubu,
                    onTap: () => _kanGrubuSecDiyalogu(),
                  ),
                  _buildEditTile(
                    icon: Icons.height,
                    title: 'Boy (cm)',
                    subtitle: _boyController.text.isEmpty ? 'Belirtilmedi' : '${_boyController.text} cm',
                    onTap: () => _boyDuzenle(),
                  ),
                  _buildEditTile(
                    icon: Icons.monitor_weight,
                    title: 'Kilo (kg)',
                    subtitle: _kiloController.text.isEmpty ? 'Belirtilmedi' : '${_kiloController.text} kg',
                    onTap: () => _kiloDuzenle(),
                  ),
                  _buildEditTile(
                    icon: Icons.cake,
                    title: 'Yaş',
                    subtitle: _yasController.text.isEmpty ? 'Belirtilmedi' : _yasController.text,
                    onTap: () => _yasDuzenle(),
                  ),
                  _buildEditTile(
                    icon: Icons.medical_information,
                    title: 'Tıbbi Bilgiler / Alerjiler',
                    subtitle: _tibbiInfo.isEmpty ? 'Belirtilmedi' : _tibbiInfo,
                    onTap: () => _tibbiInfoDuzenle(),
                  ),
                  const SizedBox(height: 30),

                  // BÖLÜM 4: İRTİBAT BİLGİLERİ
                  _buildSectionHeader('BÖLÜM 4: İRTİBAT BİLGİLERİ', ''),
                  _buildEditTile(
                    icon: Icons.contact_phone,
                    title: 'İrtibat Kişi Adı',
                    subtitle: _acilKisi.isEmpty ? 'Henüz eklenmedi' : _acilKisi,
                    onTap: () => _acilKisiDuzenle(),
                  ),
                  _buildEditTile(
                    icon: Icons.phone,
                    title: 'İrtibat Telefon Numarası',
                    subtitle: _acilTel.isEmpty ? 'Henüz eklenmedi' : _acilTel,
                    onTap: () => _acilTelDuzenle(),
                  ),
                  const SizedBox(height: 30),

                  // BÖLÜM 5: HESAP
                  _buildSectionHeader('BÖLÜM 5: HESAP', ''),
                  _buildInfoTile(
                    icon: Icons.person,
                    title: _userName.isEmpty ? 'Ad Soyad' : _userName,
                    subtitle: _userEmail.isEmpty ? 'e-posta@rota.plus' : _userEmail,
                  ),
                  _buildArrowTile(
                    icon: Icons.lock_outline,
                    title: 'Şifre Değiştir',
                    subtitle: 'Hesap güvenlik anahtarınızı güncelleyin',
                    onTap: () => _sifreDegistir(),
                  ),
                  const SizedBox(height: 30),

                  // BÖLÜM 6: İLETİŞİM & DESTEK
                  _buildSectionHeader('BÖLÜM 6: İLETİŞİM & DESTEK', 'YARDIM MERKEZİ'),
                  _buildArrowTile(
                    icon: Icons.email_outlined,
                    title: 'E-Posta Destek',
                    subtitle: 'destek@rotaplus.app',
                    onTap: () => _launchURL('mailto:destek@rotaplus.app'),
                  ),
                  _buildArrowTile(
                    icon: Icons.play_circle_outline,
                    title: 'YouTube Kanalı',
                    subtitle: 'Eğitim ve Uygulama Videoları',
                    onTap: () => _launchURL('https://www.youtube.com/@rotaplus'),
                  ),
                  _buildArrowTile(
                    icon: Icons.info_outline,
                    title: 'Hakkımızda',
                    subtitle: 'Uygulama Sürümü: $_appVersion',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                    },
                  ),

                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _cikisYap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      color: kCardBg,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: kOrange, size: 20),
                          SizedBox(width: 12),
                          Text('ÇIKIŞ YAP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _hesabiSil,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                          SizedBox(width: 12),
                          Text('HESABI KALICI OLARAK SİL',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  void _sifreDegistir() {
    final eskiCtrl = TextEditingController();
    final yeniCtrl = TextEditingController();
    final onayCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Şifre Değiştir',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput('Mevcut Şifre', eskiCtrl, obscure: true),
            const SizedBox(height: 10),
            _buildDialogInput('Yeni Şifre', yeniCtrl, obscure: true),
            const SizedBox(height: 10),
            _buildDialogInput('Yeni Şifre Tekrar', onayCtrl, obscure: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () async {
              if (yeniCtrl.text != onayCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şifreler eşleşmiyor!'), backgroundColor: Colors.red),
                );
                return;
              }
              if (yeniCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şifre en az 6 karakter olmalı!'), backgroundColor: Colors.red),
                );
                return;
              }
              final email = await StorageHelper.getUserEmail();
              if (email == null) return;
              final user = await DatabaseHelper.instance.kullaniciGirisDogrula(email, eskiCtrl.text);
              if (user == null) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mevcut şifre yanlış!'), backgroundColor: Colors.red),
                );
                return;
              }
              final userId = await StorageHelper.getUserId();
              if (userId != null) {
                await DatabaseHelper.instance.kullaniciSifreDegistir(userId, yeniCtrl.text);
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Şifre güncellendi'), backgroundColor: Color(0xFF43A047)),
              );
            },
            child: const Text('GÜNCELLE',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInput(String label, TextEditingController ctrl, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
      ),
    );
  }

  void _gpsModSecDiyalogu() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('GPS Hassasiyeti',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioTile(ctx, 'YÜKSEK HASSASİYET (<3m)', 'YuksekHassasiyet'),
            _buildRadioTile(ctx, 'ORTA HASSASİYET (<10m)', 'OrtaHassiyet'),
            _buildRadioTile(ctx, 'DÜŞÜK / PILİ KORUMA (<30m)', 'DusukHassiyet'),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile(BuildContext ctx, String label, String val) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      value: val,
      groupValue: _gpsMod,
      activeColor: kOrange,
      onChanged: (v) {
        setState(() => _gpsMod = v!);
        Navigator.pop(ctx);
      },
    );
  }

  void _cevrimdisiHaritaBilgi() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Çevrimdışı Haritalar',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yerel Depolama: 1.2 GB',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('Haritaları harita ekranından indirilebilir.\n'
                'Aktif rota seçildikten sonra çevrimdışı indirme başlatılabilir.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('TAMAM', style: TextStyle(color: kOrange)),
          ),
        ],
      ),
    );
  }

  void _sosMesajiDuzenle() {
    final ctrl = TextEditingController(text: _sosMesajiController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Durum Mesajı Düzenle',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                '[GPS] yazısını bırakın — konumunuz otomatik eklenir.',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF0A0A0A),
                border:
                    OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                enabledBorder:
                    OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder:
                    OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              setState(() => _sosMesajiController.text = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('KAYDET',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _smsSikligiDuzenle() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('SMS Güncelleme Sıklığı',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (ctx, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Her ${_smsSikligi} dakikada bir',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Slider(
                value: _smsSikligi.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                activeColor: kOrange,
                label: '${_smsSikligi} dk',
                onChanged: (v) {
                  setStateDialog(() => _smsSikligi = v.toInt());
                  setState(() => _smsSikligi = v.toInt());
                },
              ),
              const Text('1 – 30 dakika arasında seçin',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('KAPAT', style: TextStyle(color: kOrange)),
          ),
        ],
      ),
    );
  }

  void _kanGrubuSecDiyalogu() {
    const gruplar = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Kan Grubu Seç',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: gruplar.map((g) => GestureDetector(
            onTap: () {
              setState(() => _kanGrubu = g);
              Navigator.pop(ctx);
            },
            child: Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _kanGrubu == g ? kOrange : const Color(0xFF0A0A0A),
                border: Border.all(color: _kanGrubu == g ? kOrange : Colors.white12),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(g,
                  style: TextStyle(
                      color: _kanGrubu == g ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  void _tibbiInfoDuzenle() {
    final ctrl = TextEditingController(text: _tibbiInfo);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Tıbbi Bilgiler / Alerjiler',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Alerjiler, ilaçlar, kronik hastalıklar...',
            hintStyle: TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Color(0xFF0A0A0A),
            border:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              setState(() => _tibbiInfo = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('KAYDET',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _acilKisiDuzenle() {
    final ctrl = TextEditingController(text: _acilKisi);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Acil Kişi Adı',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ad Soyad',
            hintStyle: TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Color(0xFF0A0A0A),
            border:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              setState(() => _acilKisi = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('KAYDET',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _aprsKeyDuzenle() {
    if (_isAprsLocked && _aprsKeyController.text.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCardBg,
          title: const Text('Anahtar Kilitli', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: const Text('Bu anahtar güvenlik için kilitlenmiştir. Değiştirmek için önce mevcut anahtarı temizlemeniz gerekir.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT', style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _aprsKeyController.clear();
                  _isAprsLocked = false;
                });
                Navigator.pop(ctx);
                _aprsKeyDuzenle(); // Open edit dialog after clearing
              },
              child: const Text('TEMİZLE VE AÇ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final ctrl = TextEditingController(text: _aprsKeyController.text);
    bool localVisible = _aprsKeyVisible;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          title: const Text('Taktiksel Veri Anahtarı', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                obscureText: !localVisible,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0A0A0A),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(localVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white38),
                    onPressed: () => setDialogState(() => localVisible = !localVisible),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Bu anahtar güvenli veri paylaşımı ve telsiz takibi için kullanılır. Kaydettiğinizde otomatik olarak kilitlenecektir.', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange),
              onPressed: () {
                setState(() {
                  _aprsKeyController.text = ctrl.text;
                  _aprsKeyVisible = localVisible;
                  if (ctrl.text.isNotEmpty) _isAprsLocked = true;
                });
                Navigator.pop(ctx);
              },
              child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _boyDuzenle() {
    final ctrl = TextEditingController(text: _boyController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Boy (cm)', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0A0A0A), border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              setState(() => _boyController.text = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('TAMAM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _kiloDuzenle() {
    final ctrl = TextEditingController(text: _kiloController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Kilo (kg)', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0A0A0A), border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              setState(() => _kiloController.text = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('TAMAM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _yasDuzenle() {
    final ctrl = TextEditingController(text: _yasController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Yaş', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0A0A0A), border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              setState(() => _yasController.text = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('TAMAM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _acilTelDuzenle() {
    final ctrl = TextEditingController(text: _acilTel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Acil Telefon Numarası',
            style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '+90 555 000 0000',
            hintStyle: TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Color(0xFF0A0A0A),
            border:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              setState(() => _acilTel = ctrl.text);
              StorageHelper.setObserverPhone(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('KAYDET',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _cikisYap() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Çıkış Yap',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Oturumunuz kapatılacak. Emin misiniz?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ÇIKIŞ',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageHelper.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _hesabiSil() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('HESABI KALICI OLARAK SİL',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
            'Hesabınız, verileriniz ve tüm kayıtlarınız anında silinecek. Bu işlem geri alınamaz! Emin misiniz?',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EVET, SİL',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await CloudSyncService.deleteAccountImmediately();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen(reactivationMessage: 'HESABINIZ BAŞARIYLA SİLİNDİ')),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, String status,
      {Color headerColor = Colors.white24}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
          if (status.isNotEmpty)
            Text(status,
                style: TextStyle(
                    color: headerColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      color: kCardBg,
      child: Row(
        children: [
          Icon(icon, color: kGreen.withOpacity(0.8), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.5)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kGreen,
            activeTrackColor: const Color(0xFF43A047),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: kCardBg,
      child: ListTile(
        leading: Icon(icon, color: kGreen.withOpacity(0.8), size: 22),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 22),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      color: kCardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kGreen.withOpacity(0.8), size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: kOrange,
            inactiveColor: Colors.white10,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildEditTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData? trailingIcon,
    Color? trailingColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: kCardBg,
      child: ListTile(
        leading: Icon(icon, color: kGreen.withOpacity(0.8), size: 22),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
              color: Colors.white38, fontSize: 10, height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(trailingIcon ?? Icons.edit, color: trailingColor ?? kOrange, size: 18),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      color: kCardBg,
      child: Row(
        children: [
          Icon(icon, color: kGreen.withOpacity(0.8), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
