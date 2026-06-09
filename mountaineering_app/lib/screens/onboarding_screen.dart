import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../storage_helper.dart';
import 'dart:math' as math;

const Color _kOrange = Color(0xFFFF6B00);
const Color _kGreen = Color(0xFF62FF4C);
const Color _kBg = Color(0xFF0A0A0A);
const Color _kCard = Color(0xFF141414);

class OnboardingScreen extends StatefulWidget {
  final String nextRoute;
  const OnboardingScreen({Key? key, this.nextRoute = '/home'}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  bool _saving = false;

  // Fiziksel veriler
  int _boy = 175;
  int _kilo = 70;
  int _yas = 28;
  String _kanGrubu = 'A+';

  // Acil iletişim
  final _adSoyadCtrl = TextEditingController();
  final _adCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  final List<String> _kanGruplari = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];

  // Tanıtım slaytları
  final List<Map<String, dynamic>> _featureSlides = [
    {
      'title': 'SOS — Tek Dokunuş,\nHayat Kurtarır',
      'tag': 'ACİL DURUM',
      'description': 'SOS butonuna bas, konumun otomatik olarak acil kişine SMS ile gönderilsin. Sesli komutla bile tetiklenebilir.',
      'icon': Icons.crisis_alert,
      'color': const Color(0xFFFF2244),
      'badge': '🆘',
    },
    {
      'title': 'Ekibinin Konumunu\nAnlık Gör',
      'tag': 'EKİP RADARI',
      'description': 'Tüm ekip üyelerinin gerçek zamanlı konumunu haritada izle. Kayıp üye olduğunda anında uyarı al.',
      'icon': Icons.radar,
      'color': const Color(0xFF00AAFF),
      'badge': '📡',
    },
    {
      'title': 'Ekip Kur,\nKoordine Ol',
      'tag': 'EKİP YÖNETİMİ',
      'description': 'Ekip oluştur, üye ekle, ortak görevler belirle. SOS anında tüm ekip aynı anda bilgilendirilsin.',
      'icon': Icons.groups,
      'color': const Color(0xFF62FF4C),
      'badge': '🤝',
    },
    {
      'title': 'Dağcıların\nSosyal Dünyası',
      'tag': 'SOSYAL AKIŞ',
      'description': 'Diğer dağcıların rotalarını, fotoğraflarını ve deneyimlerini keşfet. Beğen, yorum yap, ilham al.',
      'icon': Icons.dynamic_feed,
      'color': const Color(0xFFFFD700),
      'badge': '🏔️',
    },
    {
      'title': 'Profesyonel\nRota Planla',
      'tag': 'ROTA PLANLAMA',
      'description': 'Topografik harita üzerinde waypoint ekle, yükseklik profili gör, GPX olarak dışa aktar. Offline çalışır.',
      'icon': Icons.map,
      'color': const Color(0xFFFF6B00),
      'badge': '🗺️',
    },
    {
      'title': 'Rotanı Paylaş,\nBirlikte Keşfet',
      'tag': 'ROTA PAYLAŞMA',
      'description': 'Planladığın rotayı ekibinle veya tüm toplulukla paylaş. Canlı takipte konumunu gerçek zamanlı yayınla.',
      'icon': Icons.share_location,
      'color': const Color(0xFFAA44FF),
      'badge': '📍',
    },
  ];

