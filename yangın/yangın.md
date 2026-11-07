# ORMAN YANGINLARINI ANLIK TAKİP SİSTEMİ

## Proje Tanımı

Türkiye genelindeki orman yangınlarını ve yüksek sıcaklık kaynaklı termal anomalileri mümkün olduğunca hızlı şekilde tespit eden, harita üzerinde gösteren, tespit edilen noktanın koordinatını ve idari konumunu otomatik olarak belirleyen profesyonel bir **web tabanlı yangın erken tespit ve izleme sistemi** geliştir.

Sistem; **Copernicus Sentinel-3 / SLSTR uydu verilerini** kullanmalı, termal/fire verilerini analiz etmeli ve Türkiye haritası üzerinde aktif yangın şüpheli noktaları otomatik olarak oluşturmalıdır.

> ÖNEMLİ: Sentinel-3 SLSTR'nin gerçek sensör/bant yapısını esas al. SLSTR'de SWIR bantları S4, S5 ve S6; termal bantlar S7, S8 ve S9; aktif yangın için F1 ve F2 bantları bulunur. Termal/fire bantlarının mekânsal çözünürlüğü yaklaşık 1 km, SWIR bantlarının çözünürlüğü yaklaşık 500 m'dir.

---

# 1. ANA AMAÇ

Sistem açıldığında Türkiye haritası üzerinde uydu verilerinden elde edilen termal anomalileri gerçek veriye dayalı şekilde göstermeli.

Her uydu geçişi/veri güncellemesi sonrasında:

1. Sentinel-3 SLSTR verisini al.
2. Türkiye sınırları içerisindeki verileri filtrele.
3. Termal ve yangın bantlarını analiz et.
4. Belirlenen eşik değerini karşılayan pikselleri tespit et.
5. Tespit edilen koordinatları GeoJSON/JSON formatında oluştur.
6. Haritada aktif termal nokta olarak göster.
7. Noktanın üzerine otomatik olarak yakınlaş.
8. Latitude / longitude bilgisini hesapla.
9. OpenStreetMap/Nominatim üzerinden reverse geocoding yap.
10. İl ve ilçe bilgisini belirle.
11. Köy, belde, mahalle, mevkii gibi daha detaylı yer adlarını mümkün olduğunca Nominatim/OSM verilerinden getir.
12. HDX üzerindeki Türkiye idari sınır verilerini kullanarak il/ilçe sınırlarını kesinleştir.
13. Tüm tespitleri zaman damgasıyla kaydet.
14. Aynı yangın noktasını her uydu güncellemesinde tekrar tekrar yeni yangın olarak oluşturmamak için clustering/tracking sistemi kullan.

---

# 2. UYDU VERİ KAYNAĞI

## Ana kaynak

Copernicus Sentinel-3.

Sensör:

Sentinel-3 SLSTR — Sea and Land Surface Temperature Radiometer.

Kullanılacak veri kategorileri:

* SWIR
* MWIR/TIR
* Fire bands
* Brightness Temperature
* Radiance
* Geolocation data
* Quality flags
* Cloud masks

SLSTR bant yapısını gerçek Copernicus dokümantasyonuna göre uygula.

Özellikle:

### SWIR

* S4 ≈ 1.375 µm
* S5 ≈ 1.61 µm
* S6 ≈ 2.25 µm

### MWIR / Thermal

* S7 ≈ 3.74 µm

### Thermal IR

* S8 ≈ 10.85 µm
* S9 ≈ 12.0 µm

### Fire bands

* F1 ≈ 3.74 µm
* F2 ≈ 10.85 µm

Fire band verileri özellikle aktif yangın tespitinde öncelikli olarak değerlendirilmelidir.

---

# 3. 10 MW EŞİK DEĞERİ KONUSU

Kullanıcı arayüzünde yangın tespit eşiği:

**10 MW ve üzeri**

olarak gösterilebilir.

Ancak sensörün ham ölçümünün doğrudan "MW" olup olmadığını varsayma.

Uydu ürünündeki gerçek ölçüm parametresini ve birimini kontrol et.

Eğer ürün:

* Brightness Temperature
* Radiance
* Fire Radiative Power
* veya başka bir fiziksel ölçüm

sağlıyorsa, 10 MW eşiğini doğrudan yanlış birim üzerinde uygulama.

Sistem içerisinde açık bir dönüşüm/kalibrasyon katmanı oluştur:

