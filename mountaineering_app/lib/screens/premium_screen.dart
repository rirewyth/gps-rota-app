import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io' show Platform;
import '../services/premium_service.dart';
import '../services/tactical_styles.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _purchasing = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isPremium = false;
  String _selectedPlanId = 'rota_premium_12m';
  late StreamSubscription<bool> _purchaseSub;

  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.wb_twilight_rounded,
      'title': 'Güneş & Gece Operasyon Radarı',
      'desc': 'Offline güneş yörüngesi, kalan gün ışığı sayacı, altın saat kamp limiti ve ay aydınlatması.',
      'color': Colors.orangeAccent,
    },
    {
      'icon': Icons.ac_unit_rounded,
      'title': 'Hipotermi & Rüzgar Soğuğu Kalkanı',
      'desc': 'Hedef irtifaya göre Wind Chill, donma süresi (dk), matara donma uyarısı ve katman önerisi.',
      'color': Colors.cyanAccent,
    },
    {
      'icon': Icons.flashlight_on_rounded,
      'title': 'Mors Feneri & Sinyal İstasyonu',
      'desc': 'Özel mesajınızı telefon flaşıyla gerçek Mors koduna çevirip yayınlayın + kırmızı gece feneri.',
      'color': Colors.redAccent,
    },
    {
      'icon': Icons.backpack_rounded,
      'title': 'Ekipman & Kalori Planlayıcı PRO',
      'desc': 'Ekspedisyon süresine ve irtifaya göre otomatik teknik çanta listesi, ağırlık (kg), su ve kalori hesabı.',
      'color': Colors.amber,
    },
    {
      'icon': Icons.workspace_premium_rounded,
      'title': 'Zirve Pasaportu & Sertifika PRO',
      'desc': 'GPS koordinatlı zirve günlüğü, alpinist rütbeleri ve paylaşılabilir dijital Zirve Sertifikası.',
      'color': Colors.tealAccent,
    },
    {
      'icon': Icons.speed_rounded,
      'title': 'Barometre & Fırtına Radarı PRO',
      'desc': '24 saatlik hPa basınç eğrisi, 3 saatlik fırtına risk uyarısı ve yüksek irtifa oksijen yoğunluğu.',
      'color': Colors.lightBlueAccent,
    },
    {
      'icon': Icons.shield_moon_rounded,
      'title': 'Otomatik Hareketsizlik SOS',
      'desc': 'Dead Man\'s Switch: Seçtiğiniz süre hareket algılanmazsa 30 sn onay sonrası otomatik SOS gönderir.',
      'color': Colors.redAccent,
    },
    {
      'icon': Icons.route_rounded,
      'title': 'Profesyonel GPX Dışa Aktarma',
      'desc': 'Rotalarınızı Garmin, Strava ve Suunto uyumlu standart .gpx dosyası olarak dışa aktarın.',
      'color': Colors.amber,
    },
    {
      'icon': Icons.auto_graph_rounded,
      'title': 'Akıllı Eğim & Zirve Analizi',
      'desc': 'Naismith kuralıyla tırmanış süresi, maksimum eğim açısı ve >30° dik eğim/çığ riski analizi.',
      'color': Colors.cyanAccent,
    },
    {
      'icon': Icons.verified,
      'title': 'Onaylı Mavi Tik',
      'desc': 'Profilinizde ve gönderilerinizde onaylı mavi tik rozeti sergileyin.',
      'color': Colors.blueAccent,
    },
    {
      'icon': Icons.radar,
      'title': 'Canlı İzleme',
      'desc': 'Bir aktivite sırasında konumunuzu arkadaşlarınızla ve sevdiklerinizle paylaşın.',
      'color': Colors.blue,
    },
    {
      'icon': Icons.view_in_ar,
      'title': '3D Dağ Görünümü',
      'desc': 'Mapbox altyapısı ile dağları ve vadileri 3 boyutlu olarak inceleyin, gerçek arazi yapısını görün.',
      'color': Colors.teal,
    },
    {
      'icon': Icons.track_changes,
      'title': 'Night Ops',
      'desc': 'Gözlerinizi yormayan, gece görüşünü koruyan özel taktiksel kırmızı arayüz.',
      'color': Colors.redAccent,
    },
    {
      'icon': Icons.layers,
      'title': 'Taktiksel Katmanlar',
      'desc': 'Gece operasyonları ve düşük görüş için optimize edilmiş taktiksel karanlık mod haritaları.',
      'color': Colors.indigo,
    },
    {
      'icon': Icons.psychology,
      'title': 'AI Rota Danışmanı',
      'desc': 'Rotadan saptığınızda size en güvenli dönüş yolunu yapay zeka ile anlık olarak sunar.',
      'color': Colors.purpleAccent,
    },
    {
      'icon': Icons.public,
      'title': 'Küresel Uydu Takibi',
      'desc': 'Tüm dünyayı kapsayan yüksek çözünürlüklü uydu görüntüleri ile rotanızı her detayda planlayın.',
      'color': Colors.blueGrey,
    },
    {
      'icon': Icons.terrain,
      'title': 'Topografik Haritalar',
      'desc': 'Çevrimdışı ve detaylı dağ haritalarına, izohips eğrilerine erişin.',
      'color': Colors.green,
    },
    {
      'icon': Icons.block,
      'title': 'Reklamsız Deneyim',
      'desc': 'Tüm reklamları kaldırın, dikkatinizi sadece doğaya ve güvenliğinize verin.',
      'color': Colors.grey,
    },
    {
      'icon': Icons.wb_cloudy,
      'title': 'Hava Durumu & Radar',
      'desc': 'Hava değişimlerini ve fırtına uyarılarını önceden fark edin.',
      'color': Colors.amber,
    },
    {
      'icon': Icons.route,
      'title': 'Sınırsız Rota',
      'desc': 'Sınır olmadan rota planlayın, kaydedin ve arkadaşlarınızla paylaşın.',
      'color': Colors.orange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadProducts();
    _purchaseSub = PremiumService.purchaseStatusStream.listen((success) {
      if (mounted) {
        if (success) {
          _checkStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Satın alım başarılı! Premium aktif edildi.'), backgroundColor: Colors.green),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: TacticalStyles.kSurfaceLow,
              title: const Text('İşlem Tamamlanamadı', style: TextStyle(color: TacticalStyles.kOnSurface)),
              content: const Text('Satın alma işlemi başarısız oldu veya iptal edildi.', style: TextStyle(color: TacticalStyles.kOnSurfaceVariant)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tamam', style: TextStyle(color: TacticalStyles.kTertiary)),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _purchaseSub.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final status = await PremiumService.isPremium();
    if (mounted) setState(() => _isPremium = status);
  }

  Future<void> _loadProducts() async {
    final prods = await PremiumService.fetchProducts();
    if (mounted) {
      setState(() {
        _products = prods;
        _loading = false;
      });
    }
  }

  void _buyProduct(ProductDetails prod) async {
    setState(() => _purchasing = true);
    try {
      await PremiumService.buyProduct(prod);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: TacticalStyles.kSurfaceLow,
            title: const Text('Satın Alma Başarısız', style: TextStyle(color: TacticalStyles.kOnSurface)),
            content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tamam', style: TextStyle(color: TacticalStyles.kTertiary)),
              )
            ]
          )
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color kGreen = TacticalStyles.kTertiary;
    const Color kDarkBg = TacticalStyles.kSurface;

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: kDarkBg,
        elevation: 0,
        centerTitle: true,
        title: TacticalStyles.appBarPill('ROTA+ PRO', color: Colors.amber, icon: Icons.workspace_premium_rounded),
        leading: IconButton(
          icon: const Icon(Icons.close, color: TacticalStyles.kOnSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              'ROTA+ Premium\nAbonesi Ol',
              textAlign: TextAlign.center,
              style: TacticalStyles.displayHero(
                size: 30,
                color: TacticalStyles.kOnSurface,
              ).copyWith(height: 1.15),
            ),
            const SizedBox(height: 30),
            
            // Feature Slider
            SizedBox(
              height: 250,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemCount: _features.length,
                itemBuilder: (ctx, i) {
                  return FadeIn(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _features[i]['color'].withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: _features[i]['color'].withOpacity(0.3)),
                          ),
                          child: Icon(_features[i]['icon'], size: 60, color: _features[i]['color']),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _features[i]['title'],
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontSize: 20, fontWeight: FontWeight.bold, color: TacticalStyles.kOnSurface),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _features[i]['desc'],
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontSize: 14, color: TacticalStyles.kOnSurfaceVariant, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_features.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? kGreen : TacticalStyles.kOutlineVariant,
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 40),
            
            // Pricing / Status Section
            if (_isPremium)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGreen.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars, color: kGreen, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'TEBRİKLER!',
                        style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontSize: 20, fontWeight: FontWeight.bold, color: TacticalStyles.kOnSurface),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Siz bir ROTA+ Premium üyesisiniz. Tüm ayrıcalıklı özelliklerin keyfini çıkarın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Pricing Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _loading 
                  ? const CircularProgressIndicator(color: kGreen)
                  : Row(
                    children: [
                      // Yearly Plan
                      Expanded(
                        child: _buildPriceCard(
                          title: '1 Yıl',
                          price: '₺500',
                          monthlyPrice: '₺41,66/ay',
                          savings: '%50+ TASARRUF ET',
                          isHighlighted: _selectedPlanId == 'rota_premium_12m',
                          onTap: () {
                            setState(() => _selectedPlanId = 'rota_premium_12m');
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      // 6 Months Plan
                      Expanded(
                        child: _buildPriceCard(
                          title: '6 Ay',
                          price: '₺450',
                          monthlyPrice: '₺75,00/ay',
                          isHighlighted: _selectedPlanId == 'rota_premium_6m',
                          onTap: () {
                            setState(() => _selectedPlanId = 'rota_premium_6m');
                          },
                        ),
                      ),
                    ],
                  ),
              ),
              
              const SizedBox(height: 40),
              
              // Trial Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TacticalStyles.kTertiaryContainer, TacticalStyles.kTertiary],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: TacticalStyles.kTertiary.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_loading) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lütfen ürünlerin yüklenmesini bekleyin...')),
                        );
                        return;
                      }
                      if (_products.isEmpty) {
                        setState(() => _loading = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ürünler yeniden sorgulanıyor... Lütfen bekleyin.')),
                        );
                        _loadProducts().then((_) {
                          if (mounted && _products.isEmpty) {
                            final storeName = Platform.isAndroid ? 'Google Play' : 'App Store';
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: TacticalStyles.kSurfaceLow,
                                title: const Text('Bağlantı Hatası', style: TextStyle(color: TacticalStyles.kOnSurface)),
                                content: Text('$storeName ürünleri yüklenemedi. Lütfen internet bağlantınızı kontrol edin veya $storeName hesabınızla giriş yaptığınızdan emin olun.\n\nHata: ${PremiumService.lastError}', style: const TextStyle(color: TacticalStyles.kOnSurfaceVariant)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Tamam', style: TextStyle(color: TacticalStyles.kTertiary)),
                                  ),
                                ],
                              ),
                            );
                          }
                        });
                        return;
                      }
                      
                      ProductDetails? prod;
                      for (var p in _products) {
                        if (p.id == _selectedPlanId) {
                          prod = p;
                          break;
                        }
                      }
                      if (prod == null) {
                        prod = _products.first;
                      }
                      
                      _buyProduct(prod!);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _purchasing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          '14 günlüğüne ÜCRETSİZ olarak deneyin',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontSize: 16, fontWeight: FontWeight.bold, color: TacticalStyles.kOnTertiary),
                        ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Disclaimer Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Dilediğiniz zaman iptal edebilirsiniz, yenilenen faturalandırma. Endişelenmeyin, aboneliğinizin kontrolü tamamen sizdedir. Ödeme, satın alma onayının ya da deneme döneminin (varsa) sonunda ${Platform.isAndroid ? "Google Play" : "App Store"} hesabınızdan tahsil edilir. Rota+ Premium aboneliğiniz, iptal edilmediği sürece otomatik olarak yenilenir. Aboneliğinizi yenilenme tarihinden en az 24 saat öncesine kadar iptal etmeye karar vermediğiniz sürece, mevcut dönemin bitiminden önceki 24 saat içinde hesabınızdan yenilenme ücreti alınır. Aboneliğinizi ${Platform.isAndroid ? "Google Play" : "App Store"} hesap ayarları üzerinden yönetebilirsiniz.',
                textAlign: TextAlign.start,
                style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 10.5, height: 1.4),
              ),
            ),
            
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Satın alımlar kontrol ediliyor...')),
                );
                
                try {
                  await InAppPurchase.instance.restorePurchases();
                } catch (e) {
                  debugPrint('Restore error: $e');
                }
                
                // Admin panelinden veya veritabanından verilmiş premium kontrolü
                bool isPrem = await PremiumService.isPremium();
                if (isPrem) {
                  setState(() {
                    _isPremium = true;
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Premium hesabınız başarıyla doğrulandı!', style: TextStyle(color: TacticalStyles.kTertiary))),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aktif bir premium abonelik bulunamadı.', style: TextStyle(color: TacticalStyles.kError))),
                    );
                  }
                }
              },
              child: Text('Satın Alımları Geri Yükle', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 12)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ŞİMDİ DEĞİL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard({
    required String title,
    required String price,
    required String monthlyPrice,
    String? savings,
    bool isHighlighted = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: TacticalStyles.kSurfaceLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isHighlighted ? TacticalStyles.kTertiary : TacticalStyles.kOutlineVariant, width: 2),
          boxShadow: isHighlighted ? [BoxShadow(color: TacticalStyles.kTertiary.withOpacity(0.15), blurRadius: 12)] : [],
        ),
        child: Column(
          children: [
            if (savings != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  color: TacticalStyles.kTertiaryContainer,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(11)),
                ),
                child: Text(
                  savings,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Column(
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontSize: 18, fontWeight: FontWeight.bold, color: TacticalStyles.kOnSurfaceVariant)),
                  const SizedBox(height: 10),
                  Text(price, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontSize: 24, fontWeight: FontWeight.w800, color: TacticalStyles.kOnSurface)),
                  const SizedBox(height: 4),
                  Text(monthlyPrice, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontSize: 12, color: TacticalStyles.kOnSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
