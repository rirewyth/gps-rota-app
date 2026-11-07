# ROTA+ NEXUS — Taktik Afet & Operasyon Komuta Merkezi

**ROTA+ NEXUS**, saha ekiplerini, dağcıları ve kullanıcıları gerçek zamanlı izleyen, detaylı topografik arazi haritasına sahip, kritik SOS çağrılarında otomatik alarm veren ve arama kurtarma koordinasyonu sağlayan merkezi komuta merkezidir.

---

## 🚀 Hızlı Başlatma

Uygulama arka planda hazır ve çalışıyor:
* **Yerel Adres:** [http://localhost:5174/](http://localhost:5174/)
* **Ağ Adresi:** `http://192.168.1.15:5174/`

Dilediğiniz zaman klasör içerisindeki `start.bat` dosyasına çift tıklayarak da komuta merkezini başlatabilirsiniz.

---

## 🌟 Temel Yetenekler & Özellikler

### 1. Detaylı Arazi ve Topografik Harita (Terrain Focus)
Harita üzerinden sağ üstteki mod seçiciyle anında geçiş yapabilirsiniz:
- 🏔️ **ESRI Topo & Arazi:** Yükseklik gölgelendirmeleri, vadi kıvrımları, nehir yatakları ve dağ sırtları.
- ⛰️ **OpenTopoMap:** Yüksek detaylı izolips eğrileri (kontur çizgileri), irtifa rakamları ve yürüyüş patikaları.
- 🛰️ **Uydu & Arazi Hibrit:** Yüksek çözünürlüklü uydu fotoğrafları + yol/tepe etiketleri.
- ⬛ **Taktik Karanlık:** Gece operasyonları için göz yormayan askeri HUD görünümü.
- ⭕ **Taktik Menzil Halkaları:** 1 km ve 3 km mesafe daireleri.
- 〰️ **İz / Rota Takibi:** Ekiplerin arazide katettiği patika izleri (breadcrumb trail).

### 2. Canlı Veritabanı Entegrasyonu (Firebase Firestore)
- Proje: `rotaplus-cd84d`
- Koleksiyon: `users`
- Gerçek zamanlı `onSnapshot` dinleyicisi ile kullanıcıların GPS konumu (`lat`, `lng`), rakımı (`altitude`), şarj durumu (`battery`), hızı ve SOS bayrağı (`sos` / `is_sos`) canlı çekilir.
- Veritabanı çevrimdışı veya boş olduğunda otomatik olarak 6 adet gerçekçi saha ekibi (Uludağ, Kaçkarlar, Toroslar, AFAD, UMKE Sağlık, Termal İHA) aktif devriye moduna geçer.

### 3. Ekip Canlı Haritası
- Ekiplerin anlık yönelimleri ve rolleri:
  - ⛑️ **SAR:** Dağ Arama Kurtarma Timleri (Turkuaz)
  - 🩺 **MED:** Taktik Sağlık Ekipleri (Zümrüt Yeşil)
  - 🛸 **İHA:** Termal Keşif Droneları (Mor - Hızlı devriye)
  - 🧗‍♂️ **KULLANICI:** Sahadaki sivil / dağcı kullanıcılar
- Anlık batarya göstergesi, irtifa sayacı ve telsiz kanalı bilgisi.

### 4. Kritik SOS Alarmı ve Komuta Merkezi Yönetimi
Bir kullanıcı SOS butonuna bastığında:
1. **Sesli Siren:** Web Audio API ile donanımsal çift tonlu taktik siren çalar (üst bardan tek tıkla sessize alınabilir).
2. **Kırmızı Acil Durum Paneli:** Sağ üstte yanıp sönen kritik uyarı penceresi açılır.
3. **Kamerayı Kilitle:** Tek tıkla harita hedefin 1.5 km yakınına yumuşak animasyonla kilitlenir.
4. **En Yakın SAR Ekibini Sevk Et:** En yakın arama kurtarma timine doğrudan intikal rotası çizer ve intikal durumuna geçirir.
5. **Hava Ambulansı / Helikopter:** Hava tahliye çağrısı kaydı açar.
6. **Çözüldü:** Durumu normale döndürür, sireni susturur ve operasyon günlüğüne işler.
7. **Test SOS Butonu:** Üst barda bulunan `TEST SOS BAŞLAT/DURDUR` butonu ile tüm alarm akışını canlı deneyimleyebilirsiniz.

---

## 📂 Klasör Yapısı

```
ROTA+ NEXUS/
├── src/
│   ├── components/
│   │   ├── Header.jsx           # Üst taktik kontrol ve saat/sayaç barı
│   │   ├── TacticalMap.jsx      # Detaylı arazi, topoğrafya ve ekip haritası
│   │   ├── OperationsPanel.jsx   # Sol telemetri, ekip listesi ve canlı log akışı
│   │   ├── SosAlertBanner.jsx    # Sağ üst kırmızı acil SOS ve sevk paneli
│   │   └── TeamCard.jsx          # Tıklanan birimin detaylı telemetri kartı
│   ├── audio.js                 # Web Audio API taktik siren ve telsiz ses motoru
│   ├── firebase.js              # rotaplus-cd84d Firestore gerçek zamanlı veri katmanı
│   ├── App.jsx                  # Komuta merkezi ana yöneticisi ve hareket simülasyonu
│   ├── index.css                # Taktik CRT tarama çizgileri ve Leaflet stilleri
│   └── main.jsx
├── start.bat                    # Tek tıkla çalıştırma betiği
├── vite.config.js               # Port 5174 yapılandırması
├── package.json
└── index.html
```