```text
Satellite Raw Data
        ↓
Radiometric Processing
        ↓
Brightness Temperature / Radiance
        ↓
Fire Detection Algorithm
        ↓
Fire Radiative Power / Validated Fire Metric
        ↓
10 MW Threshold
        ↓
Active Fire Point
```

10 MW eşiği yalnızca karşılaştırılan parametrenin gerçekten MW cinsinden olması durumunda doğrudan uygulanmalıdır.

---

# 4. YANGIN TESPİT MANTIĞI

Her uydu görüntüsü için Türkiye sınırları içerisinde bulunan pikselleri analiz et.

Öncelikli analiz:

```text
F1
F2
S7
S8
SWIR S4/S5/S6
Cloud Mask
Quality Flags
```

Bir pikselin aktif yangın olarak işaretlenebilmesi için tek başına sıcaklık değerine güvenme.

Mümkün olduğunca:

* termal anomalisi,
* fire-band sinyali,
* SWIR davranışı,
* çevredeki piksellere göre sıcaklık farkı,
* cloud mask,
* veri kalite bayrakları

birlikte değerlendirilmelidir.

Örnek mantık:

```pseudo
for pixel in turkey_pixels:

    if cloud_mask(pixel) == CLOUD:
        continue

    thermal_signal = analyze_thermal(pixel)
    fire_signal = analyze_fire_band(pixel)
    swir_signal = analyze_swir(pixel)

    fire_metric = calculate_fire_metric(
        thermal_signal,
        fire_signal,
        swir_signal
    )

    if fire_metric >= 10 MW:
        create_fire_candidate(pixel)
```

---

# 5. FALSE POSITIVE FİLTRESİ

Sistem yalnızca sıcaklık yüksek diye her noktayı yangın kabul etmemeli.

Özellikle aşağıdaki kaynaklardan gelebilecek yanlış pozitifleri azalt:

* sanayi tesisleri
* enerji santralleri
* büyük fabrikalar
* havaalanları
* şehir merkezleri
* çatı/metal yüzeyler
* yoğun güneş yansıması
* bulut kenarları
* veri hataları
* uydu sensör anomalileri

Bunun için:

```text
Thermal Detection
        +
Fire Band Confirmation
        +
SWIR Confirmation
        +
Cloud Filtering
        +
Land Cover Filtering
        +
Temporal Confirmation
```

yaklaşımı kullanılmalıdır.

---

# 6. AKTİF YANGIN NOKTASI

Bir nokta eşik değerini geçtiğinde haritada:

**AKTİF YANGIN**

olarak göster.

Marker içerisinde:

* Yangın ID
* Tespit zamanı
* Latitude
* Longitude
* İl
* İlçe
* Köy / Belde / Mahalle / Mevkii
* Ölçüm değeri
* Fire metric
* Güven skoru
* Uydu
* Sensör
* Kullanılan bant
* Son güncelleme

bilgileri bulunmalı.

---

# 7. HARİTA DAVRANIŞI

Türkiye haritası ana ekranın merkezinde olmalı.

Harita:

* Türkiye sınırlarını göstermeli.
* İl sınırlarını göstermeli.
* İlçe sınırlarını göstermeli.
* Yangın noktalarını göstermeli.
* Aktif yangınları ayrı markerlarla göstermeli.
* Yangın yoğunluğunu heatmap olarak gösterebilmeli.
* Uydu görüntüsü katmanı eklenebilmeli.
* Termal katman açılıp kapatılabilmeli.
* SWIR katmanı açılıp kapatılabilmeli.
* Fire detection katmanı açılıp kapatılabilmeli.

Harita kütüphanesi olarak:

**MapLibre GL JS veya Mapbox GL JS**

kullan.

Mümkünse GeoJSON tabanlı katman mimarisi oluştur.

---

# 8. YANGIN TESPİT EDİLDİĞİNDE OTOMATİK ZOOM

Yeni bir aktif yangın tespit edildiğinde:

```text
Türkiye
   ↓
İl
   ↓
İlçe
   ↓
Yangın koordinatı
```

şeklinde otomatik zoom yapılabilmeli.

Ancak sistem her yeni veri geldiğinde haritayı zorla hareket ettirmemeli.

Bunun yerine:

* yeni yangın oluştuğunda,
* kullanıcı "Yeni Yangına Git" butonuna bastığında,
* alarm tetiklendiğinde

otomatik zoom uygulanmalı.

Örnek:

```javascript
map.flyTo({
    center: [longitude, latitude],
    zoom: 12,
    duration: 2000
});
```

