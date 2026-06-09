Bir dağcılık ve acil durum güvenlik mobil uygulaması geliştirmek istiyorum. Bu uygulama, internetin olmadığı, çok zorlu doğa koşullarında çalışacak şekilde tasarlanmalıdır. Sistemde iki rol var: "Dağcı" (sahada olan) ve "Gözlemci" (evde bekleyen).

Aşağıdaki mimariyi ve özellikleri kurmam için bana adım adım kodlama rehberi, sistem mimarisi ve gerekli kütüphaneleri (paketleri) sun.

# TEMEL ÖZELLİKLER VE MANTIK:

1. Çevrimdışı GPS Takibi (Offline Tracking):
- Uygulama, internet olmasa bile cihazın dahili GPS sensörünü kullanarak dağcının konumunu (enlem/boylam ve rakım) düzenli aralıklarla almalı.
- Alınan bu rota noktaları telefonun yerel veritabanına (SQLite/Room/CoreData) kaydedilmeli. Pil tasarrufu için konum alma sıklığı optimize edilmeli.

2. Gözlemci ile Rota Paylaşımı:
- Dağcı tırmanışa başlamadan önce (interneti varken), planladığı rotayı ve Gözlemci'nin telefon numarasını uygulamaya girmeli.

3. Acil Durum (SOS) Butonu ve SMS Mekanizması (Kritik Özellik):
- Ekranda büyük bir SOS butonu olacak.
- Dağcı buna bastığında uygulama şu bilgileri içeren bir SMS metni derleyecek: 
  "ACİL DURUM! Dağcı yardıma ihtiyaç duyuyor. Planlanan Rota: [Rota Adı]. Son Bilinen Konum: Enlem [X], Boylam [Y]. Google Maps Linki: [Offline oluşturulmuş link]."
- İNTERNETSİZ ÇALIŞMA MANTIĞI: SMS gönderimi uygulamanın içinden, kullanıcıyı SMS uygulamasına atmadan arka planda (Direct SMS API) yapılmalı. 
- EN ZOR KOŞUL ALGORİTMASI: Eğer SOS'e basıldığında hücresel ağ (şebeke) hiç yoksa, uygulama "Pending SMS" (Bekleyen Mesaj) durumuna geçmeli. Arka planda bir servis çalışarak hücresel şebekeyi dinlemeli. Cihaz dağda en ufak bir sinyal yakaladığı an (1 diş bile çekse) bu SMS'i otomatik olarak Gözlemci'ye fırlatmalı.

# TEKNİK GEREKSİNİMLER:
- Hedeflenen Platform: (Buraya uygulamanın yapılacağı dili girilecek örn: Flutter / React Native / Native Android-Kotlin)
- Arka plan işlemleri (Background Tasks & Location Services) telefon uyku modundayken bile çalışmaya devam etmeli ve işletim sistemi tarafından kapatılmasını önleyecek izinler (WakeLock, Foreground Service vb.) ayarlanmalı.

Lütfen bana bu uygulamanın temel yapısını kurmak için:
1. Hangi izinlerin (Permissions) gerektiğini,
2. Hangi kütüphanelerin (Location, SQLite, Background Service, Direct SMS) kullanılacağını,
3. SOS butonuna basıldığında çalışan "Sinyal bekleyen arka plan SMS algoritmasının" kod taslağını yaz.
Bir dağcılık ve acil durum güvenlik mobil uygulaması geliştirmek istiyorum. Bu uygulama, internetin olmadığı zorlu doğa koşullarında çalışacak şekilde tasarlanmalıdır. Geliştirme için Google'ın Flutter altyapısını ve haritalandırma için topografik verileri (örn. Mapbox veya eşdeğer bir sistem) kullanacağız. Sistemde iki rol var: "Dağcı" (sahada olan) ve "Gözlemci" (evde bekleyen).

Aşağıdaki mimariyi ve özellikleri kurmam için bana adım adım Flutter kodlama rehberi, sistem mimarisi ve gerekli pub.dev paketlerini sun.

# TEMEL ÖZELLİKLER VE MANTIK:

1. Çevrimdışı GPS Takibi (Offline Tracking):
- Uygulama, internet olmasa bile cihazın dahili GPS sensörünü kullanarak dağcının konumunu (enlem/boylam ve rakım) düzenli aralıklarla almalı ve yerel veritabanına (SQLite/Isar) kaydetmeli.

2. Acil Durum (SOS) Butonu ve İnternetsiz SMS Mekanizması:
- Dağcı SOS butonuna bastığında sistem mevcut konumu ve rotayı içeren bir SMS derleyecek.
- Eğer o an şebeke yoksa, uygulama "Pending SMS" durumuna geçecek. Arka planda bir servis çalışarak hücresel şebekeyi dinleyecek ve cihaz 1 diş bile sinyal yakalasa bu SMS'i otomatik olarak Gözlemci'ye gönderecek (Direct SMS API ile arka planda).

3. Akıllı Rota Tahmini ve Olası Yönelim Analizi (KRİTİK ÖZELLİK):
- SOS tuşuna basıldığı an, sistem sadece o anki konumu değil, dağcının "bundan sonra nereye gidebileceğini" de analiz etmeli.
- Uygulama cihazdaki çevrimdışı topografik harita verisini kullanarak, SOS noktasının etrafındaki;
  a) En yakın iniş rotalarını (eğim verisine göre),
  b) Bilinen en yakın sığınak/kamp alanlarını,
  c) Çevredeki patika yollarını veya su yataklarını (vadi içleri) hesaplamalı.
- Gönderilen SMS'te: "Son Konum: [Koordinat]. Olası İlerleme Yönleri: [Kuzeydeki X patikası veya Y vadisi yönüne hareket etme ihtimali yüksek]" şeklinde bir algoritma çıktısı da yer almalı. Gözlemci bu veriyi haritada açtığında SOS noktasından çıkan "olasılık vektörlerini" görebilmeli.

# TEKNİK GEREKSİNİMLER:
- Hedeflenen Platform: Flutter (Dart).
- Arka plan işlemleri telefon uyku modundayken bile çalışmaya devam etmeli (flutter_background_service, workmanager).
- Akıllı Rota Tahmini için cihazda önceden indirilmiş (offline) harita/vektör verisinin nasıl işleneceği algoritmik olarak açıklanmalı.

Lütfen bana bu uygulamanın temel yapısını kurmak için:
1. Flutter'da hangi native izinlerin (Permissions) gerektiğini,
2. Hangi kütüphanelerin (Location, SQLite, Background Service, Map/Routing) kullanılacağını,
3. "Olası Rota Tahmini" algoritmasının mantığını ve SOS anında şebeke bekleyen arka plan SMS kod taslağını yaz.
Triggering a new build...
