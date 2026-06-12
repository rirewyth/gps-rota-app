import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({Key? key}) : super(key: key);

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class StepData {
  final String question;
  final String? instruction;
  final List<OptionData> options;
  final IconData icon;
  final Color color;
  final String? imagePath;

  StepData({
    required this.question,
    this.instruction,
    required this.options,
    this.icon = Icons.help_outline,
    this.color = const Color(0xFFFF6B00),
    this.imagePath,
  });
}

class OptionData {
  final String label;
  final String? nextStepKey;
  final bool isFinal;
  final String? finalAdvice;
  final String? finalAdviceImage;

  OptionData({
    required this.label,
    this.nextStepKey,
    this.isFinal = false,
    this.finalAdvice,
    this.finalAdviceImage,
  });
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kCardBg = Color(0xFF141414);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kGreen = Color(0xFF62FF4C);

  String _currentStepKey = 'start';
  final List<String> _history = [];

  final Map<String, StepData> _steps = {
    'start': StepData(
      question: 'ACİL DURUM TİPİNİ SEÇİN',
      instruction: 'Lütfen hastanın en belirgin şikayetini seçin.',
      icon: Icons.emergency,
      options: [
        OptionData(label: 'KANAMALAR, KIRIKLAR VE ÇIKIKLAR', nextStepKey: 'trauma'),
        OptionData(label: 'ÇEVRESEL (HİPOTERMİ / DONMA / SICAK ÇARPMASI)', nextStepKey: 'environmental'),
        OptionData(label: 'YÜKSEK İRTİFA HASTALIKLARI', nextStepKey: 'altitude'),
        OptionData(label: 'BİLİNÇ KAYBI / DİĞER', nextStepKey: 'medical'),
      ],
    ),
    'trauma': StepData(
      question: 'YARALANMA TİPİ NEDİR?',
      icon: Icons.healing,
      color: Colors.redAccent,
      options: [
        OptionData(label: 'KANAMA', nextStepKey: 'bleeding_type'),
        OptionData(label: 'KIRIK / ÇIKIK ŞÜPHESİ', nextStepKey: 'fracture'),
      ],
    ),
    'bleeding_type': StepData(
      question: 'KANAMA TÜRÜNÜ TANIMLAYIN',
      icon: Icons.bloodtype,
      color: Colors.red,
      imagePath: 'assets/guides/basi_noktalari_guide.jpg',
      options: [
        OptionData(label: 'NABIZ ATIŞI İLE UYUMLU FIŞKIRIR ŞEKİLDE', nextStepKey: 'bleeding_pressure'),
        OptionData(label: 'SIZINTI ŞEKLİNDE KOYU KIRMIZI RENKTE', nextStepKey: 'bleeding_pressure'),
        OptionData(label: 'KILCAL İNCE (BURUN KANAMASI) / MORARMA İLE', isFinal: true, finalAdvice: 'Kılcal kanamalar ve morarmalar hafiftir. Temiz tutup hafif baskı uygulayın. Gerekirse buz kompresi yapın.'),
      ],
    ),
    'bleeding_pressure': StepData(
      question: 'KANAMA BASI NOKTASINDA MI?',
      icon: Icons.touch_app,
      color: Colors.redAccent,
      options: [
        OptionData(label: 'EVET (Bası Noktasında)', isFinal: true, finalAdvice: 'DİREK TURNİKE UYGULAMASI!\n\nKemer gibi malzemeler hariç, tshirtten yapacağınız bir uzun bez/bandanayı bası noktasının olduğu damarın üstüne düğüm atarak sıkın. Turnike saatinizi kişinin alnına yazın ve 15 dakikada 1 güncelleyin.'),
        OptionData(label: 'HAYIR (Bası Noktasından Uzakta)', isFinal: true, finalAdvice: 'BEZ PROSEDÜRÜ UYGULAYIN!\n\nKanama noktasına bir bez örtün. Durmazsa üçüncü bez üst üste gelene kadar tekrarlayın. Yine durmazsa dördüncü bezle sarıp düğüm atın, durmuyorsa çubukla sıkın. Acil yardım gelene kadar çıkarmayın.'),
      ],
    ),
    'fracture': StepData(
      question: 'AÇIK YARA VEYA KEMİK GÖRÜNÜMÜ VAR MI?',
      icon: Icons.medical_services,
      color: Colors.orange,
      options: [
        OptionData(label: 'EVET', isFinal: true, finalAdvice: 'Bölgeyi atel ile eklem noktasından sabitleyin. Yaralının atellediğiniz noktasını hareket ettirmeden taşıma işlemini gerçekleştirin.'),
        OptionData(label: 'HAYIR', isFinal: true, finalAdvice: 'Bölgeyi mevcut malzemelerle (dal, mat, baton) atelleyin. Hareket ettirmeyin. Buz uygulayın.'),
      ],
    ),
    'environmental': StepData(
      question: 'ANA BELİRTİ NEDİR?',
      icon: Icons.ac_unit,
      color: Colors.blueAccent,
      options: [
        OptionData(label: 'ŞİDDETLİ TİTREME / UYUŞUKLUK', nextStepKey: 'hypothermia'),
        OptionData(label: 'DOKUDA HİS KAYBI / BEYAZLAMA', nextStepKey: 'frostbite'),
        OptionData(label: 'SICAK ÇARPMASI', isFinal: true, finalAdvice: 'HİPERTERMİ YÖNETİMİ\n\nYaralı sıcaktan aşırı seviyede etkilendi ve yürüyecek hali yok ise yaralıyı güneşten uzak havadar bir alana alın koltuk altlarını, ayak uçlarını yükselterek, alnına, koltuk altına ve ayak uçlarına serin veya soğuk malzemeler (soğuk su, ıslak bez olabilir) koyun.'),
      ],
    ),
    'hypothermia': StepData(
      question: 'HASTA BİLİNÇLİ Mİ?',
      icon: Icons.psychology,
      color: Colors.cyan,
      options: [
        OptionData(label: 'EVET', isFinal: true, finalAdvice: 'Islak giysileri çıkarın. Kuru battaniyeye sarın. Ilık şekerli su verin. Masaj yapmayın!'),
        OptionData(label: 'HAYIR', isFinal: true, finalAdvice: 'Hava yolunu açık tutun. Isı kaybını önleyin. Derhal acil tahliye çağırın. Şekerli sıvı vermeyin!'),
      ],
    ),
    'frostbite': StepData(
      question: 'DONMA ŞİDDETİ',
      icon: Icons.ac_unit,
      color: Colors.lightBlue,
      options: [
        OptionData(label: 'YÜZEYSEL', isFinal: true, finalAdvice: 'Paniğe kapılmayın, vücut ısınızı yükseltin. Üstünüze bir katman daha alın ve alabiliyorsanız yanınızdakilerden acil durum battaniyesi ile sizi örtmesini isteyin.'),
        OptionData(label: 'MORARMA / DERİN (SİYAHLAŞMA)', isFinal: true, finalAdvice: 'Derhal 112 arayın ve acil yardım alın.'),
      ],
    ),
    'altitude': StepData(
      question: 'İRTİFA HASTALIĞI ŞÜPHESİ (ADH, HİBE, HİAO)',
      icon: Icons.terrain,
      color: Colors.amber,
      options: [
        OptionData(label: 'İLKYARDIM PROTOKOLÜNÜ GÖSTER', isFinal: true, finalAdviceImage: 'assets/guides/altitude_guide.png', finalAdvice: 'ADH(Akut Dağ Hastalığı), HİBE(Yüksek İrtifa Beyin Ödemi) ve HİAO(Yüksek İrtifa Akciğer Ödemi) hastalıklarının tespiti durumunda Dağcılığın Aklimatizasyon kuralına uygun hareket edin.\n\nEkibinizden herhangi biri bu hastalıklardan birine yakalandı ise üyeyi yalnız bırakmayın. Tırmanış sırasında gerçekleşti ise kişiyi belirtiler azalana kadar dinlendirin, dinlenmesine rağmen süreç geçmiyor ise ana kamp alanına kadar yaralıya eşlik edin.\n\nHİAO ve HİBE görülmesi durumunda ana kamp alanında hastalığın geçmediği tespit edilirse 112\'yi arayınız, genellikle bu hastalıkların tedavisi irtifa kaybetmektir.'),
      ],
    ),
    'medical': StepData(
      question: 'YARALININ BİLİNCİ YERİNDE Mİ?\n(Uyarana cevap veriyor mu?)',
      icon: Icons.psychology_alt,
      color: Colors.purple,
      options: [
        OptionData(label: 'EVET', nextStepKey: 'medical_breathing'),
        OptionData(label: 'HAYIR', nextStepKey: 'medical_cpr'),
      ],
    ),
    'medical_breathing': StepData(
      question: 'SOLUNUM VAR MI?',
      icon: Icons.air,
      color: Colors.purpleAccent,
      options: [
        OptionData(label: 'EVET', isFinal: true, finalAdvice: 'ŞOK POZİSYONU VERİN!\n\nBu pozisyonu vermek için yaralının yattığı alan altına mat veya zemini düzeltecek materyal koyun sonrasında hasta/yaralının ayağını yerden 30 cm yükseltmek maksadı ile ayak bileğinin altına sırt çantanızı veya hasta/yaralının ayağını yerden yükseltecek bastığında bozulmayacak materyaller koyun.'),
        OptionData(label: 'HAYIR', nextStepKey: 'medical_cpr'),
      ],
    ),
    'medical_cpr': StepData(
      question: 'UYGULAMA YAPILDI MI?',
      instruction: 'Derhal 112’yi arayınız ve 112 gelene kadar hastayı düz bir zemine sırtüstü yatırıp hastaya 30 bası ve 2 suni teneffüs yapınız. Her 30 bası 2 suni teneffüs döngüsü sonrası solunum ve bilinç durumunu kontrol ediniz.',
      icon: Icons.favorite,
      color: Colors.red,
      options: [
        OptionData(label: 'EVET', nextStepKey: 'medical'),
      ],
    ),
  };