---

# 9. KOORDİNAT SİSTEMİ

Tüm yangın koordinatlarını standart olarak:

**WGS84 / EPSG:4326**

formatında sakla.

Her yangın kaydında:

```json
{
  "latitude": 38.XXXX,
  "longitude": 27.XXXX
}
```

alanları bulunmalı.

Koordinat hassasiyetini sensör çözünürlüğünden daha yüksekmiş gibi gösterme.

Örneğin yaklaşık 1 km çözünürlüklü bir thermal/fire piksel için kullanıcıya gereksiz şekilde santimetre hassasiyetinde konum sunma.

Arayüzde:

**Uydu tespit konumu**

ifadesini kullan.

---

# 10. İL VE İLÇE VERİLERİ

Türkiye idari sınırları için kullanıcının verdiği HDX kaynağını kullan:

https://data.humdata.org/m/dataset/cod-ab-tur

Bu veri setini projeye dahil et.

Amaç:

* Türkiye ülke sınırı
* il sınırları
* ilçe sınırları
* idari kodlar
* geometriler

üzerinden yangın koordinatının hangi idari bölgede olduğunu belirlemek.

Öncelikli yöntem:

```text
Fire Point
      ↓
Point-in-Polygon
      ↓
Province Polygon
      ↓
District Polygon
```

Böylece il ve ilçe bilgisi sadece reverse-geocoding sonucuna bağlı kalmaz.

---

# 11. NOMINATIM / OPENSTREETMAP

Yangın koordinatı için Nominatim reverse geocoding kullan.

Endpoint:

```text
https://nominatim.openstreetmap.org/reverse
```

Örnek:

```text
/reverse?format=jsonv2&lat={LAT}&lon={LON}&zoom=18&addressdetails=1
```

Nominatim sonucundan mümkün olduğunca:

* village
* town
* municipality
* suburb
* neighbourhood
* hamlet
* city
* county
* state
* country

alanlarını değerlendir.

Özellikle:

**köy, belde, mahalle ve yerleşim adı**

için OSM/Nominatim verisini kullan.

Nominatim'in koordinattan en yakın uygun OSM nesnesini döndürdüğünü unutma. Bu nedenle sonuç kesin koordinat eşleşmesi olarak değil, reverse-geocoding sonucu olarak değerlendirilmelidir.

---

# 12. MEVKİİ VE KÜÇÜK YERLEŞİMLER

Mevkii, köy, belde ve küçük yerleşim isimleri için:

1. Nominatim
2. OpenStreetMap
3. Gerekli durumlarda Overpass API
4. HDX idari verileri

birlikte kullanılmalı.

Örneğin:

```text
İl:
İzmir

İlçe:
Menderes

Köy:
Örnekköy

Mevkii:
XXXX Mevkii
```

şeklinde mümkün olan en detaylı konum bilgisi oluştur.

Bir veri kaynağında bilgi bulunmuyorsa uydurma.

Alan:

```text
Bilinmiyor
```

olarak bırakılabilir.

---

# 13. HDX VERİSİ

HDX Türkiye COD Administrative Boundaries veri setini sistemin idari sınır katmanı için kullan.

Veri:

```text
https://data.humdata.org/m/dataset/cod-ab-tur
```

Uygulama başlangıcında gerekli sınır verilerini indirerek kendi backend/veritabanında cache'le.

Her kullanıcı isteğinde HDX'e tekrar tekrar istek gönderme.

Önerilen yapı:

```text
HDX
 ↓
Administrative Boundary Importer
 ↓
GeoJSON
 ↓
PostGIS
 ↓
Point-in-Polygon
 ↓
Province / District
```

---

# 14. VERİTABANI

PostgreSQL + PostGIS kullan.

Önerilen tablolar:

### fire_events

```text
id
external_id
satellite
sensor
detected_at
updated_at
latitude
longitude
fire_metric
brightness_temperature
confidence
status
province
district
village
locality
geometry
```

### satellite_observations

```text
id
satellite
sensor
product_id
acquisition_time
processing_time
latitude
longitude
band
value
unit
quality_flag
cloud_flag
geometry
```

### administrative_boundaries

```text
id
admin_level
name
code
geometry
source
source_date
```

---

# 15. YANGIN KÜMELEME SİSTEMİ

Aynı yangının her uydu geçişinde yeni yangın olarak gösterilmesini engelle.

Yakın koordinatları ve zamanları karşılaştır.

