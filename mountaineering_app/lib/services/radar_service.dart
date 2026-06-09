import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TeammateLocation {
  final String uid;
  final String name;
  final double lat;
  final double lng;
  final DateTime lastUpdate;
  final bool isRecording;

  TeammateLocation({
    required this.uid,
    required this.name,
    required this.lat,
    required this.lng,
    required this.lastUpdate,
    required this.isRecording,
  });
}

class RadarService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> broadcastLocation(double lat, double lng) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _db.collection('users').doc(user.uid).set({
        'lat': lat,
        'lng': lng,
        'location_timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error broadcasting location: $e');
    }
  }

  static Stream<List<TeammateLocation>> getTeammateLocations() async* {
    final user = _auth.currentUser;
    if (user == null) yield [];

    // Önce kullanıcının kendi team_id'sini al.. eger yoksa bir stream veremeyiz, bos list donelim.
    final docSnap = await _db.collection('users').doc(user?.uid).get();
    final teamId = docSnap.data()?['team_id'] as String?;

    if (teamId == null || teamId.isEmpty) {
        yield* const Stream.empty();
        return;
    }

    yield* _db.collection('users').where('team_id', isEqualTo: teamId).snapshots().map((snapshot) {
      final List<TeammateLocation> teammates = [];
      for (var doc in snapshot.docs) {
        if (doc.id == user?.uid) continue; // Kendimizi haritada tekrar isaretlemeyelim
        
        final data = doc.data();
        if (data['lat'] != null && data['lng'] != null) {
            final ts = data['location_timestamp'] as Timestamp?;
            final lastUpdateDate = ts != null ? ts.toDate() : DateTime.now();

            // Eğer 30 dakikadan eskiyse gosterme (Offline say)
            if (DateTime.now().difference(lastUpdateDate).inMinutes < 30) {
              teammates.add(TeammateLocation(
                uid: doc.id,
                name: data['name'] ?? 'Operatör',
                lat: (data['lat'] as num).toDouble(),
                lng: (data['lng'] as num).toDouble(),
                lastUpdate: lastUpdateDate,
                isRecording: data['is_recording'] ?? false,
              ));
            }
        }
      }
      return teammates;
    });
  }
}
