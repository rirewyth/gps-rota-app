// Supabase Ayarları
const supabaseUrl = 'https://lfudtzoxyiiysawikwyi.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxmdWR0em94eWlpeXNhd2lrd3lpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ0NzU3MzYsImV4cCI6MjEwMDA1MTczNn0.9HpTyHeeqSNJyZgwndfHDIuqKaI0HId9A2zoZNfXtq4';
const supabase = window.supabase.createClient(supabaseUrl, supabaseKey);

// Cihaz için eşsiz bir ID oluştur (Sadece ilk girişte)
let deviceId = localStorage.getItem('rota_device_id');
if (!deviceId) {
    deviceId = crypto.randomUUID ? crypto.randomUUID() : 'id-' + Math.random().toString(36).substr(2, 9);
    localStorage.setItem('rota_device_id', deviceId);
}
let username = localStorage.getItem('rota_username') || `Kullanıcı-${deviceId.substring(0, 4)}`;

// Capacitor Native Eklentileri (Arka plan ve Ekran)
document.addEventListener('DOMContentLoaded', async () => {
    if (window.Capacitor && window.Capacitor.Plugins) {
        const { KeepAwake, PushNotifications } = Capacitor.Plugins;

        // Ekranın uyku moduna geçmesini (kapanmasını) engelle
        if (KeepAwake) {
            try {
                await KeepAwake.keepAwake();
                console.log('KeepAwake Aktif: Ekran uyanık kalacak.');
            } catch (e) {
                console.error('KeepAwake desteklenmiyor veya başlatılamadı:', e);
            }
        }

        // Push Notifications (Anlık Bildirim) Başlatma
        if (PushNotifications) {
            try {
                let permStatus = await PushNotifications.checkPermissions();
                if (permStatus.receive === 'prompt') {
                    permStatus = await PushNotifications.requestPermissions();
                }
                if (permStatus.receive === 'granted') {
                    PushNotifications.register();
                }
                
                PushNotifications.addListener('registration', (token) => {
                    console.log('Push Registration Token: ', token.value);
                    // Supabase users tablosuna token eklenecek
                    supabase.from('users').update({ push_token: token.value }).eq('id', deviceId).then();
                });

                PushNotifications.addListener('pushNotificationReceived', (notification) => {
                    console.log('Yeni Bildirim:', notification);
                });
            } catch (e) {
                console.error('Push Notifications başlatılamadı:', e);
            }
        }
    }
});

// Haritayı oluştur
const map = L.map('map', {
    zoomControl: false 
});

L.control.zoom({ position: 'topleft' }).addTo(map);

// Yüksek performanslı ve detaylı altlık (OpenTopoMap)
L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
    maxZoom: 17,
    attribution: 'Map data &copy; OpenStreetMap contributors | Style &copy; OpenTopoMap'
}).addTo(map);

// ==========================================
// 1. STATİK ROTA VERİSİ (KASMA YAPMAZ)
// İleride burayı programınızdan gelen dinamik bir GPX/GeoJSON objesiyle değiştirebilirsiniz
// ==========================================
const lineCoordinates = [
    [32.250, 37.580], [32.235, 37.570], [32.220, 37.560], [32.205, 37.550], 
    [32.190, 37.545], [32.180, 37.535], [32.170, 37.540], [32.160, 37.550], 
    [32.150, 37.545], [32.145, 37.530], [32.150, 37.520], [32.160, 37.520], 
    [32.170, 37.525], [32.175, 37.510], [32.170, 37.480], [32.180, 37.445], 
    [32.175, 37.430], [32.190, 37.430], [32.190, 37.400], [32.190, 37.350]
];

const trailData = {
    "type": "Feature",
    "geometry": { "type": "LineString", "coordinates": lineCoordinates }
};

// Rotayı net görebilmek için kalın çizim
L.geoJSON(trailData, {
    style: { color: '#1c75bc', weight: 6, opacity: 0.9, lineJoin: 'round' }
}).addTo(map);

// Harita açıldığında rotaya odaklan
map.fitBounds(L.geoJSON(trailData).getBounds(), { padding: [50, 50] });

// ==========================================
// 2. YEREL İHTİYAÇ İKONLARI (Sadece Rota Çevresi)
// API kullanmadığı için anında yüklenir ve batarya dostudur
// ==========================================
function createIcon(emoji, type) {
    return L.divIcon({
        className: 'custom-div-icon',
        html: `<div class="poi-icon poi-${type}">${emoji}</div>`,
        iconSize: [28, 28],
        iconAnchor: [14, 14]
    });
}

