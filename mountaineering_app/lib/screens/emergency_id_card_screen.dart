import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database_helper.dart';
import '../services/tactical_styles.dart';
import '../storage_helper.dart';
import 'edit_profile_screen.dart';

/// Yüksek kontrastlı tam ekran Acil Durum İletişim & Medikal Künye Ekranı.
class EmergencyIdCardScreen extends StatefulWidget {
  const EmergencyIdCardScreen({super.key});

  @override
  State<EmergencyIdCardScreen> createState() => _EmergencyIdCardScreenState();
}

class _EmergencyIdCardScreenState extends State<EmergencyIdCardScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _loading = true;
  bool _isSpeaking = false;
  bool _highContrastLockMode = false;

  String _name = 'ROTA+ Operatörü';
  String _uidShort = 'ROTA-ID';
  String _bloodType = 'Belirtilmedi';
  String _medicalInfo = 'Bilinen kronik rahatsızlık / alerji girilmedi.';
  String _emergencyName = 'Tanımlanmadı';
  String _emergencyPhone = '';

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('tr-TR');
    _tts.setSpeechRate(0.48);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _loadMedicalProfile();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadMedicalProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final storedName = await StorageHelper.getUserName();
      final storedEmail = await StorageHelper.getUserEmail();
      final storedBlood = await StorageHelper.getBloodType();
      final storedMedical = await StorageHelper.getMedicalInfo();

      String name = storedName ?? user?.displayName ?? 'ROTA+ Operatörü';
      String blood = storedBlood ?? '';
      String medical = storedMedical ?? '';
      String emName = '';
      String emPhone = '';

      if (storedEmail != null && storedEmail.isNotEmpty) {
        final dbUser = await DatabaseHelper.instance.kullaniciBul(storedEmail);
        if (dbUser != null) {
          if ((dbUser['ad_soyad'] ?? '').toString().isNotEmpty) {
            name = dbUser['ad_soyad'].toString();
          }
          if ((dbUser['kan_grubu'] ?? '').toString().isNotEmpty) {
            blood = dbUser['kan_grubu'].toString();
          }
          if ((dbUser['tibbi_bilgi'] ?? '').toString().isNotEmpty) {
            medical = dbUser['tibbi_bilgi'].toString();
          }
          if ((dbUser['acil_kisi'] ?? '').toString().isNotEmpty) {
            emName = dbUser['acil_kisi'].toString();
          }
          if ((dbUser['acil_tel'] ?? '').toString().isNotEmpty) {
            emPhone = dbUser['acil_tel'].toString();
          }
        }
      }

      if (mounted) {
        setState(() {
          _name = name;
          _uidShort = user != null ? user.uid.substring(0, 8).toUpperCase() : 'ROTA-ID';
          _bloodType = blood.isNotEmpty ? blood : 'Belirtilmedi';
          _medicalInfo = medical.isNotEmpty
              ? medical
              : 'Bilinen kronik rahatsızlık veya alerji girilmedi.';
          _emergencyName = emName.isNotEmpty ? emName : 'Tanımlanmadı';
          _emergencyPhone = emPhone;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSpeakCard() async {
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    if (mounted) setState(() => _isSpeaking = true);
    final summary =
        'Acil durum medikal künyesi. Operatör: $_name. Kan grubu: $_bloodType. Tıbbi bilgi: $_medicalInfo. Acil durum kişisi: $_emergencyName.';
    await _tts.speak(summary);
  }

  Future<void> _callEmergencyContact() async {
    if (_emergencyPhone.trim().isEmpty) return;
    final clean = _emergencyPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String get _payloadSummary =>
      'ROTA+ MEDIKAL KUNYE\nAD:$_name\nKAN:$_bloodType\nTIBBI:$_medicalInfo\nACIL:$_emergencyName $_emergencyPhone';

  @override
  Widget build(BuildContext context) {
    final bgColor = _highContrastLockMode ? Colors.black : TacticalStyles.kBackground;
    final cardBorder = _highContrastLockMode
        ? TacticalStyles.kError
        : TacticalStyles.kError.withValues(alpha: 0.45);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TacticalStyles.kOnSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: TacticalStyles.glassCardDecoration(
            radius: 999,
            borderColor: TacticalStyles.kError.withValues(alpha: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medical_information_rounded, color: TacticalStyles.kError, size: 14),
              const SizedBox(width: 6),
              Text(
                'ACİL MEDİKAL KÜNYE',
                style: TacticalStyles.labelCaps(
                  color: TacticalStyles.kError,
                  size: 11,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isSpeaking ? 'Durdur' : 'Sesli Oku',
            icon: Icon(
              _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
              color: _isSpeaking ? TacticalStyles.kError : TacticalStyles.kPrimary,
            ),
            onPressed: _toggleSpeakCard,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TacticalStyles.kError))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kilit Ekranı / Yüksek Kontrast Anahtarı
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: TacticalStyles.glassCardDecoration(radius: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.screen_lock_portrait_rounded,
                            color: TacticalStyles.kPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YÜKSEK KONTRAST KİLİT MODU',
                                style: TacticalStyles.labelCaps(
                                  color: TacticalStyles.kOnSurface,
                                  size: 11,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Karanlıkta kurtarma ekiplerinin hızlı okuması için',
                                style: TacticalStyles.body(
                                  color: TacticalStyles.kOnSurfaceVariant,
                                  size: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _highContrastLockMode,
                          activeColor: TacticalStyles.kError,
                          onChanged: (v) => setState(() => _highContrastLockMode = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ana Medikal Kimlik Kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: TacticalStyles.glassCardDecoration(
                      radius: 20,
                      borderColor: cardBorder,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OPERATÖR KİMLİĞİ',
                                    style: TacticalStyles.labelMicro(
                                      color: TacticalStyles.kError,
                                      size: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _name,
                                    style: TacticalStyles.headline(
                                      color: TacticalStyles.kOnSurface,
                                      size: 22,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: $_uidShort',
                                    style: TacticalStyles.telemetry(
                                      color: TacticalStyles.kOnSurfaceVariant,
                                      size: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: TacticalStyles.kError.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: TacticalStyles.kError.withValues(alpha: 0.65),
                                  width: 1.4,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'KAN GRUBU',
                                    style: TacticalStyles.labelMicro(
                                      color: TacticalStyles.kError,
                                      size: 8.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _bloodType,
                                    style: TacticalStyles.headline(
                                      color: Colors.white,
                                      size: 18,
                                      weight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: TacticalStyles.kOutlineVariant),
                        const SizedBox(height: 14),

                        Text(
                          'ALERJİLER & TIBBİ NOTLAR',
                          style: TacticalStyles.labelMicro(
                            color: TacticalStyles.kPrimary,
                            size: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _medicalInfo,
                          style: TacticalStyles.body(
                            color: TacticalStyles.kOnSurface,
                            size: 14,
                          ).copyWith(height: 1.5),
                        ),

                        const SizedBox(height: 18),
                        Text(
                          'ACİL DURUM İLETİŞİM KİŞİSİ',
                          style: TacticalStyles.labelMicro(
                            color: TacticalStyles.kTertiary,
                            size: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: TacticalStyles.recessedDecoration(radius: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.contact_phone_rounded,
                                  color: TacticalStyles.kTertiary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _emergencyName,
                                      style: TacticalStyles.headline(
                                        color: TacticalStyles.kOnSurface,
                                        size: 14,
                                      ),
                                    ),
                                    Text(
                                      _emergencyPhone.isNotEmpty
                                          ? _emergencyPhone
                                          : 'Telefon numarası eklenmedi',
                                      style: TacticalStyles.telemetry(
                                        color: TacticalStyles.kOnSurfaceVariant,
                                        size: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_emergencyPhone.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: _callEmergencyContact,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TacticalStyles.kTertiary,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.call, size: 16),
                                  label: const Text(
                                    'ARA',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // QR Medikal Künye Kartı
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: TacticalStyles.glassCardDecoration(radius: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _payloadSummary,
                            version: QrVersions.auto,
                            size: 112,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DİJİTAL MEDİKAL KÜNYE',
                                style: TacticalStyles.labelCaps(
                                  color: TacticalStyles.kPrimary,
                                  size: 11,
                                  weight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Kan grubu, tıbbi notlar ve acil kişi özetiniz cihazda çevrimdışı saklanır.',
                                style: TacticalStyles.body(
                                  color: TacticalStyles.kOnSurfaceVariant,
                                  size: 12,
                                ).copyWith(height: 1.45),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EditProfileScreen(),
                                    ),
                                  );
                                  _loadMedicalProfile();
                                },
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text('Bilgileri Güncelle'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: TacticalStyles.kPrimary,
                                  side: BorderSide(
                                    color: TacticalStyles.kPrimary.withValues(alpha: 0.55),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
