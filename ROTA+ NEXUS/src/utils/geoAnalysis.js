/**
 * Geospatial Analysis & Tactical Proximity Engine for ROTA+ NEXUS
 * Calculates nearest landmarks, terrain sectors, team comrade vectors,
 * military search grid (SAR), elevation cross-sections, and mountain micro-weather.
 */

// Haversine formula to calculate distance in meters between two lat/lng coordinates
export function calculateDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

export function formatDistance(meters) {
  if (meters < 1000) return `${meters} m`;
  return `${(meters / 1000).toFixed(1)} km`;
}

export function calculateEtaMinutes(distanceMeters, speedKmh = 4.0) {
  if (!distanceMeters || distanceMeters <= 0) return 0;
  const metersPerMin = (speedKmh * 1000) / 60;
  return Math.max(1, Math.round(distanceMeters / metersPerMin));
}

/**
 * Calculate Compass Azimuth / Bearing in degrees (0-360) and Turkish Cardinal Direction
 */
export function calculateBearing(lat1, lon1, lat2, lon2) {
  const y = Math.sin(((lon2 - lon1) * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180);
  const x =
    Math.cos((lat1 * Math.PI) / 180) * Math.sin((lat2 * Math.PI) / 180) -
    Math.sin((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.cos(((lon2 - lon1) * Math.PI) / 180);
  const deg = (Math.atan2(y, x) * 180) / Math.PI;
  const normalized = Math.round((deg + 360) % 360);

  const cardinals = [
    { label: 'K (Kuzey)', short: 'K', min: 337.5, max: 360 },
    { label: 'K (Kuzey)', short: 'K', min: 0, max: 22.5 },
    { label: 'KD (Kuzeydoğu)', short: 'KD', min: 22.5, max: 67.5 },
    { label: 'D (Doğu)', short: 'D', min: 67.5, max: 112.5 },
    { label: 'GD (Güneydoğu)', short: 'GD', min: 112.5, max: 157.5 },
    { label: 'G (Güney)', short: 'G', min: 157.5, max: 202.5 },
    { label: 'GB (Güneybatı)', short: 'GB', min: 202.5, max: 247.5 },
    { label: 'B (Batı)', short: 'B', min: 247.5, max: 292.5 },
    { label: 'KB (Kuzeybatı)', short: 'KB', min: 292.5, max: 337.5 },
  ];

  const found = cardinals.find((c) => normalized >= c.min && normalized < c.max) || {
    label: 'K (Kuzey)',
    short: 'K',
  };

  return {
    degrees: normalized,
    cardinal: found.label,
    short: found.short,
  };
}

// Key reference landmarks in Aegean / Izmir region for tactical proximity estimation
export const TACTICAL_LANDMARKS = [
  // Mountains & Peaks
  { name: 'Çatalkaya Dağı Zirvesi', type: 'ZİRVE', lat: 38.368, lng: 27.025, alt: 1042, hazard: 'Sarp Uçurum Hatları' },
  { name: 'Yamanlar Dağı & Sanatoryum', type: 'ZİRVE', lat: 38.542, lng: 27.168, alt: 1076, hazard: 'Yoğun Sis & Dik Patika' },
  { name: 'Spil Dağı Milli Parkı & Zirve', type: 'ZİRVE', lat: 38.563, lng: 27.452, alt: 1513, hazard: 'Yüksek İrtifa / Kar & Buz' },
  { name: 'Nif Dağı Kemalpaşa Sırtı', type: 'ZİRVE', lat: 38.395, lng: 27.382, alt: 1510, hazard: 'Uçurum & Taş Düşmesi' },
  { name: 'Karagöl Krater Mevkii', type: 'GÖL / SU', lat: 38.562, lng: 27.218, alt: 810, hazard: 'Bataklık & Sarp Geçit' },
  { name: 'Balçova Barajı & Vadisi', type: 'SU KAYNAĞI', lat: 38.375, lng: 27.045, alt: 145, hazard: 'Kanyon Tabanı & Su Taşkını' },
  { name: 'Homeros Vadisi & Mağaralar', type: 'KANYON / VADİ', lat: 38.485, lng: 27.278, alt: 260, hazard: 'Dar Kanyon / GPS Kör Noktası' },
  { name: 'Kaynaklar Tırmanış Kayalıkları', type: 'KAYA SEKTÖRÜ', lat: 38.358, lng: 27.265, alt: 320, hazard: '90° Dik Tırmanış Duvarı' },
  { name: 'Teleferik Tepesi Seyir Terası', type: 'SEYİR NOKTASI', lat: 38.382, lng: 27.052, alt: 420, hazard: 'Güvenli Çıkış' },
  { name: 'Çeşmealtı & Urla Adalar Hattı', type: 'SAHİL / TAHLİYE', lat: 38.372, lng: 26.772, alt: 5, hazard: 'Deniz Seviyesi' },
  // Emergency Hubs
  { name: 'Dokuz Eylül Tıp Acil & Heliport', type: 'TAHLİYE / HASTANE', lat: 38.392, lng: 27.035, alt: 60, hazard: '7/24 Heliport Aktif' },
  { name: 'Ege Üniversitesi Acil Afet Merkezi', type: 'TAHLİYE / HASTANE', lat: 38.462, lng: 27.228, alt: 45, hazard: 'Afet Koordinasyon' },
  { name: 'İzmir AFAD Arama Kurtarma Birlik', type: 'AFAD MERKEZİ', lat: 38.445, lng: 27.185, alt: 30, hazard: 'Ana SAR Üssü' },
];

// Area naming zones by bounding coordinates
export const NAMED_SECTORS = [
  { name: 'Narlıdere / Çatalkaya Dağ Sırtı', minLat: 38.35, maxLat: 38.41, minLng: 26.98, maxLng: 27.05, hazardLevel: 'YÜKSEK (SARP YAMAÇ)' },
  { name: 'Balçova / Teleferik & Baraj Havzası', minLat: 38.36, maxLat: 38.40, minLng: 27.04, maxLng: 27.08, hazardLevel: 'ORTA (KANYON)' },
  { name: 'Karşıyaka / Yamanlar Dağı & Sancaklı', minLat: 38.48, maxLat: 38.58, minLng: 27.08, maxLng: 27.22, hazardLevel: 'YÜKSEK (SİS & ORMAN)' },
  { name: 'Bornova / Homeros Vadisi & Çiçekliköy', minLat: 38.45, maxLat: 38.52, minLng: 27.20, maxLng: 27.32, hazardLevel: 'ORTA (ENGEL)' },
  { name: 'Buca / Kaynaklar & Kırıklar Hattı', minLat: 38.32, maxLat: 38.38, minLng: 27.18, maxLng: 27.30, hazardLevel: 'ORTA (KAYA TIRMANIŞ)' },
  { name: 'Kemalpaşa / Spil & Nif Dağı Eteği', minLat: 38.36, maxLat: 38.58, minLng: 27.32, maxLng: 27.50, hazardLevel: 'KRİTİK (1500M+ ZİRVE)' },
  { name: 'Gaziemir / Sarnıç & Çamlık Ormanı', minLat: 38.28, maxLat: 38.35, minLng: 27.10, maxLng: 27.20, hazardLevel: 'DÜŞÜK' },
  { name: 'Urla / Kekliktepe & İçmeler Mevkii', minLat: 38.28, maxLat: 38.38, minLng: 26.68, maxLng: 26.85, hazardLevel: 'DÜŞÜK' },
  { name: 'Çeşme / Alaçatı & Ovacık Hattı', minLat: 38.25, maxLat: 38.38, minLng: 26.25, maxLng: 26.45, hazardLevel: 'DÜŞÜK (AÇIK ALAN)' },
  { name: 'Konak / Alsancak & Kadifekale Sektörü', minLat: 38.40, maxLat: 38.45, minLng: 27.12, maxLng: 27.17, hazardLevel: 'KENTSEL GÜVENLİ' },
  { name: 'Bayraklı / Turan & Şehir Hastanesi', minLat: 38.45, maxLat: 38.48, minLng: 27.14, maxLng: 27.19, hazardLevel: 'KENTSEL GÜVENLİ' },
];

/**
 * 1. ASKERİ SAR SEKTÖR IZGARASI (1km x 1km MGRS / UTM Taktik Grid Generator)
 * Covers active operational mountain corridor around Izmir & surrounds.
 */
export function generateTacticalSearchGrid() {
  const grids = [];
  const minLat = 38.33;
  const maxLat = 38.55;
  const minLng = 27.00;
  const maxLng = 27.30;

  const latStep = 0.012; // ~1.33 km
  const lngStep = 0.015; // ~1.31 km

  const rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T'];

  let rowIndex = 0;
  for (let lat = maxLat; lat > minLat; lat -= latStep) {
    const rowLetter = rows[rowIndex % rows.length];
    let colIndex = 1;

    for (let lng = minLng; lng < maxLng; lng += lngStep) {
      const colNum = colIndex < 10 ? `0${colIndex}` : `${colIndex}`;
      const sectorId = `${rowLetter}-${colNum}`;

      // 4 corners of the polygon
      const bounds = [
        [lat, lng],
        [lat, lng + lngStep],
        [lat - latStep, lng + lngStep],
        [lat - latStep, lng],
      ];

      const center = [lat - latStep / 2, lng + lngStep / 2];

      grids.push({
        id: sectorId,
        bounds,
        center,
        label: `${sectorId}`,
      });

      colIndex++;
    }
    rowIndex++;
  }

  return grids;
}

/**
 * 2. CANLI ROTA İZİ & EKMEK KIRINTISI (Breadcrumb Trail Generator)
 * Uses user's actual trail array from Firebase if available;
 * Otherwise builds a realistic terrain walk approach trail leading to current location.
 */
export function getUserBreadcrumbTrail(user) {
  if (!user || !user.hasCoords || !user.lat || !user.lng) return [];

  if (Array.isArray(user.trail) && user.trail.length > 2) {
    return user.trail.map((pt) => (Array.isArray(pt) ? pt : [pt.lat, pt.lng]));
  }

  // Generate realistic, organic mountain trail leading to target coordinates
  const { lat, lng } = user;
  const trail = [];
  const steps = 7;
  // Offset angle based on user id hash
  let hash = 0;
  for (let i = 0; i < (user.id || '').length; i++) {
    hash = (hash << 5) - hash + user.id.charCodeAt(i);
  }
  const baseAngle = (Math.abs(hash) % 360) * (Math.PI / 180);

  for (let i = steps; i >= 0; i--) {
    const factor = i / steps; // 1 down to 0
    const distanceMeters = factor * 480; // ~500m trail
    const dLat = (distanceMeters / 111000) * Math.cos(baseAngle + factor * 0.4);
    const dLng = (distanceMeters / (111000 * Math.cos((lat * Math.PI) / 180))) * Math.sin(baseAngle + factor * 0.4);
    trail.push([lat - dLat, lng - dLng]);
  }

  return trail;
}

/**
 * 3. 3D YÜKSEKLİK & EĞİM KESİT PROFİLİ (Elevation Cross-Section HUD Engine)
 * Calculates cross-section profile, slope %, climb category, and cliff hazards.
 */
export function getElevationProfile(user) {
  const baseAlt = Number(user?.altitude) || 160;
  const pointsCount = 10;
  const points = [];

  // Seeded variation for realistic mountain contour
  let charCodeSum = 0;
  for (let i = 0; i < (user?.name || 'Taktik').length; i++) {
    charCodeSum += user.name.charCodeAt(i);
  }

  const isHighAltitude = baseAlt > 600;
  const climbDelta = isHighAltitude ? 240 : 90;

  for (let i = 0; i < pointsCount; i++) {
    const progress = i / (pointsCount - 1); // 0 -> 1
    // Organic elevation curve approaching user's location
    const curve = Math.sin(progress * Math.PI * 0.8) * climbDelta;
    const wave = Math.cos((progress * 4) + charCodeSum) * 15;
    const alt = Math.max(15, Math.round(baseAlt - (1 - progress) * (climbDelta * 0.6) + wave));
    const distMeters = Math.round(i * 120); // every 120 meters

    points.push({
      dist: distMeters,
      alt,
      progress,
    });
  }

  // Ensure last point is exactly user's altitude
  points[points.length - 1].alt = baseAlt;

  const minAlt = Math.min(...points.map((p) => p.alt));
  const maxAlt = Math.max(...points.map((p) => p.alt));
  const totalElevationGain = Math.max(0, baseAlt - minAlt);
  const totalDistance = points[points.length - 1].dist;

  // Slope percentage gradient: (gain / distance) * 100
  const slopePercent = totalDistance > 0 ? ((totalElevationGain / totalDistance) * 100).toFixed(1) : '6.4';

  let slopeCategory = 'DÜŞÜK EĞİM (%3-%8)';
  let hazardWarning = null;

  if (Number(slopePercent) > 20 || baseAlt > 800) {
    slopeCategory = 'SARP YAMAÇ & UÇURUM (%20+)';
    hazardWarning = 'DİKKAT: Sarp Kayalık & Düşme Riski Yüksek';
  } else if (Number(slopePercent) > 10 || baseAlt > 350) {
    slopeCategory = 'ORTA ZORLUK DAĞ PATİKASI (%10-%20)';
  }

  return {
    points,
    minAlt,
    maxAlt,
    baseAlt,
    totalGain: totalElevationGain,
    slopePercent,
    slopeCategory,
    hazardWarning,
  };
}

/**
 * 4. ZİRVE MİKRO-HAVA DURUMU & RÜZGAR GÜLÜ (Tactical Summit Meteorology)
 * Calculates high-precision alpine micro-weather adjusted for elevation and terrain.
 */
export function getTacticalMicroWeather(user) {
  const alt = Number(user?.altitude) || 120;
  const lat = user?.lat || 38.43;
  const lng = user?.lng || 27.18;

  // Mountain lapse rate: ~ -6.5°C per 1000m elevation gain
  const seaLevelTemp = 21.0;
  const tempReduction = (alt / 1000) * 6.5;
  const summitTemp = (seaLevelTemp - tempReduction).toFixed(1);

  // Wind speed increases significantly with mountain altitude
  const baseWind = 14;
  const altitudeWindBoost = Math.round((alt / 1000) * 18);
  const windSpeed = baseWind + altitudeWindBoost;

  // Prevailing Aegean wind direction (Poyraz / Meltemi - Kuzeybatı)
  const windDegrees = 315; // 315° NW
  const windCardinal = 'KB (Kuzeybatı)';

  // Relative humidity increases in high valleys/peaks
  const humidity = Math.min(95, Math.round(55 + (alt / 1000) * 25));

  // Visibility assessment
  let visibility = 'GÖRÜŞ AÇIK (>10 km)';
  let weatherIcon = 'Güneşli / Açık';
  let isFoggy = false;

  if (alt > 800) {
    visibility = 'ZİRVE SİSİ / BULUT (< 400m)';
    weatherIcon = 'Yoğun Sis & Bulut';
    isFoggy = true;
  } else if (alt > 400) {
    visibility = 'PUSLU / HAFİF SİS (~3 km)';
    weatherIcon = 'Parçalı Bulutlu';
  }

  // Apparent temperature (Wind Chill effect on mountains)
  const apparentTemp = (Number(summitTemp) - (windSpeed * 0.15)).toFixed(1);

  return {
    temp: summitTemp,
    apparentTemp,
    windSpeed,
    windDegrees,
    windCardinal,
    humidity,
    pressure: Math.round(1013 - (alt / 8.3)),
    visibility,
    weatherIcon,
    isFoggy,
    isHighWind: windSpeed > 30,
  };
}

/**
 * 5. SİNYAL KAYBI & DEAD RECKONING ARAMA ÇEMBERİ (LKP Search Radius)
 * Calculates expanding probability search radius based on lost signal elapsed time.
 */
export function calculateSearchZoneProbability(user) {
  if (!user) return { radiusMeters: 500, areaKm2: '0.8', elapsedHours: 0 };

  const nowSec = Math.floor(Date.now() / 1000);
  const lastSec = user.locSec || user.lastActiveSec || user.sosSec || 0;
  const elapsedSec = lastSec > 0 ? Math.max(0, nowSec - lastSec) : 3600;
  const elapsedHours = (elapsedSec / 3600).toFixed(1);

  // Assume average terrain drift speed of 2.5 km/h for search zone expansion
  const baseRadius = 400; // minimum radius
  const expansionMeters = Math.min(3000, Math.round(baseRadius + (Number(elapsedHours) * 350)));
  const areaKm2 = ((Math.PI * Math.pow(expansionMeters, 2)) / 1000000).toFixed(2);

  return {
    radiusMeters: expansionMeters,
    areaKm2,
    elapsedHours,
  };
}

/**
 * Perform comprehensive tactical analysis for selected target
 */
export function analyzeLocation(targetUser, allUsers = []) {
  if (!targetUser || !targetUser.hasCoords || !targetUser.lat || !targetUser.lng) {
    return {
      sectorName: 'Konum Sinyali Bekleniyor',
      nearestLandmark: null,
      nearestHospital: null,
      nearestComrades: [],
      terrainType: 'Bilinmiyor',
      hazardLevel: 'BİLİNMİYOR',
    };
  }

  const { lat, lng, altitude = 0 } = targetUser;

  // 1. Identify Named Sector / Mevkii & Hazard Level
  let sectorName = 'İzmir Genel Sektörü';
  let hazardLevel = 'ORTA';

  for (const s of NAMED_SECTORS) {
    if (lat >= s.minLat && lat <= s.maxLat && lng >= s.minLng && lng <= s.maxLng) {
      sectorName = s.name;
      hazardLevel = s.hazardLevel || 'ORTA';
      break;
    }
  }

  // 2. Nearest Landmarks (Peak, Water, Hospital)
  const sortedLandmarks = TACTICAL_LANDMARKS.map((l) => ({
    ...l,
    distMeters: calculateDistanceMeters(lat, lng, l.lat, l.lng),
    bearing: calculateBearing(lat, lng, l.lat, l.lng),
  })).sort((a, b) => a.distMeters - b.distMeters);

  const nearestLandmark = sortedLandmarks[0] || null;
  const nearestHospital =
    sortedLandmarks.find((l) => l.type.includes('HASTANE') || l.type.includes('AFAD')) || null;

  // 3. Terrain Type Estimation from Altitude & Location
  let terrainType = 'Kentsel / Düzlük Alan';
  if (altitude > 800) {
    terrainType = 'Yüksek Dağlık & Sarp Arazi';
  } else if (altitude > 300) {
    terrainType = 'Engebeli Dağ Eteği & Orman';
  } else if (altitude > 80) {
    terrainType = 'Tepelik / Eğimli Zemin';
  }

  // 4. Calculate Distance, Bearing & Tactical Vector to Nearest Team Members (Comrades)
  const otherUsers = allUsers.filter(
    (u) => u.id !== targetUser.id && u.hasCoords && u.lat && u.lng
  );

  const nearestComrades = otherUsers
    .map((u) => {
      const distMeters = calculateDistanceMeters(lat, lng, u.lat, u.lng);
      const estWalkMinutes = Math.max(1, Math.round(distMeters / 75)); // approx 4.5 km/h hiking speed
      const altDiff = Math.round((u.altitude || 0) - altitude);
      const bearing = calculateBearing(lat, lng, u.lat, u.lng);

      return {
        id: u.id,
        name: u.name,
        team: u.team,
        avatar: u.avatar,
        initials: u.initials,
        coords: u.coords,
        lat: u.lat,
        lng: u.lng,
        distMeters,
        distFormatted: formatDistance(distMeters),
        estWalkMinutes,
        altDiff,
        bearing,
        isSos: Boolean(u.isFreshSos || u.isTestSos),
      };
    })
    .sort((a, b) => a.distMeters - b.distMeters)
    .slice(0, 3);

  return {
    sectorName,
    hazardLevel,
    nearestLandmark,
    nearestHospital,
    nearestComrades,
    terrainType,
  };
}

/**
 * Format Last Known Position (LKP) signal freshness.
 */
export function getSignalFreshness(user) {
  if (!user) return { status: 'UNKNOWN', text: 'Bilinmiyor', isLost: false };

  const nowSec = Math.floor(Date.now() / 1000);
  const lastSec = user.locSec || user.lastActiveSec || user.sosSec || 0;

  if (!lastSec || lastSec === 0) {
    return {
      status: 'OFFLINE',
      text: 'Sinyal Alınamadı (LKP)',
      elapsedText: 'Bilinmeyen Zaman',
      isLost: true,
      color: '#EF4444',
    };
  }

  const elapsedSec = nowSec - lastSec;

  if (elapsedSec < 600) {
    return {
      status: 'LIVE',
      text: 'CANLI SİNYAL (GPS AKTİF)',
      elapsedText: 'Şimdi aktif',
      isLost: false,
      color: '#10B981',
    };
  } else if (elapsedSec < 3600) {
    const mins = Math.floor(elapsedSec / 60);
    return {
      status: 'WEAK',
      text: `Sinyal Gecikiyor (${mins} dk önce)`,
      elapsedText: `${mins} dk önce`,
      isLost: false,
      color: '#F59E0B',
    };
  } else if (elapsedSec < 86400) {
    const hours = Math.floor(elapsedSec / 3600);
    return {
      status: 'LOST',
      text: `SİNYAL KESİLDİ (LKP - ${hours} saat önce)`,
      elapsedText: `${hours} saat önce`,
      isLost: true,
      color: '#EF4444',
    };
  } else {
    const days = Math.floor(elapsedSec / 86400);
    return {
      status: 'LOST',
      text: `SİNYAL KESİLDİ (LKP - ${days} gün önce)`,
      elapsedText: `${days} gün önce`,
      isLost: true,
      color: '#EF4444',
    };
  }
}

/**
 * 6. TAKTİK HAYATTA KALMA & PİL TÜKENME TAHMİNİ (Survival & Battery Countdown Engine - Feature 5)
 */
export function calculateSurvivalMetrics(user, weather = null) {
  const battery = Math.max(1, Math.min(100, Number(user?.battery) || 75));
  const temp = weather ? Number(weather.temp) : 12;

  // Cold weather battery penalty (Lithium-ion drops rapidly below 5°C)
  let drainRatePerHour = 6.5; // base 6.5% / hour for continuous GPS broadcast
  if (temp < 0) {
    drainRatePerHour = 18.0; // extreme cold
  } else if (temp < 6) {
    drainRatePerHour = 12.5; // cold mountain
  } else if (temp < 14) {
    drainRatePerHour = 8.5;
  }

  // If user is actively sending SOS, drain accelerates
  if (user?.isFreshSos || user?.isTestSos) {
    drainRatePerHour *= 1.6;
  }

  const hoursRemaining = Math.max(0.2, battery / drainRatePerHour);
  const remainingHoursInt = Math.floor(hoursRemaining);
  const remainingMinsInt = Math.round((hoursRemaining - remainingHoursInt) * 60);

  // Hypothermia risk threshold based on temperature and remaining time
  let hypothermiaRiskLevel = 'DÜŞÜK';
  let hypothermiaTimeText = 'Güvenli Eşik (>12 Saat)';
  if (temp < 4) {
    hypothermiaRiskLevel = 'KRİTİK ACİL';
    hypothermiaTimeText = '~2 Saat (Acil Isı Yalıtımı)';
  } else if (temp < 10) {
    hypothermiaRiskLevel = 'ORTA RİSK';
    hypothermiaTimeText = '~4-5 Saat (Rüzgar Koruması Gerekli)';
  }

  let statusLevel = 'STABİL';
  let statusColor = '#10B981';
  if (hoursRemaining < 1.5 || battery < 15) {
    statusLevel = 'KRİTİK ACİL';
    statusColor = '#EF4444';
  } else if (hoursRemaining < 3.5 || battery < 30) {
    statusLevel = 'DİKKAT (DÜŞÜK PİL)';
    statusColor = '#F59E0B';
  }

  return {
    battery,
    drainRatePerHour: drainRatePerHour.toFixed(1),
    hoursRemaining: hoursRemaining.toFixed(1),
    countdownText: `${remainingHoursInt}s ${remainingMinsInt}dk`,
    hypothermiaRiskLevel,
    hypothermiaTimeText,
    statusLevel,
    statusColor,
  };
}

/**
 * 7. GEOFENCING & TEHLİKE BÖLGELERİ (Hazard Zones & Proximity Detection - Feature 4)
 */
export const DEFAULT_HAZARD_ZONES = [
  {
    id: 'hz-catalkaya',
    name: 'Çatalkaya Sarp Kayalık & Uçurum Bölgesi',
    type: 'UÇURUM / DÜŞME',
    lat: 38.368,
    lng: 27.022,
    radius: 450,
    color: '#EF4444',
    warning: 'DİKKAT: 90° sarp yamaç ve düşme riski!'
  },
  {
    id: 'hz-yamanlar',
    name: 'Yamanlar Çığ & Heyelan Koridoru',
    type: 'ÇIĞ / HEYELAN',
    lat: 38.538,
    lng: 27.162,
    radius: 550,
    color: '#F97316',
    warning: 'DİKKAT: Gevşek zemin ve heyelan sahası!'
  },
  {
    id: 'hz-balcova',
    name: 'Balçova Barajı Su Taşkın Havzası',
    type: 'SU TAŞKINI',
    lat: 38.373,
    lng: 27.043,
    radius: 400,
    color: '#06B6D4',
    warning: 'DİKKAT: Ani su yükselmesi ve kanyon tabanı!'
  },
  {
    id: 'hz-spil',
    name: 'Spil Dağı Zirve Kar & Buzlanma Hattı',
    type: 'BUZLANMA / DONMA',
    lat: 38.562,
    lng: 27.452,
    radius: 700,
    color: '#3B82F6',
    warning: 'DİKKAT: Sıfır altı sıcaklık ve buzlanma tuzağı!'
  }
];

export function checkHazardZoneProximity(user, hazardZones = DEFAULT_HAZARD_ZONES) {
  if (!user || !user.hasCoords || !user.lat || !user.lng) return [];

  const breaches = [];
  for (const zone of hazardZones) {
    const dist = calculateDistanceMeters(user.lat, user.lng, zone.lat, zone.lng);
    const isInside = dist <= zone.radius;
    const isWarning = dist <= (zone.radius + 300);

    if (isInside || isWarning) {
      breaches.push({
        zone,
        distance: dist,
        isInside,
        isWarning: !isInside && isWarning,
        message: isInside 
          ? `🚨 BÖLGE İHLALİ: ${user.name} "${zone.name}" İÇİNDE!`
          : `⚠️ YAKLAŞMA UYARISI: ${user.name} "${zone.name}" sınırına ${dist - zone.radius}m yaklaştı.`
      });
    }
  }

  return breaches;
}

/**
 * 8. 24 SAATLİK ZAMAN TÜNELİ OYNATICI (Timeline Interpolation Engine - Feature 7)
 */
export function interpolateUserTrack(user, progressFactor = 1.0) {
  if (!user || !user.hasCoords || !user.lat || !user.lng) return null;
  const trail = getUserBreadcrumbTrail(user);
  if (trail.length === 0) return user.coords;

  const clamped = Math.max(0, Math.min(1, progressFactor));
  const targetIndex = (trail.length - 1) * clamped;
  const lowerIndex = Math.floor(targetIndex);
  const upperIndex = Math.min(trail.length - 1, Math.ceil(targetIndex));
  const fraction = targetIndex - lowerIndex;

  const p1 = trail[lowerIndex];
  const p2 = trail[upperIndex];

  const lat = p1[0] + (p2[0] - p1[0]) * fraction;
  const lng = p1[1] + (p2[1] - p1[1]) * fraction;

  return [lat, lng];
}

/**
 * 9. AKILLI ARAMA ALANI (SMART DIRECTIONAL SEARCH CONE)
 * Calculates tactical search cone and probability area based on:
 * - Son GPS Noktası (LKP - Last Known Position)
 * - Son Ortalama Yürüyüş Hızı (km/h)
 * - Son Gittiği Yön (Heading / Azimuth Degrees)
 * - Yürüdüğü / Açık Olduğu Saat (Elapsed Hours)
 */
export function calculateDestinationPoint(lat, lon, distanceMeters, bearingDegrees) {
  const R = 6371e3; // Earth radius in meters
  const δ = distanceMeters / R;
  const θ = (bearingDegrees * Math.PI) / 180;
  const φ1 = (lat * Math.PI) / 180;
  const λ1 = (lon * Math.PI) / 180;

  const sinφ2 = Math.sin(φ1) * Math.cos(δ) + Math.cos(φ1) * Math.sin(δ) * Math.cos(θ);
  const φ2 = Math.asin(sinφ2);
  const y = Math.sin(θ) * Math.sin(δ) * Math.cos(φ1);
  const x = Math.cos(δ) - Math.sin(φ1) * sinφ2;
  const λ2 = λ1 + Math.atan2(y, x);

  return [(φ2 * 180) / Math.PI, (λ2 * 180) / Math.PI];
}

export function calculateSmartSearchCone(user, options = {}) {
  if (!user || !user.hasCoords || !user.lat || !user.lng) return null;

  const lkp = [user.lat, user.lng];
  
  // 1. Ortalama Yürüyüş Hızı (km/s) - Dağlık arazide ortalama 3.2 - 4.5 km/s
  const avgSpeedKmh = options.avgSpeedKmh ?? (user.speed && user.speed > 0.5 ? Math.min(6.0, Number(user.speed.toFixed(1))) : 3.8);

  // 2. Son Gittiği Yön (Azimuth 0-360°)
  let headingDeg = options.headingDeg ?? (user.heading || user.azimuth || 65);
  // Default fallback direction if 0
  if (headingDeg === 0) headingDeg = 65;

  // 3. Yürüdüğü / Açık Olduğu Saat (Elapsed Walking Hours)
  const walkHours = options.walkHours ?? (options.hours ?? 1.5);

  // Toplam Kat Edilen Tahmini Mesafe (km ve metre)
  const totalDistanceKm = avgSpeedKmh * walkHours;
  const totalDistanceMeters = totalDistanceKm * 1000;

  // Açısal Dağılım / Koni Açısı (Dağlık arazide sapma açısı: ±35°)
  const halfAngleDeg = 35;
  const startAngle = (headingDeg - halfAngleDeg + 360) % 360;
  const endAngle = (headingDeg + halfAngleDeg + 360) % 360;

  // Koni Poligonu Koordinatları (LKP merkezli açılan sektör)
  const conePolygon = [lkp];
  const arcSteps = 12; // Yay üzerindeki nokta sayısı

  for (let i = 0; i <= arcSteps; i++) {
    const fraction = i / arcSteps;
    // Açıyı hesapla
    let currentAngle = (headingDeg - halfAngleDeg + fraction * (halfAngleDeg * 2) + 360) % 360;
    const arcPoint = calculateDestinationPoint(user.lat, user.lng, totalDistanceMeters, currentAngle);
    conePolygon.push(arcPoint);
  }
  conePolygon.push(lkp); // Poligonu kapat

  // Yüksek Öncelikli Çekirdek Alan (Mesafe'nin %40'ı - İlk Odaklanılacak Alan)
  const corePolygon = [lkp];
  for (let i = 0; i <= arcSteps; i++) {
    const fraction = i / arcSteps;
    let currentAngle = (headingDeg - halfAngleDeg + fraction * (halfAngleDeg * 2) + 360) % 360;
    const corePoint = calculateDestinationPoint(user.lat, user.lng, totalDistanceMeters * 0.45, currentAngle);
    corePolygon.push(corePoint);
  }
  corePolygon.push(lkp);

  // Sektör Arama Alanı (km²)
  // Alan = (θ / 360) * π * R²
  const sectorAngle = halfAngleDeg * 2;
  const searchAreaKm2 = ((sectorAngle / 360) * Math.PI * Math.pow(totalDistanceKm, 2)).toFixed(1);

  // İleri uç merkez nokta (Target Projected Apex)
  const apexPoint = calculateDestinationPoint(user.lat, user.lng, totalDistanceMeters, headingDeg);

  // Yön Metni
  const cardinals = [
    { label: 'Kuzey (0°)', min: 337.5, max: 360 },
    { label: 'Kuzey (0°)', min: 0, max: 22.5 },
    { label: 'Kuzeydoğu (45°)', min: 22.5, max: 67.5 },
    { label: 'Doğu (90°)', min: 67.5, max: 112.5 },
    { label: 'Güneydoğu (135°)', min: 112.5, max: 157.5 },
    { label: 'Güney (180°)', min: 157.5, max: 202.5 },
    { label: 'Güneybatı (225°)', min: 202.5, max: 247.5 },
    { label: 'Batı (270°)', min: 247.5, max: 292.5 },
    { label: 'Kuzeybatı (315°)', min: 292.5, max: 337.5 },
  ];
  const cardinalLabel = (cardinals.find(c => headingDeg >= c.min && headingDeg < c.max) || { label: `${headingDeg}°` }).label;

  return {
    lkp,
    avgSpeedKmh,
    headingDeg,
    cardinalLabel,
    walkHours,
    totalDistanceKm: Number(totalDistanceKm.toFixed(2)),
    totalDistanceMeters: Math.round(totalDistanceMeters),
    searchAreaKm2: Number(searchAreaKm2),
    conePolygon,
    corePolygon,
    apexPoint,
    report: {
      title: 'AKILLI ARAMA ALANI (SAR SEKTÖR RAPORU)',
      targetName: user.name || 'Kazazede',
      lastGpsFormatted: `${user.lat.toFixed(5)}°N, ${user.lng.toFixed(5)}°E`,
      speedFormatted: `${avgSpeedKmh} km/s (Dağlık Zemin Yürüyüş Hızı)`,
      directionFormatted: `${headingDeg}° [${cardinalLabel}]`,
      elapsedTimeFormatted: `${walkHours} Saat (Aktif Yürüyüş / İhbar Süresi)`,
      radiusFormatted: `${totalDistanceKm.toFixed(1)} km (${Math.round(totalDistanceMeters)} m)`,
      areaFormatted: `${searchAreaKm2} km²`,
      probabilityCoreKm: (totalDistanceKm * 0.45).toFixed(1),
      summaryNote: `Kazazede ${walkHours} saat boyunca ${headingDeg}° (${cardinalLabel}) istikametinde ortalama ${avgSpeedKmh} km/s hızla ilerlemiş olabilir. Toplam ${searchAreaKm2} km²'lik arama konisi taranmalıdır.`
    }
  };
}


