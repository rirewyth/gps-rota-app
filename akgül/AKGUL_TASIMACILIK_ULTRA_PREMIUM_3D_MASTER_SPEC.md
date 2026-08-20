# AKGÜL TAŞIMACILIK — ULTRA PREMIUM 3D WEBSITE MASTER SPEC

Antigravity için hazırlanmış bu doküman, klasik nakliyat sitesi değil; ultra gerçekçi 3D asansörlü nakliye kamyonunun ziyaretçi scroll ettikçe hareket ettiği interaktif bir marka deneyimi üretmek içindir.

MARKA
- Ad: AKGÜL TAŞIMACILIK
- Ana hizmet: Evden eve taşımacılık
- Öne çıkan uzmanlık: Asansörlü evden eve taşımacılık
- Telefon: 0536 431 76 87
- WhatsApp: https://wa.me/905364317687
- Ana CTA: WHATSAPP'TAN TEKLİF AL
- İkincil CTA: 0536 431 76 87

ANA FİKİR
Site açıldığında kullanıcı büyük, ultra gerçekçi, reklam filmi kalitesinde bir nakliye kamyonu görür. Aşağı kaydırdıkça:
1. Kamyon çalışır.
2. Kamera etrafında sinematik şekilde dolaşır.
3. Kamyon şehir içinde ilerler.
4. Bina önünde durur.
5. Mobil asansör sistemi açılır.
6. Hidrolik destekler çıkar.
7. Teleskopik mekanizma yükselir.
8. Platform üst kata yaklaşır.
9. Koli/mobilya platformla taşınır.
10. Asansör kapanır.
11. Kamyon yola çıkar.
12. Yeni adrese ulaşır.
13. Final CTA'da WhatsApp'a yönlendirilir.

Bu hikâye sitenin ana omurgasıdır. 3D kamyon dekorasyon değil, sitenin ana karakteridir.


# 01 — GÖRSEL DİL VE ART DIRECTION

Estetik: premium automotive commercial + modern logistics technology + cinematic architecture.

Kesinlikle:
- çizgi film
- low-poly
- oyuncak kamyon
- düz ikon ağırlığı
- hazır nakliyat template'i
- stok fotoğrafla dolu sayfa
- aynı kartların tekrarlandığı SaaS tasarımı
- aşırı gradient
kullanılmayacak.

Hedef: kullanıcı bunun 3D olduğunu ancak yakından anlayabilsin. İlk bakışta gerçek bir otomotiv reklamı hissi vermeli.

Renkler:
#08090B / #111316 / #1B1E22 / #F5F5F2 / #FF6A00 / #FF8A24

Turuncu yalnızca CTA, aktif durum, mekanizma vurguları, ışık ve marka detaylarında kullanılmalı.

Tipografi:
Inter / Manrope / Plus Jakarta Sans / Space Grotesk.
Başlıklar büyük, güçlü, kısa.

Örnek hero:
EVİNİZİ
GÜVENLE
TAŞIYORUZ.

Alt:
Asansörlü evden eve taşımacılıkta profesyonel çözüm.

