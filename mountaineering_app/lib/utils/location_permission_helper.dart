import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionHelper {
  static Future<LocationPermission> checkAndRequestLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Sadece izin hiç verilmemişse uyarıyı göster ve iste
      bool? agreed = await _showProminentDisclosure(context);
      
      if (agreed == true) {
        permission = await Geolocator.requestPermission();
      }
    }

    return permission;
  }

  static Future<bool?> _showProminentDisclosure(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFFFF6B00)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Konum İzni Gerekli",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            "Rota+, canlı takip özelliğini kullanabilmeniz, rotanızı kaydedebilmeniz ve acil durumlarda (SOS) ekibinizin sizi bulabilmesi için konum verilerinizi toplar.\n\n"
            "Bu veriler, siz bir rotayı takip ederken veya kaydederken uygulama arka planda çalışırken veya kapalıyken bile toplanmaya devam eder.\n\n"
            "Devam etmek için konum erişimine izin vermeniz gerekmektedir.",
            style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("REDDET", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("KABUL ET", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
