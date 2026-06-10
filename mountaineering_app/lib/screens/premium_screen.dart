import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io' show Platform;
import '../services/premium_service.dart';

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
              backgroundColor: Colors.white,
              title: const Text('İşlem Tamamlanamadı'),
              content: const Text('Satın alma işlemi başarısız oldu veya iptal edildi.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tamam', style: TextStyle(color: Colors.green)),
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
            backgroundColor: Colors.white,
            title: const Text('Satın Alma Başarısız'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tamam', style: TextStyle(color: Colors.green)),
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
    const Color kGreen = Color(0xFF62FF4C);
    const Color kDarkBg = Color(0xFF0A0A0A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
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
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.1,
              ),
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
                            color: _features[i]['color'].withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_features[i]['icon'], size: 60, color: _features[i]['color']),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _features[i]['title'],
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _features[i]['desc'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
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
                    color: _currentPage == index ? kGreen : Colors.grey.shade300,
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
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Siz bir ROTA+ Premium üyesisiniz. Tüm ayrıcalıklı özelliklerin keyfini çıkarın.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 14),
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
                  ? const CircularProgressIndicator()
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
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade400],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
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
                        final storeName = Platform.isAndroid ? 'Google Play' : 'App Store';
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: const Text('Bağlantı Hatası'),
                            content: Text('$storeName ürünleri yüklenemedi. Lütfen internet bağlantınızı kontrol edin veya $storeName hesabınızla giriş yaptığınızdan emin olun.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Tamam', style: TextStyle(color: Colors.green)),
                              ),
                            ],
                          ),
                        );
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5, height: 1.4),
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
                      const SnackBar(content: Text('Premium hesabınız başarıyla doğrulandı!', style: TextStyle(color: Colors.green))),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aktif bir premium abonelik bulunamadı.', style: TextStyle(color: Colors.red))),
                    );
                  }
                }
              },
              child: const Text('Satın Alımları Geri Yükle', style: TextStyle(color: Colors.black45, fontSize: 12)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ŞİMDİ DEĞİL', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isHighlighted ? const Color(0xFF62FF4C) : Colors.grey.shade200, width: 2),
          boxShadow: isHighlighted ? [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10)] : [],
        ),
        child: Column(
          children: [
            if (savings != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF43A047),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
                ),
                child: Text(
                  savings,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Column(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 10),
                  Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(monthlyPrice, style: const TextStyle(fontSize: 12, color: Colors.black38)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
