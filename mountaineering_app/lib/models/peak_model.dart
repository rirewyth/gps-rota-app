class PeakModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int elevation; // metre cinsinden

  PeakModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
  });

  factory PeakModel.fromJson(Map<String, dynamic> json) {
    // Overpass API'den gelen veriye göre uyarlanmıştır.
    int ele = 0;
    if (json['tags']?['ele'] != null) {
      ele = int.tryParse(json['tags']['ele'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }

    return PeakModel(
      id: json['id'].toString(),
      name: json['tags']?['name'] ?? 'İsimsiz Tepe',
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['lon'] ?? 0.0).toDouble(),
      elevation: ele,
    );
  }
}