// Önemli Lokasyonlar Dizisi
const pois = [
    { lat: 37.580, lng: 32.250, type: 'view', emoji: '📸', name: 'Başlangıç Manzarası' },
    { lat: 37.560, lng: 32.220, type: 'camp', emoji: '⛺', name: 'Evliyatekke Kampı' },
    { lat: 37.550, lng: 32.205, type: 'water', emoji: '💧', name: 'Büyük Yayla Çeşmesi' },
    { lat: 37.545, lng: 32.190, type: 'view', emoji: '📸', name: 'Vadi Seyir Terası' },
    { lat: 37.520, lng: 32.160, type: 'camp', emoji: '⛺', name: 'Sülüklü Göl Kampı' },
    { lat: 37.480, lng: 32.170, type: 'water', emoji: '💧', name: 'Ketenli Doğal Kaynak Suyu' },
    { lat: 37.430, lng: 32.175, type: 'camp', emoji: '⛺', name: 'Zoburçimen Yaylası' }
];

pois.forEach(poi => {
    L.marker([poi.lat, poi.lng], { icon: createIcon(poi.emoji, poi.type) })
        .addTo(map)
        .bindPopup(`<b>${poi.name}</b>`);
});

// ==========================================
// 3. CANLI GPS TAKİBİ (Sıfır Gecikme)
// ==========================================
let userMarker = null;
let isTracking = false; // Zoom için kontrol
const locateBtn = document.getElementById('locate-btn');

// GPS Noktası İkonu (Yanıp Sönen Mavi Nokta)
const gpsIcon = L.divIcon({
    className: 'custom-div-icon',
    html: `<div class="gps-marker-container"><div class="gps-ring"></div><div class="gps-pulse"></div></div>`,
    iconSize: [24, 24],
    iconAnchor: [12, 12]
});

// Konum başarılı şekilde haritada bulunduğunda
map.on('locationfound', async function(e) {
    if (!userMarker) {
        userMarker = L.marker(e.latlng, { icon: gpsIcon }).addTo(map);
    } else {
        userMarker.setLatLng(e.latlng); // Noktayı hareket ettir
    }
    
    // Yalnızca butona basıldığında ilk sefer haritayı oraya kaydır
    if (isTracking) {
        map.setView(e.latlng, 15, { animate: true });
        isTracking = false; 
    }
    
    locateBtn.classList.add('active');

    // Supabase'e konumu gönder (Upsert: Varsa güncelle, yoksa ekle)
    try {
        const { error } = await supabase
            .from('users')
            .upsert({
                id: deviceId,
                username: username,
                latitude: e.latlng.lat,
                longitude: e.latlng.lng,
                is_sos: false, // İleride SOS butonu eklendiğinde burası değişecek
                updated_at: new Date().toISOString()
            });
            
        if (error) {
            console.error('Konum gönderilirken hata oluştu:', error);
        } else {
            console.log('Konum başarıyla Supabase sunucusuna gönderildi.');
        }
    } catch (err) {
        console.error('Supabase bağlantı hatası:', err);
    }
});

// Konum bulmada hata oluşursa (izin reddedilirse vs.)
map.on('locationerror', function(e) {
    alert("Konumunuz bulunamadı. Lütfen cihazınızın (Telefon/Bilgisayar) konum (GPS) servisinin açık olduğundan ve tarayıcıya izin verdiğinizden emin olun.");
    locateBtn.classList.remove('active');
});

// Sağ alttaki 'Konumumu Bul' butonuna tıklama olayı
locateBtn.addEventListener('click', async () => {
    isTracking = true;
    
    // Eğer native mobil (Capacitor) çalışıyorsa ve BackgroundGeolocation varsa
    if (window.Capacitor && window.Capacitor.Plugins && Capacitor.Plugins.BackgroundGeolocation) {
        try {
            const { BackgroundGeolocation } = Capacitor.Plugins;
            
            // Arka planda konumu dinlemeye başla
            BackgroundGeolocation.addWatcher(
                {
                    backgroundMessage: "Rota arka planda izleniyor.",
                    backgroundTitle: "Rota Takibi",
                    requestPermissions: true,
                    stale: false,
                    distanceFilter: 10 // 10 metrede bir güncelle
                },
                function callback(location, error) {
                    if (error) {
                        if (error.code === "NOT_AUTHORIZED") {
                            alert("Konum izni verilmedi.");
                        }
                        return console.error(error);
                    }
                    
                    // Leaflet'in beklediği formatta bir event fırlatarak mevcut kodu tetikle
                    map.fireEvent('locationfound', {
                        latlng: L.latLng(location.latitude, location.longitude),
                        accuracy: location.accuracy
                    });
                }
            ).then(function(watcher_id) {
                console.log('Background Geolocation başlatıldı, watcher ID: ', watcher_id);
                locateBtn.classList.add('active');
            });
        } catch (e) {
            console.error('Background Geolocation hatası:', e);
            // Hata olursa standart yönteme dön
            map.locate({ setView: false, watch: true, enableHighAccuracy: true });
        }
    } else {
        // Web ortamındaysa (veya eklenti yoksa) standart HTML5 Geolocation kullan
        map.locate({ setView: false, watch: true, enableHighAccuracy: true });
    }
});
