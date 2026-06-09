import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum LegalType { terms, privacy }

class LegalScreen extends StatelessWidget {
  final LegalType type;
  const LegalScreen({Key? key, required this.type}) : super(key: key);

  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kBackground = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    final String title = type == LegalType.terms ? 'Kullanım Koşulları' : 'Gizlilik Politikası';
    final String content = type == LegalType.terms ? _termsText : _privacyText;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kOrange, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Son Güncelleme: 28 Nisan 2026',
              style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Text(
              content,
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  static const String _termsText = '''
1. Giriş
Rota+ uygulamasına hoş geldiniz. Bu uygulama, dağcılık ve doğa sporları ile uğraşan kullanıcılar için dağcılık, trekking ve deprem anında acil durum yönetimi için tasarlanmıştır. Uygulamayı kullanarak bu koşulları kabul etmiş sayılırsınız.

2. Kritik Uyarı ve Feragatname
Rota+, resmi acil servislerin yerini tutmaz. Hayati tehlike durumunda öncelikle yerel acil servislerini (örn: 112) aramalısınız. Uygulamanın sunduğu konum takibi ve radar özellikleri teknolojik imkânlara ve sinyal gücüne bağlıdır; bu özelliklerin her zaman kusursuz çalışacağı garanti edilemez. Doğa sporları doğası gereği risk taşır ve uygulamanın kullanımı bu riskleri ortadan kaldırmaz. Kullanıcı, uygulamayı kullanırken tüm sorumluluğun kendisine ait olduğunu kabul eder.

3. Kullanım Lisansı
Uygulama üzerinden sunulan içerikler ve yazılım Rota+'ya aittir. Ticari olmayan, kişisel kullanımınız için kısıtlı bir kullanım hakkı verilmektedir.

4. Sorumluluk Sınırlandırması
Uygulamanın kullanımından kaynaklanabilecek fiziksel yaralanma, mal kaybı veya diğer zararlardan Rota+ geliştiricileri ve ortakları sorumlu tutulamaz. Verilerin (konum, mesaj vb.) iletilememesi durumunda doğabilecek aksaklıklardan Rota+ sorumlu değildir.

5. Kullanıcı Yükümlülükleri
Kullanıcı, uygulamayı yasalara uygun ve etik çerçevede kullanacağını taahhüt eder. Diğer kullanıcıları taciz etmek veya sistemi manipüle etmek yasaktır.

6. Değişiklikler
Rota+, bu kullanım koşullarını dilediği zaman güncelleme hakkını saklı tutar. Değişiklikler uygulama üzerinden bildirilecektir.
''';

  static const String _privacyText = '''
1. Veri Toplama ve İzinler
Rota+, size navigasyon ve konum hizmetleri sunabilmek için aşağıdaki verileri toplar ve izinleri kullanır:
- Konum Verileri: Radar ve canlı takip için hassas konumunuz (arka planda dahil) toplanır.
- Kamera Erişimi: AR Pusula özelliği ile yönlendirme bilgilerini görüntülemek ve rehberlik sertifikası yükleme işlemleri için kullanılır. Görüntüler kaydedilmez.
- Mikrofon: Sesli aktivasyon ve walkie-talkie özellikleri için kullanılır. Ses kaydı saklanmaz.
- SMS İzni: İnternet bağlantısı olmayan bölgelerde konum bilgilerini irtibat kişisine iletmek için isteğe bağlı olarak kullanılabilir.

2. Verilerin Kullanımı
Toplanan veriler sadece uygulamanın temel fonksiyonlarını yerine getirmek için kullanılır:
- Konumunuz, ekip arkadaşlarınızın sizi bulması için paylaşılır.
- Kamera görüntüsü anlık olarak AR işlemleri için kullanılır, sunucularımıza gönderilmez.
- Verileriniz asla üçüncü taraflara reklam amaçlı satılmaz veya paylaşılmaz.

3. Veri Güvenliği
Verileriniz güvenli sunucularda şifrelenmiş (TLS/SSL) olarak saklanır. Profil bilgileriniz ve tıbbi bilgileriniz (isteğe bağlı) sadece size ve irtibat kişinize paylaşılır.

4. Kullanıcı Hakları
Kullanıcılar, istedikleri zaman hesaplarını ve verilerini silme hakkına sahiptir. Uygulama içinden Profil → Ayarlar → Hesabı Sil adımlarını izleyerek tüm verilerinizi kalıcı olarak silebilirsiniz.

5. İletişim
Gizlilik politikamızla ilgili sorularınız için destek@rotaplus.app adresinden bize ulaşabilirsiniz.
''';
}