CTA:
[ WHATSAPP'TAN TEKLİF AL ] [ 0536 431 76 87 ]


# 02 — ULTRA GERÇEKÇİ 3D KAMYON

Kamyon basit geometrilerden oluşmayacak.

Kabin:
- gerçekçi metal boya
- cam yansımaları
- ön ızgara
- tampon
- far
- sinyal
- ayna
- kapı kolu
- panel aralıkları
- gerçekçi lastik ve jant

Kasa:
- metal paneller
- kapak ve menteşeler
- bağlantı noktaları
- hafif kullanım izleri
- fiziksel olarak doğru roughness

Asansör:
- hidrolik pistonlar
- teleskopik raylar
- platform
- destek ayakları
- güvenlik bariyerleri
- mekanik bağlantılar
- hortum/kablo detayları
- gerçekçi hareket oranları

Materyaller PBR olmalı:
base color, roughness, metallic, normal, AO.

3D model mümkünse GLB/GLTF.
Three.js veya React Three Fiber.
GSAP + ScrollTrigger ile scroll progress kamera ve mekanik animasyonlara bağlanmalı.

Asset prompt:
"Ultra photorealistic modern household moving box truck, realistic commercial vehicle proportions, detailed cab, glass, rubber tires, metal panels, premium subtle orange accents, mounted hydraulic furniture moving elevator, telescopic hydraulic lift, stabilizer legs, realistic platform, physically based materials, automotive commercial photography quality, cinematic reflections, realistic imperfections, high detail, no cartoon, no low poly, no toy appearance."

Kamyon üzerinde AKGÜL TAŞIMACILIK yazısı bulunabilir.


# 03 — HERO VE İLK 3 SANİYE

Tam ekran hero: 100svh.
Karanlık asfalt/şehir atmosferi.
Kamyon 3/4 açıyla kadrajda.
Hafif çevre yansıması.
Farlar çok hafif açık.
Kamera yavaşça yaklaşır.

Sol/üst metin:
TAŞINMAK
ARTIK DAHA
KOLAY.

Alt açıklama:
Evden eve ve asansörlü taşımacılık için profesyonel çözüm.

CTA her zaman erişilebilir:
WHATSAPP'TAN TEKLİF AL

Alt:
AŞAĞI KAYDIR

İlk scroll:
kamera yaklaşır, kamyon hafif hareket eder.
İkinci:
kamera yana geçer.
Üçüncü:
arka açı.
Sonra asansör mekanizması görünür.


# 04 — SCROLL STORY / 10 SİNEMATİK SAHNE

SAHNE 01 — PLANLAMA
Başlık: HER TAŞINMA İYİ BİR PLANLA BAŞLAR.
Arka planda kamyon bekler. Minimal operasyon HUD'ı: EV / KAT / EŞYA / TAŞIMA PLANI. Demo verileri gerçek müşteri bilgisi gibi gösterilmez.

SAHNE 02 — YOLA ÇIKIŞ
Kamyon çalışır ve şehir atmosferinde ilerler.
Başlık: YOLA ÇIKIYORUZ.
Kamera road-level tracking shot.

SAHNE 03 — VARIŞ
Kamyon bina önünde durur.
Fren ışıkları ve hafif süspansiyon hareketi.
Başlık: YÜKSEK KATLAR İŞİ ZORLAŞTIRMASIN.

SAHNE 04 — ASANSÖRÜN KURULMASI
Destek ayakları çıkar.
Hidrolik mekanizma açılır.
Teleskopik kollar sırayla uzar.
Platform hizalanır.
Bu bölüm signature moment.

SAHNE 05 — YÜKSELİŞ
Platform bina seviyesine yükselir.
Kamera platformu takip eder.
Balkon/pencere hedefi vurgulanır.

SAHNE 06 — EŞYA TAŞIMA
Koli, koltuk, masa veya beyaz eşya gibi gerçekçi 3D objeler platforma gelir.
Platform yukarı taşır.
Aşırı kalabalık olmaz.

SAHNE 07 — KAMYON KASASI
Kamera kasanın içine girer.
Düzenli koliler, mobilyalar ve sabitleme kayışları görülür.
Başlık: HER ŞEYİN YERİ BELLİ.

SAHNE 08 — YOLCULUK
Kamyon şehir yolunda ilerler.
Ön/yan/arka kamera.
Başlık: YENİ ADRESE DOĞRU.

SAHNE 09 — YENİ EV
Kamyon yeni binaya gelir.
Asansör yeniden açılır.
Eşyalar yukarı taşınır.

SAHNE 10 — TAMAMLANDI
Asansör kapanır, destekler toplanır.
Başlık: TAŞINMA TAMAMLANDI.
Alt: Sıradaki adresiniz için hazırız.


# 05 — HİZMETLERİ FOTOĞRAFSIZ, ANİMASYONLA ANLAT

Her hizmet klasik kart olmayacak. Büyük yatay sahneler kullanılacak.

01 EVDEN EVE TAŞIMACILIK
3D ev + kamyon + hareketli rota.
Başlık: EVİNİZDEN YENİ YUVANIZA.

02 ASANSÖRLÜ TAŞIMACILIK
Kamyon asansörü tam açılır.
Başlık: YÜKSEK KATLAR İÇİN AKILLI ÇÖZÜM.
Alt: ASANSÖRLÜ TAŞIMACILIK.

03 ŞEHİR İÇİ TAŞIMACILIK
Minimal şehir haritası ve hareket eden kamyon.

04 ŞEHİRLER ARASI TAŞIMACILIK
Yalnızca firma gerçekten sunuyorsa yayınla.
Türkiye haritasında animasyonlu rota.

Ek hizmetler — paketleme, montaj/demontaj, depolama, sigortalı taşıma vb. sadece firma doğrularsa gerçek hizmet olarak eklenmeli. Doğrulanmamış hiçbir hizmeti kesin gerçek gibi yazma.


# 06 — ASANSÖRLÜ TAŞIMACILIK SİGNATURE EXPERIENCE

Bu bölüm sitenin en güçlü satış sahnesi.

Kamera kamyonun arkasında.
Asansör mekanizması kapalı.
Scroll başladığında:
- destek ayakları açılır
- hidrolik pistonlar devreye girer
- teleskopik bölümler çıkar
- platform yukarı yükselir
- bina cephesine yaklaşır
- hedef balkon/pencere vurgulanır

Kullanıcı scroll'u durdurduğunda kamyon + bina + asansör aynı sinematik kadrajda kalır.

Başlık:
YÜKSEK KATLAR
ARTIK ENGEL DEĞİL.

Alt:
Asansörlü taşımacılık

CTA:
BİLGİ AL

Fizik hissi çok önemli. Asansör tek parça çubuk gibi uzamayacak. Mekanik parçalar birbirleriyle uyumlu hareket edecek.


# 07 — HİZMET SÜRECİ

Beş adım:
01 İLETİŞİME GEÇİN
02 TAŞINMA İHTİYACINIZI BELİRLEYELİM
03 TAŞIMA PLANINI OLUŞTURALIM
04 EŞYALARINIZI TAŞIYALIM
05 YENİ ADRESİNİZE ULAŞTIRALIM

Her adım scroll ile bir sonraki 3D sahneye bağlanmalı.

Klasik timeline yerine:
kamyonun hareket yolu + numaralar + kamera geçişleri kullanılabilir.


# 08 — TEKLİF / WHATSAPP DÖNÜŞÜMÜ

WhatsApp sitenin ana conversion noktasıdır.

Bağlantı:
https://wa.me/905364317687

Önceden hazırlanmış mesaj:
"Merhaba, AKGÜL TAŞIMACILIK'tan evden eve / asansörlü taşımacılık hakkında bilgi ve teklif almak istiyorum."

Butonlar:
- WHATSAPP'TAN TEKLİF AL
- HEMEN WHATSAPP'TAN YAZ
- TAŞINMANIZI KONUŞALIM

Mobilde alt sabit bar:
[ WHATSAPP ] [ ARA ]

Desktop sağ altta floating WhatsApp.

Telefon:
0536 431 76 87

Telefon linki:
tel:+905364317687


# 09 — AKILLI TEKLİF FORMU

Form kısa tutulmalı:
Nereden? İl / İlçe
Nereye? İl / İlçe
Ev tipi? 1+1 / 2+1 / 3+1 / 4+1 / Diğer
Kat?
Asansör? Var / Yok / Bilmiyorum
Taşınma tarihi?
Ad Soyad
Telefon

CTA:
WHATSAPP'TAN TEKLİF İSTE

Form gönderildiğinde WhatsApp mesajı hazırlanabilir.
Gerçek fiyat hesaplanıyormuş gibi sahte hesaplama yapılmamalı.

Görsel feedback:
3+1 seçilirse kamyon kasasında birkaç koli belirir.
Yüksek kat seçilirse asansör mekanizması hafifçe görünür.
Bunlar sadece UI feedback'tir.


# 10 — NAVIGATION / HEADER / FOOTER

Desktop header:
AKGÜL TAŞIMACILIK
Hizmetler
Asansörlü Taşıma
Nasıl Çalışır?
Hakkımızda
İletişim
[ WhatsApp'tan Teklif Al ]

Scroll sonrası header küçülür.

Mobil hamburger:
01 Hizmetler
02 Asansörlü Taşıma
03 Süreç
04 Hakkımızda
05 İletişim
0536 431 76 87
WhatsApp

Footer:
AKGÜL TAŞIMACILIK
Taşınma sürecinizi daha kolay hale getirmek için buradayız.
Hizmetler / İletişim / WhatsApp
0536 431 76 87
KVKK / Gizlilik / Çerezler.


# 11 — GÜVEN, SEO VE İÇERİK

Ton:
Profesyonel, net, güven veren, abartısız.

Kullanma:
- sahte müşteri sayısı
- sahte yorum
- sahte yıldız
- sahte ödül
- sahte sertifika
- sahte deneyim yılı
- sahte filo sayısı
- doğrulanmamış sigorta iddiası
- doğrulanmamış şehir sayısı
- "Türkiye'nin 1 numarası" gibi kanıtsız ifadeler.

SEO niyetleri:
İzmir evden eve nakliyat
İzmir asansörlü nakliyat
İzmir asansörlü ev taşıma
İzmir ev taşıma
İzmir taşımacılık
evden eve taşımacılık İzmir
asansörlü taşımacılık İzmir
Akgül Taşımacılık

Title:
Akgül Taşımacılık | İzmir Evden Eve & Asansörlü Taşımacılık

Description:
Akgül Taşımacılık ile evden eve ve asansörlü taşımacılık hizmetleri hakkında bilgi alın. Taşınma süreciniz için WhatsApp üzerinden hızlıca iletişime geçin.

LocalBusiness/MovingCompany schema yalnızca doğrulanmış firma bilgileriyle kurulmalı.


# 12 — FAQ

Sorular:
Asansörlü taşımacılık nedir?
Asansörlü taşıma hangi durumlarda tercih edilir?
Taşınma öncesinde neler hazırlanmalıdır?
Teklif almak için ne yapmalıyım?
İzmir içinde taşımacılık nasıl planlanır?
Şehirler arası taşıma yapılıyor mu?

Son soru ve ilgili hizmet yalnızca firma tarafından doğrulanırsa yayınlanmalı.

Accordion:
ikon rotation + içerik fade + smooth height animation.


# 13 — TEKNİK MİMARİ

Önerilen stack:
React
React Three Fiber
Three.js
Drei
GSAP
ScrollTrigger

Component:
App
Header
Hero
TruckScene
TruckCamera
ElevatorMechanism
BuildingScene
MovingProcess
ServiceStory
QuoteForm
Contact
Footer
FloatingWhatsApp

3D:
Truck
Elevator
Building
Camera
Materials
Lighting

Animations:
heroTimeline
truckTimeline
elevatorTimeline
scrollStory

Data:
services
contact

Önerilen dosya yapısı:
src/components/
src/three/
src/animations/
src/data/
public/models/
public/textures/

Model GLB/GLTF.
LOD:
Desktop high quality
Tablet medium
Mobile optimized

WebGL yoksa video/poster fallback.
prefers-reduced-motion desteklenmeli.


# 14 — KAMERA VE IŞIK

Kamera dili otomotiv reklamı gibi:
35mm / 50mm lens hissi.
Dolly, orbit, crane, tracking, low angle, overhead ve close-up.

Hero:
low 3/4 front.

Scroll:
front → side → rear → elevator.

Final:
wide cinematic.

Lighting:
soft cinematic key
çok düşük fill
hafif turuncu rim
şehir/environment reflections

Metal yüzeylerde kontrollü reflection.
Her şey aşırı parlak CGI gibi görünmeyecek.


# 15 — MOBİL

Mobil masaüstünün küçültülmüş hali olmayacak.

Kamyon ekranın yaklaşık %55–65'ini kaplayabilir.
Başlıklar 2–4 satır.
CTA geniş ve thumb-friendly.
Alt sabit bar:
WHATSAPP | ARA

Mobil asansör sahnesinde kamera kamyon + asansör + balkon yakın planına geçsin.

Performans için mobile LOD model ve düşük texture kullanılmalı.


# 16 — MİKRO ETKİLEŞİMLER

Hover:
hafif scale + ışık.

WhatsApp:
subtle pulse.

Navigation:
animated underline.

Buttons:
150–350ms.

Normal reveal:
500–800ms.

Büyük 3D:
1–2.5s.

Animasyon easing:
GSAP power2 / power3 / expo.

Ses varsayılan kapalı.
İstenirse Sound On:
çok hafif motor, hidrolik ve şehir ambience.
Otomatik ses başlatma yok.


# 17 — LOADING

İlk yükleme:
siyah ekran.
Ortada AKGÜL TAŞIMACILIK.
Alt:
LOADING VEHICLE EXPERIENCE
Progress 00–100.

3D yüklenirken wireframe kamyon.
Yükleme bitince wireframe → gerçek materyal.
Farlar açılır ve hero'ya geçilir.

Loading gereksiz uzun tutulmamalı.


# 18 — FINAL CTA / BRAND STATEMENT

Son sahnede kamyon uzakta görünür.
Kamera yavaşça yaklaşır.
Kamyonun farları açılır.

Büyük:
SİZ YERLEŞİN.
GERİSİNİ BİZE BIRAKIN.

Alt:
AKGÜL TAŞIMACILIK
0536 431 76 87

[ WHATSAPP'TAN TEKLİF AL ]

Alternatif sloganlar:
TAŞINMAK ARTIK DAHA KOLAY.
EVİNİZİ GÜVENLE TAŞIYORUZ.
YÜKÜNÜZÜ HAFİFLETİYORUZ.
YENİ ADRESİNİZE, GÜVENLE.
TAŞINMANIN PROFESYONEL HALİ.


# 19 — ANTIGRAVITY İÇİN ÇALIŞMA EMRİ

Bu projeyi basit landing page olarak ele alma.

Bu bir:
INTERACTIVE 3D BRAND EXPERIENCE.

Ana interaction:
SCROLL → CAMERA → TRUCK → ELEVATOR → MOVING STORY

Ana conversion:
WHATSAPP

Ana telefon:
0536 431 76 87

Ana hizmet:
ASANSÖRLÜ EVDEN EVE TAŞIMACILIK

Önce kod yazma.
Önce:
1. site architecture
2. component architecture
3. animation architecture
4. 3D asset strategy
5. responsive strategy
6. SEO structure
çıkar.

Sonra uygulamaya geç.

Kullanıcı aşağı kaydırdıkça kamyonun hikâyesini izlemeli.
Her scroll chapter kamyonun bir sonraki fiziksel hareketine bağlanmalı.
Fiyatlandırma bölümü oluşturma.
Sahte şirket verisi oluşturma.
Doğrulanmamış hizmetleri gerçekmiş gibi sunma.
WhatsApp ve telefon CTA'sını görünür tut.


# 20 — BAŞARI KRİTERİ

İlk 3 saniye:
"Bu sıradan bir nakliyat sitesi değil."

İlk 10 saniye:
"Kamyon gerçekten hareket ediyor."

Asansör sahnesi:
"Bunu nasıl yaptılar?"

Final:
"Teklif almak istiyorum."

Site çok uzun olabilir; uzunluk boş metinle değil, gerçek 3D sahneler, scroll storytelling, hizmet deneyimleri, süreç, teklif alanı ve güçlü içerikle oluşturulmalı.

Son deneyim:
Kamyonu gör.
Aşağı kaydır.
Kamyon hareket etsin.
Binaya ulaş.
Asansör kurulsun.
Platform yükselsin.
Eşyalar taşınsın.
Kamyon yola çıksın.
Yeni adrese gelsin.
Final:
SİZ YERLEŞİN. GERİSİNİ BİZE BIRAKIN.

AKGÜL TAŞIMACILIK
0536 431 76 87
WHATSAPP'TAN TEKLİF AL


# 21 — GERÇEK FİRMA BİLGİSİ / DOĞRULAMA NOTU

Bu briefte kullanıcı tarafından verilen telefon numarası 0536 431 76 87 ana iletişim olarak kullanılmalıdır.

Yerel işletme kaydında Akgül Evden Eve Asansörlü Taşımacılık için aynı telefon numarası ve İzmir/Bornova konumu görülebilmektedir. Bununla birlikte web üzerinde aynı/benzer Akgül isimli işletmeler için farklı telefon ve adres kayıtları da bulunabildiğinden, web sitesine adres, çalışma saatleri, kuruluş yılı, sigorta, araç filosu, hizmet verilen şehirler ve sertifikalar gibi bilgiler yalnızca firma tarafından doğrulandıktan sonra eklenmelidir.

Web sitesinin amacı gerçek olmayan kurumsal iddialar üretmek değil, doğrulanmış hizmeti premium bir dijital deneyime dönüştürmektir.

# 22 — SON TALİMAT

ANTIGRAVITY, BU DOSYAYI BİR TASARIM FİKRİ OLARAK DEĞİL, UYGULANABİLİR ÜRÜN SPECIFICATION OLARAK ELE AL.

Ana karakter = ultra gerçekçi asansörlü nakliye kamyonu.
Ana hareket = scroll kontrollü sinematik 3D animasyon.
Ana hikâye = planlama → yola çıkış → varış → asansör → taşıma → yeni adres.
Ana satış noktası = asansörlü evden eve taşımacılık.
Ana iletişim = WhatsApp + 0536 431 76 87.
Ana tasarım ilkesi = fotoğraf yerine mümkün olduğunca özel animasyon ve 3D sahne.
Ana kalite standardı = premium otomotiv reklamı.

Kullanıcı siteyi gezdiğinde sadece bilgi okumamalı; taşınma operasyonunu görsel olarak deneyimlemeli.