  late AnimationController _pulseCtrl;
  late AnimationController _confettiCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      _adSoyadCtrl.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _confettiCtrl.dispose();
    _pageCtrl.dispose();
    _adSoyadCtrl.dispose();
    _adCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_page < 9) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _prevPage() {
    if (_page > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final finalName = _adSoyadCtrl.text.trim().isEmpty ? 'Anonim' : _adSoyadCtrl.text.trim();
      
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': finalName,
          'ad': finalName,
          'boy_cm': _boy,
          'kilo_kg': _kilo,
          'yas': _yas,
          'kan_grubu': _kanGrubu,
          'acil_kisi_ad': _adCtrl.text.trim(),
          'acil_kisi_tel': _telCtrl.text.trim(),
          'onboarding_done': true,
        }, SetOptions(merge: true));
      }
      // Yerel depolamaya da kaydet (Ayarlarda gözükmesi için)
      await StorageHelper.setUserLoggedIn(true, userName: finalName, userEmail: user?.email ?? '');
      await StorageHelper.setHeight(_boy.toString());
      await StorageHelper.setWeight(_kilo.toString());
      await StorageHelper.setAge(_yas.toString());
      await StorageHelper.setBloodType(_kanGrubu);
      await StorageHelper.setObserverPhone(_telCtrl.text.trim());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete_v1', true);
      if (mounted) Navigator.pushReplacementNamed(context, widget.nextRoute);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            _buildProgressBar(),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _page = i);
                  if (i == 9) _confettiCtrl.forward();
                },
                children: [
                  _buildWelcomePage(),
                  _buildPhysicalPage(),
                  _buildEmergencyPage(),
                  ..._featureSlides.map((s) => _buildFeatureSlide(s)),
                  _buildReadyPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: List.generate(10, (i) {
          final done = i <= _page;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: done ? _kOrange : Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Sayfa 1: Karşılama
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeIn(
            duration: const Duration(milliseconds: 800),
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_kOrange.withOpacity(0.3), Colors.transparent]),
                  border: Border.all(color: _kOrange.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.shield, color: _kOrange, size: 64),
              ),
            ),
          ),
          const SizedBox(height: 40),
          FadeInUp(delay: const Duration(milliseconds: 200),
            child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(colors: [_kOrange, Color(0xFFFFD700)]).createShader(b),
              child: Text('ROTA+\'ya\nHoş Geldin!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInUp(delay: const Duration(milliseconds: 400),
            child: Text(
              'Deprem, afet ve acil durumda ekibinle koordineli ol, tek tuşla SOS gönder.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: 48),
          FadeInUp(delay: const Duration(milliseconds: 600),
            child: _buildNavButton('HADİ BAŞLAYALIM', _kOrange, _nextPage, icon: Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  // ── Sayfa 2: Fiziksel Profil
  Widget _buildPhysicalPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(child: _buildPageHeader(Icons.person_pin, 'Fiziksel Profil', 'Navigasyonda daha iyi deneyim için')),
          const SizedBox(height: 32),

          // Kullanıcı Adı
          FadeInLeft(delay: const Duration(milliseconds: 50),
            child: _buildTacticalField('KULLANICI ADI / ÇAĞRI KODU', _adSoyadCtrl, Icons.person, 'Örn: ALFA-1', false),
          ),
          const SizedBox(height: 16),

          // Boy
          FadeInLeft(delay: const Duration(milliseconds: 100),
            child: _buildScrollPicker('BOY', _boy, 100, 250, 'cm', (v) => setState(() => _boy = v)),
          ),
          const SizedBox(height: 16),

          // Kilo
          FadeInLeft(delay: const Duration(milliseconds: 200),
            child: _buildScrollPicker('KİLO', _kilo, 30, 200, 'kg', (v) => setState(() => _kilo = v)),
          ),
          const SizedBox(height: 16),

          // Yaş
          FadeInLeft(delay: const Duration(milliseconds: 300),
            child: _buildScrollPicker('YAŞ', _yas, 10, 100, 'yaş', (v) => setState(() => _yas = v)),
          ),
          const SizedBox(height: 16),

          // Kan grubu
          FadeInLeft(delay: const Duration(milliseconds: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KAN GRUBU', style: GoogleFonts.shareTechMono(color: _kOrange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _kanGruplari.map((k) {
                    final selected = k == _kanGrubu;
                    return GestureDetector(
                      onTap: () => setState(() => _kanGrubu = k),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? _kOrange : _kCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? _kOrange : Colors.white12),
                        ),
                        child: Text(k, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildNavButton('GERİ', Colors.white12, _prevPage, textColor: Colors.white54)),
              const SizedBox(width: 12),
              Expanded(child: _buildNavButton('DEVAM', _kOrange, _nextPage, icon: Icons.arrow_forward)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sayfa 3: Acil İletişim
  Widget _buildEmergencyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(child: _buildPageHeader(Icons.contact_phone, 'Acil Durum Kişisi', 'SOS anında otomatik SMS gönderilecek kişi')),
          const SizedBox(height: 32),
          FadeInLeft(delay: const Duration(milliseconds: 100),
            child: _buildTacticalField('BİRİNCİL KİŞİ ADI (İsteğe Bağlı)', _adCtrl, Icons.person_outline, 'Örn: Ahmet Yıldız', false),
          ),
          const SizedBox(height: 16),
          FadeInLeft(delay: const Duration(milliseconds: 200),
            child: _buildTacticalField('TELEFON NUMARASI (İsteğe Bağlı)', _telCtrl, Icons.phone_outlined, '+90 5xx xxx xx xx', true),
          ),
          const SizedBox(height: 12),
          FadeInLeft(delay: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.3))),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  SizedBox(width: 10),
                  Expanded(child: Text('SOS butonuna bastığınızda bu numaraya otomatik konum SMS\'i gönderilir.', style: TextStyle(color: Colors.amber, fontSize: 12))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildNavButton('GERİ', Colors.white12, _prevPage, textColor: Colors.white54)),
              const SizedBox(width: 12),
              Expanded(child: _buildNavButton('DEVAM', _kOrange, _nextPage, icon: Icons.arrow_forward)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sayfa 4-9: Özellikler Tanıtımı (Detaylı & Premium Görünüm)
  Widget _buildFeatureSlide(Map<String, dynamic> slide) {
    final Color color = slide['color'] as Color;
    return Stack(
      children: [
        // Background Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [color.withOpacity(0.08), Colors.transparent],
              ),
            ),
          ),
        ),
        // Grid pattern
        Positioned.fill(
          child: CustomPaint(painter: _OnboardingGridPainter(color)),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon with Rings
              FadeIn(
                duration: const Duration(milliseconds: 600),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ring
                    Container(
                      width: 170, height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.1), width: 1),
                      ),
                    ),
                    // Middle Ring
                    Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
                      ),
                    ),
                    // Main Icon Box
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.1),
                        border: Border.all(color: color.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.2), blurRadius: 40, spreadRadius: 5)
                        ],
                      ),
                      child: Icon(slide['icon'] as IconData, color: color, size: 48),
                    ),
                    // Badge Emoji
                    Positioned(
                      top: 0, right: 10,
                      child: FadeInRight(
                        delay: const Duration(milliseconds: 400),
                        child: Text(slide['badge'] as String, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Tag
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    slide['tag'] as String,
                    style: GoogleFonts.shareTechMono(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                child: ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [Colors.white, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(b),
                  child: Text(
                    slide['title'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Description
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  slide['description'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),

              const Spacer(),

              // Navigation
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    Expanded(child: _buildNavButton('GERİ', Colors.white12, _prevPage, textColor: Colors.white54)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNavButton('DEVAM', color, _nextPage, icon: Icons.arrow_forward)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sayfa 5: Hazırsın!
  Widget _buildReadyPage() {
    return Stack(
      children: [
        // Confetti particles
        AnimatedBuilder(
          animation: _confettiCtrl,
          builder: (ctx, _) => CustomPaint(
            painter: _ConfettiPainter(progress: _confettiCtrl.value),
            size: MediaQuery.of(ctx).size,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeIn(child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_kGreen.withOpacity(0.4), Colors.transparent]),
                  border: Border.all(color: _kGreen, width: 2),
                ),
                child: const Icon(Icons.check_circle_outline, color: _kGreen, size: 56),
              )),
              const SizedBox(height: 32),
              FadeInUp(delay: const Duration(milliseconds: 200),
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(colors: [_kGreen, Color(0xFF00FFAA)]).createShader(b),
                  child: Text('HAZIRSIN!',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeInUp(delay: const Duration(milliseconds: 400),
                child: Text(
                  'Profilin oluşturuldu.\nHayat kurtarmaya hazırsın.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 15, height: 1.6),
                ),
              ),
              const SizedBox(height: 40),
              FadeInUp(delay: const Duration(milliseconds: 600),
                child: _saving
                  ? const CircularProgressIndicator(color: _kGreen)
                  : _buildNavButton('GÖREVE BAŞLA', _kGreen, _finish,
                      textColor: Colors.black, icon: Icons.rocket_launch),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Yardımcı Widgetlar
  Widget _buildPageHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _kOrange.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: _kOrange, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildScrollPicker(String label, int value, int min, int max, String unit, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: _kOrange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          height: 60,
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: value - min),
                    onSelectedItemChanged: (i) => onChanged(min + i),
                    selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                      background: _kOrange.withOpacity(0.08),
                    ),
                    children: List.generate(max - min + 1, (i) => Center(
                      child: Text('${min + i}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    )),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(unit, style: TextStyle(color: _kOrange.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTacticalField(String label, TextEditingController ctrl, IconData icon, String hint, bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: _kOrange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
          child: TextField(
            controller: ctrl,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.name,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white38, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton(String label, Color bg, VoidCallback onTap, {Color textColor = Colors.white, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: bg == _kOrange || bg == _kGreen
            ? [BoxShadow(color: bg.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
            if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: textColor, size: 18)],
          ],
        ),
      ),
    );
  }
}


// ─── Confetti Painter ──────────────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final math.Random _rng = math.Random(42);
  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final colors = [const Color(0xFFFF6B00), const Color(0xFF62FF4C), const Color(0xFFFFD700), Colors.cyanAccent, Colors.pinkAccent];
    for (int i = 0; i < 60; i++) {
      final x = _rng.nextDouble() * size.width;
      final yStart = -20.0;
      final yEnd = size.height * 1.1;
      final y = yStart + (yEnd - yStart) * progress + _rng.nextDouble() * 60 - 30;
      final color = colors[i % colors.length];
      final paint = Paint()..color = color.withOpacity(1.0 - progress * 0.5);
      canvas.drawCircle(Offset(x, y), _rng.nextDouble() * 4 + 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}

// ── Onboarding Grid Painter ──────────────────────────────────────────────────
class _OnboardingGridPainter extends CustomPainter {
  final Color color;
  _OnboardingGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingGridPainter old) => old.color != color;
}
