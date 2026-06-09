class Mountain {
  final String name;
  final double lat;
  final double lng;
  final int altitude;

  const Mountain({
    required this.name,
    required this.lat,
    required this.lng,
    required this.altitude,
  });
}

class POI {
  final String name;
  final double lat;
  final double lng;
  final String type; // 'shelter', 'rest_area', 'danger', 'junction'
  final String description;

  const POI({
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.description,
  });
}

class MountainDB {
  static const List<Mountain> turkishMountains = [
    Mountain(name: 'Ağrı Dağı (Mt. Ararat)', lat: 39.7020, lng: 44.2990, altitude: 5137),
    Mountain(name: 'Cilo Dağı (Uludoruk)', lat: 37.4916, lng: 43.9930, altitude: 4139),
    Mountain(name: 'Süphan Dağı', lat: 38.9328, lng: 42.8252, altitude: 4058),
    Mountain(name: 'Kaçkar Dağı', lat: 40.8354, lng: 41.1610, altitude: 3932),
    Mountain(name: 'Erciyes Dağı', lat: 38.5303, lng: 35.4475, altitude: 3916),
    Mountain(name: 'Demirkazık Dağı (Aladağlar)', lat: 37.8016, lng: 35.1583, altitude: 3756),
    Mountain(name: 'Kızılkaya (Aladağlar)', lat: 37.8364, lng: 35.1528, altitude: 3767),
    Mountain(name: 'Hasan Dağı', lat: 38.1275, lng: 34.1661, altitude: 3268),
    Mountain(name: 'Palandöken', lat: 39.8166, lng: 41.2833, altitude: 3271),
    Mountain(name: 'Uludağ', lat: 40.0672, lng: 29.2736, altitude: 2543),
    Mountain(name: 'Tahtalı Dağı (Beydağları)', lat: 36.5369, lng: 30.4505, altitude: 2366),
    Mountain(name: 'Babadağ', lat: 36.5292, lng: 29.1837, altitude: 1969),
    Mountain(name: 'Kaz Dağları (İda)', lat: 39.7139, lng: 26.8519, altitude: 1774),
  ];

  static const List<POI> pointsOfInterest = [
    // Uludağ Bölgesi
    POI(name: 'Oteller Bölgesi Sığınağı', lat: 40.1064, lng: 29.1332, type: 'shelter', description: 'Güvenli barınma noktası.'),
    POI(name: 'Wolfram Maden Harabeleri', lat: 40.0905, lng: 29.1760, type: 'rest_area', description: 'Geniş düzlük, mola yeri.'),
    POI(name: 'Zirve Tepe Dağ Evi', lat: 40.0672, lng: 29.2236, type: 'shelter', description: 'Zirve hattında sığınak.'),
    POI(name: 'Çobankaya Kamp Alanı', lat: 40.1228, lng: 29.1419, type: 'rest_area', description: 'Resmi kamp bölgesi.'),

    // Erciyes Bölgesi
    POI(name: 'Çobanini Dağ Evi', lat: 38.5445, lng: 35.4520, type: 'shelter', description: 'Erciyes tırmanış sığınağı.'),
    POI(name: 'Süt Donduran Yaylası', lat: 38.5670, lng: 35.4230, type: 'rest_area', description: 'Güvenli mola ve su noktası.'),

    // Aladağlar Bölgesi
    POI(name: 'Sokullupınar Kampı', lat: 37.8180, lng: 35.1550, type: 'rest_area', description: 'Ana tırmanış kampı.'),
    POI(name: 'Yediköller Sığınağı', lat: 37.8250, lng: 35.1780, type: 'shelter', description: 'Yüksek irtifa barınma noktası.'),

    // Ağrı
    POI(name: '3200m Kamp Alanı', lat: 39.7020, lng: 44.2950, type: 'rest_area', description: 'Ağrı tırmanışı 1. kamp.'),
    POI(name: '4200m Sığınağı', lat: 39.7150, lng: 44.3050, type: 'shelter', description: 'Ağrı tırmanışı 2. kamp sığınağı.'),
  ];
}