Örnek:

```text
Fire Candidate A
lat/lon

Fire Candidate B
lat/lon

distance < defined_radius
AND
time_difference < defined_window

→ SAME FIRE EVENT
```

Böylece:

```text
Yangın #TR-2026-0001
```

aynı olay olarak güncellenmeye devam eder.

---

# 16. YANGIN DURUMU

Her yangın:

### ACTIVE

Yeni ve doğrulanmış/kuvvetli termal sinyal.

### MONITORING

Son görüntülemede sinyal zayıflamış ancak olay takip ediliyor.

### INACTIVE

Belirlenen süre boyunca tekrar tespit edilmemiş.

### FALSE_POSITIVE

Sonradan yanlış pozitif olduğu belirlenen kayıt.

durumlarından birine sahip olabilir.

---

# 17. GERÇEK ZAMANLILIK

"Anlık" ifadesini teknik olarak yanlış kullanma.

Sentinel-3 bir gerçek zamanlı yer sensörü değildir.

Sistem:

```text
Yeni Sentinel-3 verisi
        ↓
Veri indirme
        ↓
İşleme
        ↓
Yangın analizi
        ↓
Database
        ↓
WebSocket
        ↓
Harita
```

pipeline'ı ile çalışmalıdır.

Yeni veri mevcut olduğunda sistem otomatik işleme başlatmalıdır.

---

# 18. BACKEND MİMARİSİ

Önerilen teknoloji:

```text
Python
FastAPI
PostgreSQL
PostGIS
Redis
Celery / RQ
WebSocket
GDAL
Rasterio
GeoPandas
Shapely
NumPy
```

Backend servisleri:

```text
Satellite Ingestion Service
Satellite Processing Service
Fire Detection Service
Geocoding Service
Administrative Boundary Service
Fire Clustering Service
Alert Service
API Service
WebSocket Service
```

---

# 19. FRONTEND

Modern profesyonel dashboard oluştur.

Önerilen:

```text
React
TypeScript
MapLibre GL JS
Tailwind CSS
WebSocket
```

Ana ekran:

```text
┌──────────────────────────────────────────────┐
│ ORMAN YANGINI İZLEME SİSTEMİ                │
├───────────────┬──────────────────────────────┤
│               │                              │
│ AKTİF YANGIN  │                              │
│ 27            │         TÜRKİYE HARİTASI    │
│               │                              │
│ KRİTİK  5     │          🔥                 │
│ YÜKSEK  9     │                              │
│ ORTA    13    │                              │
│               │                              │
├───────────────┴──────────────────────────────┤
│ Son uydu verisi: XX:XX                       │
│ Sentinel-3 | Son güncelleme: XX dakika önce │
└──────────────────────────────────────────────┘
```

---

# 20. YANGIN DETAY PANELİ

Kullanıcı yangın markerına tıkladığında sağ panel açılmalı.

Panel:

```text
AKTİF YANGIN

Yangın ID:
TR-2026-0001

Durum:
AKTİF

İl:
İzmir

İlçe:
Menderes

Köy / Mahalle:
XXXX

Mevkii:
XXXX

Enlem:
38.xxxxx

Boylam:
27.xxxxx

Fire Metric:
XX MW

Güven:
%XX

Uydu:
Sentinel-3

Sensör:
SLSTR

Bant:
F1 / F2 / S7 / S8

İlk Tespit:
23.08.2026 17:42

Son Tespit:
23.08.2026 18:11
```

---

# 21. GÜVEN SKORU

Her yangın için:

```text
confidence: 0-100
```

hesapla.

Örnek:

```text
Fire Band Signal       %30
Thermal Anomaly        %25
SWIR Confirmation      %20
Temporal Persistence   %15
Cloud Quality          %10
```

Toplam:

```text
0-39   DÜŞÜK
40-69  ORTA
70-84  YÜKSEK
85-100 KRİTİK
```

Bu skor örnek başlangıç modelidir. Gerçek performans testleriyle kalibre edilmelidir.

---

# 22. HARİTA KATMANLARI

Layer Control:

```text
☑ İl Sınırları
☑ İlçe Sınırları
☑ Aktif Yangınlar
☐ Pasif Yangınlar
☐ Yangın Heatmap
☐ Sentinel-3 Thermal
☐ Sentinel-3 SWIR
☐ Uydu Görüntüsü
☐ Orman Alanları
☐ Yerleşim Alanları
```

---

# 23. FİLTRELEME

