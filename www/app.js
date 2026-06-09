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
map.on('locationfound', function(e) {
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
});

// Konum bulmada hata oluşursa (izin reddedilirse vs.)
map.on('locationerror', function(e) {
    alert("Konumunuz bulunamadı. Lütfen cihazınızın (Telefon/Bilgisayar) konum (GPS) servisinin açık olduğundan ve tarayıcıya izin verdiğinizden emin olun.");
    locateBtn.classList.remove('active');
});

// Sağ alttaki 'Konumumu Bul' butonuna tıklama olayı
locateBtn.addEventListener('click', () => {
    isTracking = true;
    // watch: true ile harita açık kaldığı sürece konumu arka planda dinlemeye başlar
    map.locate({ setView: false, watch: true, enableHighAccuracy: true });
});
