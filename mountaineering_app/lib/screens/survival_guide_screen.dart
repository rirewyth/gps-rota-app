import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lottie/lottie.dart';
import '../services/premium_service.dart';

class SurvivalGuideScreen extends StatefulWidget {
  const SurvivalGuideScreen({Key? key}) : super(key: key);

  @override
  State<SurvivalGuideScreen> createState() => _SurvivalGuideScreenState();
}

class _SurvivalGuideScreenState extends State<SurvivalGuideScreen> {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kCardBg = Color(0xFF141414);
  static const Color kRed = Color(0xFFFF3B30);
  static const Color kBlue = Color(0xFF4FC3F7);
  static const Color kAmber = Colors.amber;
  static const Color kPurple = Color(0xFFBB86FC);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremium();
  }

  Future<void> _checkPremium() async {
    final prem = await PremiumService.isPremium();
    if (mounted) setState(() => _isPremium = prem);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'TACTICAL SURVIVAL MANUAL',
              style: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 10, letterSpacing: 2),
            ),
            Text(
              'BÖLÜM ${_currentPage + 1} / 9',
              style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _currentPage >= 3 ? kOrange : Colors.white10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                _currentPage >= 3 ? 'PREMIUM' : 'FREE',
                style: GoogleFonts.shareTechMono(color: _currentPage >= 3 ? kOrange : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Page Progress Indicator
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.white10,
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: MediaQuery.of(context).size.width * ((_currentPage + 1) / 9),
                  color: _currentPage >= 3 ? kPurple : kOrange,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              children: [
                // PAGE 1: DAĞDA HAYATTA KALMA (YENİ)
                _buildPage(
                  title: 'DAĞDA KAYBOLMA PROTOKOLÜ',
                  subtitle: 'ACİL DURUM DAVRANIŞ VE PROTOKOLLERİ',
                  color: kOrange,
                  imagePath: null,
                  imageAtEnd: true,
                  sections: [
                    _buildManualSection('S.T.O.P. KURALI', 'Dur, Düşün, Gözlemle ve Planla. Panik en büyük düşmandır. Konumunuzu belirlemeden hareket etmeyin.', Icons.stop_circle),
                    _buildManualSection('TELEFON VE BATARYA YÖNETİMİ', 'Telefonunuzu aşırı soğuk ve sıcaktan koruyun. Termal veya kaz tüyü ceketinizin iç cebinde, vücut ısınızla temas edecek şekilde saklayın. Batarya ömrü için sinyal olmayan yerlerde uçak moduna alın.', Icons.battery_saver),
                    _buildManualSection('NAVİGASYON TAVSİYESİ', 'Eğer yolunuzu tamamen kaybettiyseniz ve teknik bilginiz yoksa, en yakın akarsuyu akış yönünde takip edin. Akarsular sizi eninde sonunda bir yerleşim yerine ulaştıracaktır.', Icons.water),
                    _buildManualSection('SAAT SAAT PROTOKOL (0-6 SAAT)', '1. SAAT: Barınak yapımı ve ısı yalıtımı. 3. SAAT: Görsel sinyal (ayna, parlak kumaş) hazırlığı. 6. SAAT: Enerji tasarrufu ve sıvı alımı.', Icons.timer),
                  ],
                ),
                // PAGE 2: DEPREM ANI PROTOKOLÜ (YENİ)
                _buildPage(
                  title: 'DEPREM ANI PROTOKOLÜ',
                  subtitle: 'ÇÖK - KAPAN - TUTUN',
                  color: kAmber,
                  imagePath: null,
                  sections: [
                    _buildManualSection('BİNA İÇİNDE', 'Pencere, asansör ve merdivenlerden uzak durun. Sağlam bir masanın altına girin veya iç duvar kenarında çökün. Başınızı kollarınızla koruyun.', Icons.home),
                    _buildManualSection('DIŞARIDA', 'Binalardan, elektrik direklerinden ve ağaçlardan uzaklaşın. Açık bir alanda çökerek sarsıntının geçmesini bekleyin.', Icons.outdoor_grill),
                    _buildManualSection('ARAÇ İÇİNDE', 'Aracı binalardan ve köprülerden uzağa güvenli bir yere çekin. Sarsıntı bitene kadar araç içinde kalın.', Icons.directions_car),
                    _buildManualSection('YATAKTA', 'Yataktaysanız orada kalın, başınızı yastıkla koruyun. Cam kırıkları riskine karşı yatağın altına girmeyin.', Icons.bed),
                  ],
                ),
                // PAGE 3: ENKAZDA HAYATTA KALMA
                _buildPage(
                  title: 'ENKAZ ALTINDA HAYATTA KALMA',
                  subtitle: 'TAKTIKSEL AFET PROTOKOLÜ',
                  color: kRed,
                  imagePath: null,
                  sections: [
                    _buildManualSection('İLK MÜDAHALE (0-3 SAAT)', 'Ağzınızı ve burnunuzu bir bezle kapatın. Enerjinizi tüketmemek için gereksiz bağırmaktan kaçının. Çevredeki sesleri dinleyin.', Icons.emergency),
                    _buildManualSection('İLETİŞİM VE SES', 'Uygulamanın deprem bölümünden akustik modülü açın, sakin kalın, dışarıdan “sesimi duyan var mı” çağrısını duyana kadar belirli aralıklarla küçük sesler çıkarmaya bakın, çağrıyı duyduğunuzda tüm gücünüzle sesinizi iletmeye çalışın.', Icons.settings_input_component),
                    _buildManualSection('UZUN SÜRELİ STRATEJİ (2. GÜN+)', 'Bilincinizi açık tutmak için kendinizle veya varsa yanınızdakilerle konuşun. Susuzlukla mücadele için tükürük salgısını artıracak yöntemler deneyin.', Icons.hourglass_bottom),
                    _buildManualSection('PROFESYONEL DAVRANIŞ', 'Ekiplerin geldiğini duyduğunuzda enerjinizi toplayıp en güçlü sesi çıkarın. Işık sızan noktalara odaklanın.', Icons.psychology),
                  ],
                ),
                // PAGE 4: İLK YARDIM
                _buildPage(
                  title: 'İLK YARDIM VE TIBBİ PROTOKOL',
                  subtitle: 'ACİL MÜDAHALE ADIMLARI',
                  color: kBlue,
                  imagePath: 'assets/guides/medical_guide.png',
                  sections: [
                    _buildManualSection('HİPOTERMİ YÖNETİMİ', 'Yaralıyı ıslak kıyafetlerden arındırın , vücudu rüzgarlı ortamlardan uzak tutun yaralı bulunduğu yerden taşınması mümkün değil ise altına mont veya mat tarzı malzemeler koyun ve yanınızdaki ekipmanlarla çadır veya barınak yapmaya çalışın.', Icons.ac_unit),
                    _buildManualSection('KANAMA KONTROLÜ', 'Yaralıda kanama durumu mevcut ise kanama olan nokta üstünü bir bez ile örtün kanama durmuyor ise bu süreci üçüncü bez üst üste gelene kadar tekrarlayın . Üçüncü bez çevrildiği halde kanama devam ediyorsa dördüncü bez ile üç bezin etrafını sararak bir düğüm atın , düğüme rağmen kanama devam ediyorsa bir çubuğu düğümün içinden geçirin ve kanama durana kadar sıkın . Kesinlikle kanama durduktan sonra acil yardım ekipleri gelene kadar veya şehre inene kadar bası/kanama noktasındaki malzemeleri çıkarmayın aksi takdirde kanama devam edecektir.\n\nKanama fışkırırcasına geliyor ise uygulama içindeki kanama noktasına bez prosedürünün aynısını uygulayın bu duruma rağmen durmuyor ise. Turnike(boğucu sargı yöntemi) ile uygulama içindeki en yakın bası noktasını öğrenip bu noktaya (kemer gibi malzemeler hariç) yada tshirtten yapacağınız bir uzun bez/bandanayı bası noktasının olduğu damarın üstüne düğüm atarak sıkın ve turnike yaptığınız saati kişinin kanı veya kalem içindeki bir mürekkep tarzı madde ile alnına veya vücudunun gözükür yüzüne yazın ve 15 dakika da 1 bası noktasındaki boğucu sargıyı ve kişi üzerindeki saati güncelleyin.', Icons.bloodtype),
                    _buildManualSection('HİPERTERMİ YÖNETİMİ', 'Yaralı sıcaktan aşırı seviyede etkilendi ve yürüyecek hali yok ise yaralıyı güneşten uzak havadar bir alana alın koltuk altlarını , ayak uçlarını yükselterek , alnına, koltuk altına ve ayak uçlarına serin veya soğuk malzemeler(soğuk su,ıslak bez olabilir) koyun.', Icons.wb_sunny),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.white10), color: Colors.black),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _showZoomableImage(context, 'assets/guides/hipertermi_guide.jpg'),
                              child: Image.asset('assets/guides/hipertermi_guide.jpg', fit: BoxFit.contain),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              width: double.infinity,
                              color: Colors.white10,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.zoom_in, color: Colors.white38, size: 14),
                                  const SizedBox(width: 8),
                                  Text('Şemayı büyütmek için dokunun', style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // PAGE 5: BASI NOKTALARI
                _buildPage(
                  title: 'İLKYARDIMDA BASI NOKTALARI',
                  subtitle: 'KANAMAYI DURDURMAK İÇİN KAS SİSTEMİ UYGULAMASI',
                  color: Colors.redAccent,
                  sections: [
                    _buildManualSection('NASIL UYGULANIR?', '• Doğrudan kanayan bölgeye veya en yakın bası noktasına bası yapın.\n• 5-10 dakika süreyle kesintisiz basın.\n• Mümkünse yaralı bölgeyi kalp seviyesinin üzerinde tutun.\n• Kanama durana kadar basıya devam edin.\n\nÖNEMLİ: Bası noktaları kemik üzerine değil, kas dokusu üzerine yapılır. Kanama durmuyorsa tıbbi yardım isteyin.', Icons.front_hand),
                    _buildManualSection('TEMEL BASI NOKTALARI', '1. Şakak (Temporal)\n2. Çene Altı (Fasiyal)\n3. Köprücük Üstü (Subklaviyan)\n4. Kolun Üst Kısmı (Brachial)\n5. Ön Kol (Radiyal)\n6. Kasık (Femoral)\n7. Diz Arkası (Popliteal)\n8. Ensenin Yanı (Karotid Sinüs)\n9. Koltuk Altı (Aksiller)\n10. El Bileği İçi (Ulnar)\n11. Topuk Üstü (Posterior Tibial)', Icons.accessibility_new),
                  ],
                ),
                // PAGE 6: İLKYARDIM ÇANTASI
                _buildPage(
                  title: 'İLKYARDIM ÇANTASI',
                  subtitle: 'TEMEL VE İLERİ SEVİYE MALZEMELER',
                  color: kBlue,
                  imagePath: null,
                  sections: [
                    _buildManualSection('1 GÜNLÜK YÜRÜYÜŞ İÇİN', '• İnce bir ilk yardım battaniyesi\n• Sargı bezi\n• Antiseptik (Betadin)\n• Yapışkan yara bandı, çeşitli boyda\n• Steril gazlı bez\n• Elastik bandaj (6 cm eninde)\n• Yapışkan elastik bandaj (6 cm eninde)\n• Dayanıklı tıbbi bant\n• Bir paket Steri-Strip (küçük yaralar için kelebek bandajı)\n• Second Skin (açık yara ve kabarcıkları kapatmak için)\n• Asetaminofen (Parasetamol)\n• Düdük\n• Cımbız+küçük makas\n• Lateks eldiven', Icons.medical_information),
                    _buildManualSection('1 HAFTALIK ETKİNLİK İÇİN', '• İnce bir ilk yardım battaniyesi\n• Sargı bezi\n• Antiseptik (Betadin)\n• Yapışkan yara bandı, çeşitli boyda\n• Steril gazlı bez\n• Elastik bandaj (6 cm eninde)\n• Yapışkan elastik bandaj (6 cm eninde)\n• Dayanıklı tıbbi bant\n• Bir paket Steri-Strip (küçük yaralar için kelebek bandajı)\n• Second Skin (açık yara ve kabarcıkları kapatmak için)\n• Asetaminofen (Parasetamol)\n• Düdük\n• Cımbız+küçük makas\n• Lateks eldiven\n• Aspirin\n• Kuvvetli ağrı kesici (Minoset, Apranax)\n• İshal ilacı (Loperamid+ bağırsak antiseptiği (Ercefuryl))\n• Geniş spektrumlu antibiyotik (Amoksisilin)\n• Bir tüp C vitamini\n• Göz duşu (Plum)\n• Güneş yanığı kremi (Bepanten)\n• Küçük Atel (Sam Splint)\n• Yedek güneş gözlüğü', Icons.backpack),
                  ],
                ),
                // PAGE 6: TEKNİK BİLGİLER (PREMIUM)
                _buildPremiumPage(
                  title: 'TEKNİK DAĞCILIK VE EMNİYET',
                  subtitle: 'DÜĞÜMLER VE İLERİ TEKNİKLER',
                  color: kAmber,
                  imagePath: 'assets/guides/knots_guide.jpg',
                  sections: [
                    _buildManualSection('TEMEL DAĞCILIK DÜĞÜMLERİ', 'Alpin Kelebek, Tam Kazık, Yarım Kazık, Açık/Kapalı Sekizli, Camadan, Prusik, Çift Balıkçı, Perlon ve Karadüğüm gibi 10 temel dağcılık düğümünün adım adım atılışı ve kullanım alanları.', Icons.reorder),
                  ],
                ),
                // PAGE 5: YÜKSEK İRTİFA TIBBI (PREMIUM)
                _buildPremiumPage(
                  title: 'İLERİ DAĞ TIBBI',
                  subtitle: 'AMS, HACE VE HAPE PROTOKOLLERİ',
                  color: kPurple,
                  imagePath: 'assets/guides/altitude_guide.png',
                  sections: [],
                ),
                // PAGE 6: TAKTİKSEL KURTARMA (PREMIUM)
                _buildPremiumPage(
                  title: 'PROFESYONEL KURTARMA',
                  subtitle: 'HELİKOPTER TAHLİYE VE SİNYALLER',
                  color: kPurple,
                  imagePath: 'assets/guides/helicopter_signals.jpg',
                  sections: [
                    _buildManualSection('VÜCUT DİLİ: EVET (Y)', 'Kollarınızı yukarı doğru açık şekilde kaldırarak vücudunuzla "Y" harfi oluşturun. ANLAMI: "Yardıma ihtiyacım var / Beni alın".', Icons.check_circle_outline),
                    _buildManualSection('VÜCUT DİLİ: HAYIR (T)', 'Kollarınızı omuz hizasında yana doğru açarak vücudunuzla "T" harfi oluşturun. ANLAMI: "Yardıma ihtiyacım yok / Devam edin".', Icons.cancel_outlined),
                    _buildManualSection('YER SİNYALLERİ (HAVADAN GÖRÜNÜM)', 'Eğer mümkünse yere taşlarla, parlak kumaşlarla veya karı çiğneyerek büyük bir "Y" (Yardım Gerekli) veya "X" (Tıbbi Yardım Gerekli) çizin. Helikopter pilotları bu geometrik şekilleri doğal oluşumlardan kolayca ayırt edebilir.', Icons.visibility),
                    _buildManualSection('HELİKOPTER GÖRSEL İLETİŞİM', 'Arama kurtarma helikopteri yaklaştığında yerinizi belli etmek için ayna, flaşör veya renkli duman kullanın. Helikopter size yaklaştığında asla pervanelere doğru koşmayın, pilotun talimatlarını bekleyin.', Icons.airplanemode_active),
                  ],
                ),
              ],
            ),
          ),
          
          // Navigation Footer
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton.icon(
                    onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.ease),
                    icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 16),
                    label: Text('ÖNCEKİ', style: GoogleFonts.shareTechMono(color: Colors.white54)),
                  )
                else
                  const SizedBox(),
                
                if (_currentPage < 8)
                  ElevatedButton.icon(
                    onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.ease),
                    style: ElevatedButton.styleFrom(backgroundColor: _currentPage >= 2 ? kPurple : kOrange, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    icon: const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
                    label: Text('SONRAKİ BÖLÜM', style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    icon: const Icon(Icons.check, color: Colors.white, size: 16),
                    label: Text('TAMAMLA', style: GoogleFonts.shareTechMono(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPage({
    required String title,
    required String subtitle,
    required Color color,
    String? imagePath,
    bool isLottie = false,
    bool imageAtEnd = false,
    required List<Widget> sections,
  }) {
    // Premium kilidi kaldırıldı, tüm kullanıcılara ücretsiz.
    return _buildPage(title: title, subtitle: subtitle, color: color, imagePath: imagePath, isLottie: isLottie, imageAtEnd: imageAtEnd, sections: sections);
  }

  Widget _buildPremiumLockedScreen(String title) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kPurple.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: kPurple.withOpacity(0.3))),
            child: const Icon(Icons.lock_person_rounded, color: kPurple, size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Bu bölüm ileri düzey teknik bilgiler içerir ve sadece Premium üyelerimize özeldir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => PremiumService.showPremiumRequired(context, title),
            style: ElevatedButton.styleFrom(backgroundColor: kPurple, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('PREMIUM\'A YÜKSELT', style: GoogleFonts.shareTechMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showZoomableImage(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 5.0,
              child: Image.asset(imagePath),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required String title,
    required String subtitle,
    required Color color,
    String? imagePath,
    bool isLottie = false,
    bool imageAtEnd = false,
    required List<Widget> sections,
  }) {
    Widget? imageWidget;
    if (imagePath != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.white10), color: Colors.black),
          child: Column(
            children: [
              if (isLottie)
                 _buildRescueDiagram(color)
              else
                 GestureDetector(
                   onTap: () => _showZoomableImage(context, imagePath),
                   child: Image.asset(imagePath, fit: BoxFit.contain),
                 ),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                color: Colors.white10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white38, size: 14),
                    const SizedBox(width: 8),
                    Text(isLottie ? 'PROFESYONEL SİSTEM' : 'Şemayı büyütmek için dokunun', style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            child: Text(
              'OFFICIAL PROTOCOL',
              style: GoogleFonts.shareTechMono(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          Text(subtitle, style: GoogleFonts.shareTechMono(color: color, fontSize: 14, letterSpacing: 1)),
          const SizedBox(height: 24),
          
          if (imageWidget != null && !imageAtEnd) ...[
             imageWidget,
             const SizedBox(height: 32),
          ],
          
          ...sections,

          if (imageWidget != null && imageAtEnd) ...[
             const SizedBox(height: 32),
             imageWidget,
          ],

          const SizedBox(height: 40),
          Center(
            child: Opacity(
              opacity: 0.05,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 4)),
                  child: Text('ROTA+ TACTICAL SYSTEM', style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRescueDiagram(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomPaint(painter: TechnicalDiagramPainter(color)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStepIcon(Icons.anchor, 'İSTASYON', color),
              Icon(Icons.arrow_forward, color: color.withOpacity(0.3), size: 16),
              _buildStepIcon(Icons.settings_input_component, 'Z-SİSTEM', color),
              Icon(Icons.arrow_forward, color: color.withOpacity(0.3), size: 16),
              _buildStepIcon(Icons.person_pin_circle_outlined, 'TAHLİYE', color),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          _buildRescueDetailRow('İstasyon: Çift emniyetli ana ankraj.', color),
          _buildRescueDetailRow('Z-Sistemi: 3:1 mekanik avantaj düzeni.', color),
          _buildRescueDetailRow('Tahliye: Sedye stabilizasyonu ve çekiş.', color),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: color, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Şemalar teknik kütüphaneden (PRO) alınmıştır. Tüm ekipman sertifikalı olmalıdır.',
                    style: GoogleFonts.outfit(color: color.withOpacity(0.7), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.shareTechMono(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRescueDetailRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSection(String title, String content, IconData icon) {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _currentPage >= 3 ? kPurple : kOrange, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                content,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 15) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 15) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TechnicalDiagramPainter extends CustomPainter {
  final Color color;
  TechnicalDiagramPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final dashPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Terrain Outline (Background)
    final terrainPath = Path();
    terrainPath.moveTo(0, size.height * 0.85);
    terrainPath.lineTo(size.width * 0.2, size.height * 0.7);
    terrainPath.lineTo(size.width * 0.4, size.height * 0.9);
    terrainPath.lineTo(size.width * 0.7, size.height * 0.6);
    terrainPath.lineTo(size.width, size.height * 0.8);
    canvas.drawPath(terrainPath, dashPaint);

    // 2. Helicopter Detailed Silhouette
    final heliCenter = Offset(size.width * 0.4, size.height * 0.35);
    // Rotor blades
    canvas.drawLine(heliCenter + const Offset(-70, -15), heliCenter + const Offset(70, -15), paint);
    canvas.drawLine(heliCenter + const Offset(0, -15), heliCenter + const Offset(0, 0), paint);
    // Body
    final bodyPath = Path();
    bodyPath.moveTo(heliCenter.dx - 40, heliCenter.dy);
    bodyPath.quadraticBezierTo(heliCenter.dx, heliCenter.dy - 30, heliCenter.dx + 40, heliCenter.dy);
    bodyPath.lineTo(heliCenter.dx + 80, heliCenter.dy + 5); // Tail boom
    bodyPath.lineTo(heliCenter.dx + 80, heliCenter.dy - 15);
    bodyPath.close();
    canvas.drawPath(bodyPath, paint);
    canvas.drawPath(bodyPath, fillPaint);
    // Skids
    canvas.drawLine(heliCenter + const Offset(-30, 20), heliCenter + const Offset(30, 20), paint);
    canvas.drawLine(heliCenter + const Offset(-20, 0), heliCenter + const Offset(-25, 20), paint);
    canvas.drawLine(heliCenter + const Offset(20, 0), heliCenter + const Offset(25, 20), paint);

    // 3. Rope Rescue System (Z-Rig Style)
    final anchorPoint = Offset(size.width * 0.1, size.height * 0.65);
    final loadPoint = Offset(size.width * 0.8, size.height * 0.8);
    
    // Main line
    canvas.drawLine(anchorPoint, loadPoint, paint);
    
    // Pulleys & Carabiners
    _drawPulley(canvas, anchorPoint, paint);
    _drawPulley(canvas, Offset(size.width * 0.45, size.height * 0.725), paint);
    
    // Mechanical advantage lines
    final maPath = Path();
    maPath.moveTo(size.width * 0.45, size.height * 0.725);
    maPath.lineTo(size.width * 0.3, size.height * 0.5);
    canvas.drawPath(maPath, dashPaint);

    // 4. Stretcher / Victim Silhouette
    final stretcherPos = loadPoint;
    canvas.drawRect(Rect.fromCenter(center: stretcherPos, width: 40, height: 10), paint);
    canvas.drawCircle(stretcherPos + const Offset(-15, -5), 4, paint); // Head icon

    // 5. Vectors & Angles
    canvas.drawArc(Rect.fromCircle(center: anchorPoint, radius: 20), 0, 0.8, false, dashPaint);
    
    // HUD circles
    canvas.drawCircle(heliCenter, 90, dashPaint);
    canvas.drawCircle(heliCenter, 95, dashPaint..strokeWidth = 0.5);
  }

  void _drawPulley(Canvas canvas, Offset pos, Paint paint) {
    canvas.drawCircle(pos, 6, paint);
    canvas.drawCircle(pos, 3, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
