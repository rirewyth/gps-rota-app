import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/services.dart';
import '../storage_helper.dart';
import 'users_screen.dart';

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);
const Color kGreen = Color(0xFF62FF4C);

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({Key? key}) : super(key: key);

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _teamId;
  String _userName = 'Kullanıcı';
  
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _teamIdController = TextEditingController();
  
  late TabController _tabController;
  
  // Map/Gps
  Position? _currentPos;
  StreamSubscription<Position>? _posStream;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserStatus();
  }
  
  Future<void> _loadUserStatus() async {
    final name = await StorageHelper.getUserName();
    if (name != null) _userName = name;
    
    // Check if user is already in a team
    final userDoc = await _firestore.collection('users').doc(_auth.currentUser?.uid).get();
    if (userDoc.exists && userDoc.data()!.containsKey('team_id')) {
      final tId = userDoc.data()!['team_id'];
      if (tId != null && tId.toString().isNotEmpty) {
        setState(() => _teamId = tId);
        _startLocationBroadcast();
      }
    }
  }

  void _startLocationBroadcast() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      _currentPos = pos;
      if (_teamId != null && _auth.currentUser != null) {
        _firestore.collection('teams').doc(_teamId).collection('members').doc(_auth.currentUser!.uid).set({
          'uid': _auth.currentUser!.uid,
          'name': _userName,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'last_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> _createTeam() async {
    final isPremium = await StorageHelper.isPremium();
    if (!isPremium) {
      _showError('Ekip kurmak Premium özelliğidir!');
      return;
    }
    
    final newTeamRef = _firestore.collection('teams').doc();
    await newTeamRef.set({
      'created_by': _auth.currentUser?.uid,
      'created_at': FieldValue.serverTimestamp(),
    });
    
    await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
      'team_id': newTeamRef.id,
    }, SetOptions(merge: true));
    
    setState(() => _teamId = newTeamRef.id);
    _startLocationBroadcast();
  }

  Future<void> _joinTeam() async {
    final tId = _teamIdController.text.trim();
    if (tId.isEmpty) return;
    
    final teamDoc = await _firestore.collection('teams').doc(tId).get();
    if (!teamDoc.exists) {
      _showError('Ekip bulunamadı!');
      return;
    }
    
    await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
      'team_id': tId,
    }, SetOptions(merge: true));
    
    setState(() => _teamId = tId);
    _startLocationBroadcast();
  }
  
  void _leaveTeam() async {
    await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
      'team_id': FieldValue.delete(),
    }, SetOptions(merge: true));
    
    if (_auth.currentUser != null && _teamId != null) {
      await _firestore.collection('teams').doc(_teamId).collection('members').doc(_auth.currentUser!.uid).delete();
    }
    
    setState(() => _teamId = null);
    _posStream?.cancel();
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _teamId == null || _auth.currentUser == null) return;
    
    _msgController.clear();
    await _firestore.collection('teams').doc(_teamId).collection('messages').add({
      'sender_id': _auth.currentUser!.uid,
      'sender_name': _userName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _posStream?.cancel();
    _msgController.dispose();
    _teamIdController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_teamId == null) return _buildNoTeamView();
    
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('EKİBİM', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.people, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersScreen()));
            },
          ),
          IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.redAccent), onPressed: _leaveTeam),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kOrange,
          labelColor: kOrange,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'MESAJLAR'),
            Tab(icon: Icon(Icons.map), text: 'CANLI BÖLGE'),
          ],
        ),
      ),
      body: Column(
        children: [
          // KOPYALANABILIR EKIP KODU PANELİ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: kCardBg,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DAVET KODU', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 2),
                      Text(
                        _teamId!, 
                        style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: kGreen),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _teamId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Davet kodu panoya kopyalandı!'), backgroundColor: kGreen),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    // Normally opens share dialog
                    Clipboard.setData(ClipboardData(text: 'Rota+ uygulamasında ekibe katılmak için kodum: $_teamId'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Davet metni kopyalandı!'), backgroundColor: Colors.blueAccent),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // so map doesn't swipe accidentally
              children: [
                _buildChatView(),
                _buildTeamMap(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTeamView() {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('EKİP', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: kOrange.withOpacity(0.1),
                child: const Icon(Icons.group_add_rounded, size: 50, color: kOrange),
              ),
              const SizedBox(height: 24),
              Text('Bir Ekibe Dahil Değilsiniz', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Doğa yürüyüşlerinde ve dağ maceralarında arkadaşlarınızla konum paylaşın ve grupta kalın.', 
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, height: 1.5)),
              const SizedBox(height: 40),
              
              // KOD İLE KATIL (Daha belirgin)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MEVCUT EKİBE KATIL', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _teamIdController,
                      style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Davet Kodunu Yapıştır',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.black,
                        prefixIcon: const Icon(Icons.tag, color: kOrange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kOrange)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _joinTeam,
                        child: const Text('KATIL', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Row(children: [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('VEYA', style: TextStyle(color: Colors.white38))),
                Expanded(child: Divider(color: Colors.white12)),
              ]),
              const SizedBox(height: 30),
              
              // YENI EKIP KUR
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  backgroundColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_moderator, color: kGreen),
                label: const Text('YENİ LİDERLİK GURUBU KUR', style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                onPressed: _createTeam,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('teams').doc(_teamId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kOrange));
              
              final msgs = snapshot.data!.docs;
              if (msgs.isEmpty) {
                return const Center(child: Text('İlk mesajı sen gönder.', style: TextStyle(color: Colors.white38)));
              }
              
              return ListView.builder(
                reverse: false,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final msg = msgs[index];
                  final isMe = msg['sender_id'] == _auth.currentUser?.uid;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? kOrange.withOpacity(0.2) : kCardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isMe ? kOrange.withOpacity(0.5) : Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe) Text(msg['sender_name'] ?? 'Bilinmeyen', style: const TextStyle(color: kOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                          if (!isMe) const SizedBox(height: 4),
                          Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: kCardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('teams').doc(_teamId).collection('members').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kOrange));
        
        final members = snapshot.data!.docs;
        List<Marker> markers = [];
        
        for (var m in members) {
          final lat = m['lat'] as double?;
          final lng = m['lng'] as double?;
          if (lat != null && lng != null) {
            markers.add(
              Marker(
                point: LatLng(lat, lng),
                width: 60, height: 60,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      color: Colors.black87,
                      child: Text(m['name'].toString().substring(0, m['name'].toString().length > 5 ? 5 : m['name'].toString().length), 
                        style: const TextStyle(color: Colors.white, fontSize: 8)),
                    ),
                    const Icon(Icons.location_on, color: kOrange, size: 30),
                  ],
                ),
              ),
            );
          }
        }
        
        final initCenter = markers.isNotEmpty ? markers.first.point : const LatLng(39.0, 35.0);
        
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initCenter,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'RotaPlus_Tactical_v1.0',
            ),
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }
}
