import 'dart:io';
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

    // iOS'ta arka planda konum için "Always" iznini ayrıca iste
    // Bu olmadan uygulama arka plana geçince GPS stream durur → uygulama kapanır
    if (Platform.isIOS &&
        permission == LocationPermission.whileInUse) {
      // iOS'ta "Always" izni ancak "WhenInUse" verildikten sonra istenebilir
      // Kullanıcıya neden gerekli olduğunu açıklayan bir diyalog göster
      if (context.mounted) {
        bool? alwaysAgreed = await _showAlwaysLocationDisclosure(context);
        if (alwaysAgreed == true) {
          permission = await Geolocator.requestPermission();
        }
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
            child: const Text("Devam Et", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// iOS'a özel: Arka planda konum için "Her Zaman İzin Ver" diyaloğu
  static Future<bool?> _showAlwaysLocationDisclosure(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFFF6B00)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Arka Plan Konum İzni",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            "📍 Rota kaydı arka planda çalışmaya devam edebilmesi için:\n\n"
            "Açılan ayar ekranında konum iznini\n"
            "\"Her Zaman İzin Ver\" olarak değiştirin.\n\n"
            "Bu olmadan telefonu cepte taşıdığınızda uygulama kapanabilir ve rotanız kaydedilemez.",
            style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ATLA", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("AYARLARA GİT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