  void _onOptionSelected(OptionData option) {
    if (option.isFinal) {
      _showResult(option.finalAdvice!, imagePath: option.finalAdviceImage);
    } else {
      setState(() {
        _history.add(_currentStepKey);
        _currentStepKey = option.nextStepKey!;
      });
    }
  }

  void _goBack() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentStepKey = _history.removeLast();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _showResult(String advice, {String? imagePath}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, color: kGreen, size: 48),
            const SizedBox(height: 16),
            Text(
              'UYGULAMA PROTOKOLÜ',
              style: GoogleFonts.shareTechMono(color: kGreen, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(imagePath, fit: BoxFit.contain, height: 200),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              advice,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kOrange,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _currentStepKey = 'start';
                  _history.clear();
                });
              },
              child: const Text('TAMAM', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStepKey]!;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        title: Text('TEMEL İLKYARDIM PROTOKOLLERİ', style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.0)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kOrange),
          onPressed: _goBack,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: step.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: step.color.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(step.icon, color: step.color, size: 50),
                ),
              ),
              const SizedBox(height: 32),
              FadeIn(
                duration: const Duration(milliseconds: 500),
                key: ValueKey(_currentStepKey),
                child: Column(
                  children: [
                    Text(
                      step.question,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    if (step.imagePath != null) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(step.imagePath!, fit: BoxFit.contain, height: 200),
                      ),
                    ],
                    if (step.instruction != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        step.instruction!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),
              ...step.options.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: InkWell(
                    onTap: () => _onOptionSelected(opt),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              opt.label,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: kOrange, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