Kullanıcı:

* tarih
* saat
* il
* ilçe
* yangın durumu
* güven seviyesi
* minimum fire metric
* uydu
* sensör

filtreleri kullanabilmeli.

Örneğin:

```text
İl: İzmir
Durum: ACTIVE
Güven: YÜKSEK+
Fire Metric: 10 MW+
```

---

# 24. API

Backend REST API:

```text
GET /api/fires
GET /api/fires/active
GET /api/fires/{id}
GET /api/fires/nearby
GET /api/fires/history
GET /api/fires/geojson
GET /api/administrative/provinces
GET /api/administrative/districts
GET /api/satellite/latest
GET /api/system/status
```

WebSocket:

```text
/ws/fires
```

Yeni yangın oluştuğunda:

```json
{
  "event": "NEW_FIRE",
  "fire_id": "TR-2026-0001",
  "latitude": 38.XXXX,
  "longitude": 27.XXXX,
  "province": "İzmir",
  "district": "Menderes",
  "fire_metric": 12.4,
  "confidence": 87
}
```

frontend'e gönder.

---

# 25. ALERT SİSTEMİ

Yeni yüksek güvenli yangın tespit edildiğinde:

```text
NEW FIRE
```

WebSocket eventi oluştur.

Frontend:

* sesli uyarı
* masaüstü bildirimi
* haritada animasyon
* otomatik zoom
* detay paneli

gösterebilmeli.

Bildirim spamini önlemek için aynı yangın olayına sürekli alarm gönderme.

---

# 26. PERFORMANS

Türkiye gibi geniş bir alanın uydu verisini işlerken bütün görüntüyü tarayıcıya gönderme.

İşlem:

```text
Satellite Data
      ↓
Backend
      ↓
Turkey AOI
      ↓
Raster Processing
      ↓
Fire Detection
      ↓
Vectorization
      ↓
GeoJSON / Vector Tiles
      ↓
Frontend
```

şeklinde olmalı.

Harita tarafına sadece gerekli vektör verileri gönder.

---

# 27. CACHE

Nominatim ve HDX verilerine gereksiz yoğunluk oluşturma.

Reverse geocoding sonuçlarını cache'le.

Örneğin:

```text
coordinate grid
+
geocoding result
+
timestamp
```

sakla.

Aynı koordinata tekrar tekrar Nominatim isteği gönderme.

---

# 28. VERİ KAYNAĞI ŞEFFAFLIĞI

Her yangının veri kaynağı kullanıcıya gösterilmeli.

Örneğin:

```text
Kaynak:
Copernicus Sentinel-3

Sensör:
SLSTR

Veri:
Fire / Thermal

Tespit zamanı:
23.08.2026 18:11 UTC
```

OpenStreetMap/Nominatim kullanılan konum bilgilerinde uygun OpenStreetMap attribution göster.

---

# 29. VERİ DOĞRULAMA

Sistem "kesin yangın" ifadesini yalnızca yeterli doğrulama varsa kullanmalı.

Varsayılan ifade:

**TERMAL YANGIN ADAYI**

olabilir.

Yeterli güven oluştuğunda:

**AKTİF YANGIN**

olarak sınıflandır.

Bu ayrım yanlış alarm riskini azaltır.

---

# 30. GÖRSEL TASARIM

Arayüz:

* profesyonel
* kurumsal
* karanlık tema
* operasyon merkezi görünümü
* yüksek kontrast
* sade
* hızlı
* mobil uyumlu

olmalı.

Renk mantığı:

```text
Normal       → nötr
Monitoring   → sarı
Active       → turuncu
High         → kırmızı
Critical     → koyu kırmızı
```

Markerlar dikkat çekici fakat haritayı kirletmeyecek şekilde tasarlanmalı.

---

# 31. SİSTEM DURUM PANELİ

Üst bölümde:

```text
SYSTEM ONLINE

Sentinel-3:
CONNECTED

Last Data:
18:11

Processing:
READY

Active Fires:
27

High Confidence:
12

Data Latency:
XX min
```

göster.

Eğer veri kaynağı çalışmıyorsa:

```text
SATELLITE DATA DELAY
```

uyarısı göster.

Kesinlikle eski veriyi yeni veri gibi gösterme.

---

# 32. TEST MODU

Gerçek uydu verisi bulunamadığında geliştirme için test dataset oluştur.

Örnek:

```json
{
  "latitude": 38.XXXX,
  "longitude": 27.XXXX,
  "fire_metric": 14.8,
  "confidence": 91,
  "satellite": "Sentinel-3",
  "sensor": "SLSTR"
}
```

Test markerı:

**TEST DATA**

olarak açıkça işaretlenmeli.

Gerçek veri ile test verisi kesinlikle birbirine karıştırılmamalı.

---

# 33. GÜVENLİK

API anahtarlarını frontend'e koyma.

Environment variables:

```env
SATELLITE_API_KEY=
NOMINATIM_USER_AGENT=
DATABASE_URL=
REDIS_URL=
```

kullan.

Rate limiting uygula.

API endpointlerini koru.

Log sistemi oluştur.

---

# 34. LOGGING

Her veri işleme aşamasını logla:

```text
[18:01] Sentinel-3 data received
[18:02] Turkey AOI extracted
[18:03] Thermal processing started
[18:04] 43 candidates detected
[18:05] Cloud filtering completed
[18:05] 17 valid candidates
[18:06] Clustering completed
[18:06] 9 active fire events
[18:07] Geocoding completed
[18:07] Map updated
```

---

# 35. GELİŞTİRME AŞAMALARI

## Faz 1

* Türkiye haritası
* HDX idari sınırlar
* OpenStreetMap
* Nominatim
* temel yangın marker sistemi

## Faz 2

* Sentinel-3 veri bağlantısı
* SLSTR veri işleme
* SWIR/Thermal analiz
* Fire band analizi

## Faz 3

* 10 MW fire metric threshold
* confidence score
* false positive filtering
* clustering

## Faz 4

* WebSocket
* gerçek veri güncelleme
* otomatik zoom
* alarm sistemi

## Faz 5

* geçmiş yangın analizi
* heatmap
* yangın hareket/persistence takibi
* raporlama
* istatistikler

---

# 36. ÖNEMLİ TEKNİK KURAL

Sistemi "Sentinel-3 MWIR + SWIR değerlerinden doğrudan 10 MW ölçüyor" şeklinde tasarlama.

Önce kullanılan Copernicus ürününün gerçek veri alanlarını, fiziksel birimlerini, kalite bayraklarını ve fire-related ürünlerini incele.

Ardından:

```text
RAW SATELLITE DATA
        ↓
CALIBRATION
        ↓
PHYSICAL MEASUREMENT
        ↓
FIRE DETECTION ALGORITHM
        ↓
FIRE METRIC
        ↓
10 MW THRESHOLD
```

uygula.

Bu katman özellikle zorunludur.

---

# 37. BEKLENEN SONUÇ

Ortaya çıkacak sistem:

**Türkiye'deki uydu tabanlı termal yangın adaylarını harita üzerinde otomatik tespit eden, koordinatlarını çıkaran, il/ilçe bilgilerini belirleyen, köy/belde/mevkii bilgilerini mümkün olduğunca OSM/Nominatim üzerinden zenginleştiren ve yeni uydu verileri geldikçe yangın olaylarını güncelleyen profesyonel bir operasyon dashboardu olmalıdır.**

Ana hedef:

```text
SENTINEL-3
    ↓
THERMAL / FIRE DATA
    ↓
FIRE DETECTION
    ↓
10 MW THRESHOLD
    ↓
ACTIVE FIRE CANDIDATE
    ↓
LATITUDE / LONGITUDE
    ↓
HDX ADMINISTRATIVE BOUNDARY
    ↓
PROVINCE / DISTRICT
    ↓
NOMINATIM / OSM
    ↓
VILLAGE / TOWN / LOCALITY
    ↓
POSTGIS
    ↓
WEB SOCKET
    ↓
TÜRKİYE YANGIN HARİTASI
    ↓
AUTOMATIC ZOOM + ALERT
```

Sistem tamamen **gerçek uydu verisine dayalı** çalışmalı. Demo/test verileri gerçek veriden açık şekilde ayrılmalı.

## Veri kaynakları

### Copernicus Sentinel-3 / SLSTR

Sentinel-3 SLSTR ürün ve bant dokümantasyonunu temel kaynak olarak kullan.

### OpenStreetMap / Nominatim

Reverse geocoding:

```text
https://nominatim.openstreetmap.org/reverse
```

### HDX — Türkiye COD Administrative Boundaries

```text
https://data.humdata.org/m/dataset/cod-ab-tur
```

Bu kaynak Türkiye idari sınırlarının temel veri kaynağı olarak projeye dahil edilmelidir.
