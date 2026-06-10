import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vibration/vibration.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../services/premium_service.dart';
import '../services/routing_service.dart';
import '../services/cloud_sync_service.dart';
import 'profile_screen.dart';
import '../database_helper.dart';
import 'mesh_network_screen.dart';
import '../utils/location_permission_helper.dart';

const Color kTOrange = Color(0xFFFF6B00);
const Color kTBg = Color(0xFF0A0A0A);
const Color kTCard = Color(0xFF141414);
const Color kTGreen = Color(0xFF62FF4C);

class TeamScreen extends StatefulWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  String? _teamId;
  String? _teamName;
  bool _loading = true;
  String? _myUid;
  bool _isPremiumUser = false;
  bool _isRecordingVoice = false;
  bool _isPressingPtt = false;
  
  StreamSubscription<Position>? _syncStream;
  DateTime? _lastSyncTime;
  late Stream<Position> _radarLocationStream;
  
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _sfxPlayer = AudioPlayer();
  String? _currentRecordingPath;
  Stream<QuerySnapshot>? _messagesStream;
  Stream<QuerySnapshot>? _membersStream;
  
  StreamSubscription<QuerySnapshot>? _autoPlaySubscription;
  bool _isReceivingVoice = false;
  String? _receivingVoiceSenderName;
  Map<String, String> _memberRoles = {};
  Map<String, String> _memberSafetyStatus = {}; // {uid: status}
  String? _myRole;
  final DateTime _screenOpenTime = DateTime.now();
  
  // Güvenlik durumu seçenekleri
  static const String kStatusSafe = 'safe';
  static const String kStatusAssistance = 'assistance_needed';
  static const String kStatusUnknown = 'unknown';

  @override
  void initState() {
    super.initState();
    _audioPlayer.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.allowBluetooth,
        },
      ),
    ));
    _sfxPlayer.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.allowBluetooth,
        },
      ),
    ));
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadTeam();
    _startLocationSync();
    _radarLocationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    ).asBroadcastStream();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }
  
  Future<void> _startLocationSync() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await LocationPermissionHelper.checkAndRequestLocationPermission(context);
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    _syncStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 10),
    ).listen((pos) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_lastSyncTime == null || now.difference(_lastSyncTime!).inSeconds >= 30) {
        _lastSyncTime = now;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          FirebaseFirestore.instance.collection('users').doc(uid).update({
            'last_lat': pos.latitude,
            'last_lng': pos.longitude,
            'last_elevation': pos.altitude,
            'last_seen': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _syncStream?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _sfxPlayer.dispose();
    _autoPlaySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final tId = doc.data()?['team_id'];
      final tName = doc.data()?['team_name'];
      final isPrem = await PremiumService.isPremium();
      if (mounted) {
        setState(() {
          _isPremiumUser = isPrem;
          _teamId = (tId != null && tId.toString().isNotEmpty) ? tId.toString() : null;
          _teamName = tName?.toString();
          _loading = false;
        });
        if (_teamId != null) {
          _setupTeamStreams();
        }
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _setupTeamStreams() {
    if (_teamId == null || _activeStreamTeamId == _teamId) return;
    _activeStreamTeamId = _teamId;
    
    // Üyeleri 'users' koleksiyonundaki 'team_id' alanına göre çekiyoruz (Radar ile uyumlu)
    _membersStream = FirebaseFirestore.instance.collection('users').where('team_id', isEqualTo: _teamId).snapshots();
    _membersStream!.listen((snap) {
      if (mounted) {
        final Map<String, String> roles = {};
        final Map<String, String> safety = {};
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // Rol bilgisi
          String role = data['role'] ?? 'member';
          if (data['is_guide'] == true || data['email'] == 'sercanoral65@gmail.com') {
            role = 'leader';
          }
          roles[doc.id] = role;
          
          // Güvenlik durumu
          safety[doc.id] = data['safety_status'] ?? kStatusUnknown;
        }
        setState(() {
          _memberRoles = roles;
          _memberSafetyStatus = safety;
          _myRole = roles[_myUid];
        });
      }
    });
    _messagesStream = FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').orderBy('timestamp', descending: true).snapshots();
    _initAutoPlaySubscription();
  }

  Future<void> _createTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: const [
          Icon(Icons.group_add, color: kTOrange),
          SizedBox(width: 10),
          Text('Yeni Ekip Kur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ekip adı (Örn: İDADİK Dağcılık)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kTOrange)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              style: GoogleFonts.shareTechMono(color: kTOrange, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Özel Kod (İsteğe Bağlı, Örn: IDADIK)',
                hintStyle: GoogleFonts.shareTechMono(color: Colors.white24, fontWeight: FontWeight.normal),
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kTOrange)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Boş bırakırsanız rastgele kod oluşturulur.', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kTOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'code': codeCtrl.text.trim().toUpperCase()}),
            child: const Text('OLUŞTUR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    
    if (result == null || result['name']!.isEmpty) return;
    String teamName = result['name']!;
    String code = result['code']!.isEmpty ? _generateCode() : result['code']!;

    try {
      final teamRef = FirebaseFirestore.instance.collection('teams').doc(code);
      final existing = await teamRef.get();
      if (existing.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu ekip kodu zaten alınmış! Lütfen başka bir kod seçin.'), backgroundColor: Colors.red));
        return;
      }

      await teamRef.set({
        'name': teamName,
        'code': code,
        'created_by': uid,
        'created_at': FieldValue.serverTimestamp(),
      });
      // Üye dökümanını da ekle (opsiyonel ama yapıda kalsın)
      await teamRef.collection('members').doc(uid).set({
        'joined_at': FieldValue.serverTimestamp(),
        'role': 'leader',
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'team_id': code,
        'team_name': teamName,
      }, SetOptions(merge: true));

      setState(() {
        _teamId = code;
        _teamName = teamName;
      });
      _setupTeamStreams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _joinTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: const [
          Icon(Icons.login, color: kTOrange),
          SizedBox(width: 10),
          Text('Ekibe Katıl', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Davet kodunu girin:', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.shareTechMono(color: kTOrange, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: GoogleFonts.shareTechMono(color: Colors.white24),
                filled: true,
                fillColor: Colors.black,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kTOrange)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kTOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
            child: const Text('KATIL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    try {
      final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(code).get();
      if (!teamDoc.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ekip bulunamadı! Kodu kontrol edin.'), backgroundColor: Colors.red));
        return;
      }
      final tName = teamDoc.data()?['name'] ?? 'Ekip';
      await teamDoc.reference.collection('members').doc(uid).set({
        'joined_at': FieldValue.serverTimestamp(),
        'role': 'member',
      });
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'team_id': code,
        'team_name': tName,
      }, SetOptions(merge: true));

      setState(() {
        _teamId = code;
        _teamName = tName;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ "$tName" ekibine katıldınız!'), backgroundColor: Colors.green.shade800));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _leaveTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _teamId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTCard,
        title: const Text('Ekipten Ayrıl', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Ekibinizden ayrılmak istediğinizden emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('AYRIL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('members').doc(uid).delete();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'team_id': FieldValue.delete(), 'team_name': FieldValue.delete()});
      setState(() {
        _teamId = null;
        _teamName = null;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: kTBg, body: Center(child: CircularProgressIndicator(color: kTOrange)));
    }

    if (_teamId == null) {
      return _buildNoTeamScreen();
    }

    return Scaffold(
      backgroundColor: kTBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ACİL DURUM ',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
              ),
              TextSpan(
                text: 'EKİBİM',
                style: TextStyle(color: kTOrange, fontWeight: FontWeight.w900, fontSize: 18, fontStyle: FontStyle.italic, letterSpacing: 2),
              ),
            ],
          ),
        ),
        actions: [
          // Davet kodu paylaş
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            tooltip: 'Davet Et',
            onPressed: () => _showInviteSheet(),
          ),
          // Grup Bilgisi / Üyeler
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Ekip Bilgisi',
            onPressed: () => _showTeamSettings(),
          ),
          // Ekipten ayrıl
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
            tooltip: 'Ekipten Ayrıl',
            onPressed: _leaveTeam,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kTOrange,
          labelColor: kTOrange,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'MESAJLAR'),
            Tab(icon: Icon(Icons.radio, size: 18), text: 'TELSİZ'),
            Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'CANLI BÖLGE'),
            Tab(icon: Icon(Icons.radar, size: 18), text: 'RADAR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Telsiz sekmesinde yanlışlıkla kaydırmayı önlemek için
        children: [
          _buildChatTab(),
          _buildWalkieTalkieTab(),
          _buildLiveMapTab(),
          _buildRadarTab(),
        ],
      ),
    );
  }

  void _showInviteSheet() {
    if (_teamId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: kTCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('DAVET KODU', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kTOrange.withOpacity(0.5)),
              ),
              child: Text(
                _teamId!,
                style: GoogleFonts.shareTechMono(color: kTOrange, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: kTOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _teamId!));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı!')));
                    },
                    icon: const Icon(Icons.copy, color: Colors.black, size: 18),
                    label: const Text('KOPYALA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBubble(String url, bool isMe) {
    return GestureDetector(
      onTap: () async {
        if (url.startsWith('base64:')) {
          final bytes = base64Decode(url.substring(7));
          await _audioPlayer.play(BytesSource(bytes));
        } else {
          await _audioPlayer.play(UrlSource(url));
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, color: isMe ? Colors.black : kTOrange, size: 24),
          const SizedBox(width: 8),
          Text(
            'SESLİ MESAJ',
            style: TextStyle(
              color: isMe ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: (isMe ? Colors.black : Colors.white).withOpacity(0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVoiceMessage(String path) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _teamId == null) return;
    
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception("Ses dosyası oluşturulamadı.");
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception("Ses kaydedilemedi (Dosya boş/0 bayt). Lütfen mikrofon izinlerini kontrol edin.");
      }

      // Dosyayı byte olarak oku ve base64'e çevir (Storage yerine Firestore'a kaydetmek için)
      final bytes = await file.readAsBytes();
      final base64Audio = 'base64:${base64Encode(bytes)}';
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String name = 'Bilinmeyen';
      if (userDoc.exists && userDoc.data() != null) {
        final d = userDoc.data()!;
        name = d['name'] ?? d['username'] ?? d['ad'] ?? 'Bilinmeyen';
      }
      final pic = userDoc.data()?['profile_pic_url'] ?? '';
      
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(_teamId)
          .collection('messages')
          .add({
        'senderId': uid,
        'senderName': name,
        'senderPic': pic,
        'audioUrl': base64Audio,
        'type': 'voice',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Başarılı yüklemeden sonra yerel dosyayı temizle (opsiyonel)
      try { await file.delete(); } catch (_) {}
      
    } catch (e) {
      debugPrint("Ses Yükleme Hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ses gönderme hatası: ${e.toString()}'), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  String? _activeStreamTeamId;

  Future<void> _sendEvidence() async {
    if (_teamId == null) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = 'base64:${base64Encode(bytes)}';

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String name = userDoc.data()?['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Bilinmeyen';
      final pic = userDoc.data()?['profile_pic_url'] ?? '';

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        debugPrint("Delil için konum alınamadı: $e");
      }

      // 1. Ekip chatine gönder
      await FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').add({
        'senderId': uid,
        'senderName': name,
        'senderPic': pic,
        'text': '📸 DELİL / BULGU EKLENDİ!',
        'image': base64Image,
        'isEvidence': true,
        'lat': position?.latitude,
        'lng': position?.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Komuta merkezine (Admin) gönder
      await CloudSyncService.syncMessage(
        "YENİ DELİL BULUNDU: $name tarafından eklendi.", 
        "EVIDENCE", 
        false
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delil başarıyla iletildi.'), backgroundColor: kTGreen));
      }
    } catch (e) {
      debugPrint("Delil gönderme hatası: $e");
    }
  }

  Widget _buildChatTab() {
    if (_teamId == null) return const SizedBox.shrink();
    
    if (_membersStream == null || _messagesStream == null) {
      _setupTeamStreams();
    }
    
    final msgCtrl = TextEditingController();

    return Column(
      children: [
        _buildSafetyDashboard(),
        
        // Ekip Üyeleri Butonu
        GestureDetector(
          onTap: _showTeamSettings,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups, color: kTOrange, size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('Ekip Üyeleri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 14),
              ],
            ),
          ),
        ),

        // Mesajlar
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _messagesStream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kTOrange));
              }
              final allMsgs = snap.data?.docs ?? [];
              final msgs = allMsgs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return d['type'] != 'voice';
              }).toList();
              if (msgs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white10),
                      const SizedBox(height: 16),
                      const Text('Henüz mesaj yok.\nEkibinizle iletişime geçin!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 14)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) {
                  final data = msgs[i].data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == _myUid;
                  final text = data['text'] ?? '';
                  final sender = data['senderName'] ?? 'Bilinmeyen';
                  final senderPic = data['senderPic'] ?? '';
                  final Timestamp? ts = data['timestamp'];
                  final timeStr = ts != null ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}' : '';

                  ImageProvider? imgProv;
                  if (senderPic.startsWith('base64:')) {
                    try { imgProv = MemoryImage(base64Decode(senderPic.substring(7))); } catch (_) {}
                  } else if (senderPic.isNotEmpty) {
                    imgProv = NetworkImage(senderPic);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: kTOrange.withOpacity(0.2),
                            backgroundImage: imgProv,
                            child: imgProv == null ? Text(sender.isNotEmpty ? sender[0].toUpperCase() : '?', style: const TextStyle(color: kTOrange, fontSize: 11)) : null,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(sender.split(' ').first, style: TextStyle(color: kTOrange.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
                                      if (_memberRoles[data['senderId']] == 'leader') ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: kTOrange, borderRadius: BorderRadius.circular(4)),
                                          child: const Text('REHBER', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                decoration: BoxDecoration(
                                  color: isMe ? kTOrange : kTCard,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 18),
                                  ),
                                  border: isMe ? null : Border.all(color: Colors.white10),
                                ),
                                child: data['type'] == 'voice' 
                                    ? _buildAudioBubble(data['audioUrl'] ?? '', isMe)
                                    : Column(
                                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          if (data['image'] != null && data['image'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: GestureDetector(
                                                onTap: () {
                                                  showDialog(context: context, builder: (_) => Dialog(
                                                    backgroundColor: Colors.transparent,
                                                    insetPadding: EdgeInsets.zero,
                                                    child: Stack(
                                                      alignment: Alignment.center,
                                                      children: [
                                                        InteractiveViewer(
                                                          child: data['image'].toString().startsWith('base64:') 
                                                            ? Image.memory(base64Decode(data['image'].toString().substring(7))) 
                                                            : Image.network(data['image'].toString())
                                                        ),
                                                        Positioned(
                                                          top: 40, right: 20,
                                                          child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))
                                                        )
                                                      ]
                                                    )
                                                  ));
                                                },
                                                onLongPress: () {
                                                  if (isMe || _myRole == 'leader') {
                                                    showDialog(context: context, builder: (ctx) => AlertDialog(
                                                      backgroundColor: kTCard,
                                                      title: const Text('Sil', style: TextStyle(color: Colors.white)),
                                                      content: const Text('Bu delili/resmi silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white54)),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
                                                        TextButton(onPressed: () {
                                                          FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').doc(msgs[i].id).delete();
                                                          Navigator.pop(ctx);
                                                        }, child: const Text('Sil', style: TextStyle(color: Colors.red))),
                                                      ]
                                                    ));
                                                  }
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: data['image'].toString().startsWith('base64:')
                                                      ? Image.memory(
                                                          base64Decode(data['image'].toString().substring(7)),
                                                          width: 200,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                                        )
                                                      : Image.network(
                                                          data['image'].toString(),
                                                          width: 200,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (c,e,s) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          if (text.isNotEmpty)
                                            Text(text, style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 14)),
                                        ],
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                                child: Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                              ),
                            ],
                          ),
                        ),
                        if (isMe) const SizedBox(width: 6),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Mesaj gönder
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.white10))),
          child: Row(
            children: [
              GestureDetector(
                onTap: _sendEvidence,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: kTOrange, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: kTCard, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
                  child: TextField(
                    controller: msgCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ekibine mesaj yaz...',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (!_isPremiumUser) {
                    PremiumService.showPremiumRequired(context, 'Walkie-Talkie (Push-to-Talk) Modu');
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('🎤 Walkie-Talkie için basılı tutun', style: TextStyle(fontWeight: FontWeight.bold)), 
                    backgroundColor: kTOrange,
                    duration: Duration(seconds: 2),
                  ));
                },
                onLongPressStart: (_) async {
                  if (!_isPremiumUser) {
                    PremiumService.showPremiumRequired(context, 'Walkie-Talkie (Push-to-Talk) Modu');
                    return;
                  }
                  
                  _isPressingPtt = true;
                  if (await _audioRecorder.hasPermission()) {
                    final dir = await getTemporaryDirectory();
                    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                    
                    await Future.delayed(const Duration(milliseconds: 150));
                    if (!_isPressingPtt) return;
                    
                    try {
                      await _audioRecorder.start(
                        const RecordConfig(
                          encoder: AudioEncoder.aacLc,
                          sampleRate: 44100,
                          bitRate: 96000,
                          numChannels: 1,
                        ),
                        path: path,
                      );
                      if (_isPressingPtt) {
                        setState(() {
                          _isRecordingVoice = true;
                          _currentRecordingPath = path;
                        });
                        try { Vibration.vibrate(duration: 50); } catch(_) {}
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('🎙️ Walkie-Talkie: Ses kaydediliyor...', style: TextStyle(fontWeight: FontWeight.bold)), 
                          backgroundColor: Colors.redAccent,
                          duration: Duration(seconds: 1),
                        ));
                      } else {
                        await _audioRecorder.stop();
                      }
                    } catch (e) {
                      debugPrint("PTT Start Error: $e");
                    }
                  }
                },
                onLongPressEnd: (_) async {
                  _isPressingPtt = false;
                  if (!_isPremiumUser || !_isRecordingVoice) return;
                  
                  try {
                    final path = await _audioRecorder.stop();
                    setState(() => _isRecordingVoice = false);
                    
                    if (path != null) {
                      _sendVoiceMessage(path);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('📻 Ses iletiliyor...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), 
                        backgroundColor: kTGreen,
                        duration: Duration(seconds: 2),
                      ));
                    }
                  } catch (e) {
                    setState(() => _isRecordingVoice = false);
                  }
                },
                onLongPressCancel: () async {
                  _isPressingPtt = false;
                  if (_isRecordingVoice) {
                    try { await _audioRecorder.stop(); } catch(_) {}
                    setState(() => _isRecordingVoice = false);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _isRecordingVoice ? Colors.redAccent : Colors.white10, shape: BoxShape.circle),
                  child: Icon(Icons.mic, color: _isRecordingVoice ? Colors.white : Colors.white54, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final text = msgCtrl.text.trim();
                  if (text.isEmpty) return;
                  msgCtrl.clear();
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                  String name = 'Bilinmeyen';
                  if (userDoc.exists && userDoc.data() != null) {
                    final d = userDoc.data()!;
                    name = d['name'] ?? d['username'] ?? d['ad'] ?? 'Bilinmeyen';
                  }
                  if (name == 'Bilinmeyen') {
                    name = FirebaseAuth.instance.currentUser?.displayName ?? 'İsimsiz';
                  }
                  final pic = userDoc.data()?['profile_pic_url'] ?? '';
                  await FirebaseFirestore.instance
                      .collection('teams')
                      .doc(_teamId)
                      .collection('messages')
                      .add({
                    'senderId': uid,
                    'senderName': name,
                    'senderPic': pic,
                    'text': text,
                    'type': 'text',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                },
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(color: kTOrange, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _initAutoPlaySubscription() {
    _autoPlaySubscription?.cancel();
    if (_teamId == null) return;

    _autoPlaySubscription = FirebaseFirestore.instance
        .collection('teams')
        .doc(_teamId)
        .collection('messages')
        .where('timestamp', isGreaterThan: _screenOpenTime)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          if (data['type'] == 'voice' && data['senderId'] != _myUid) {
            _playIncomingVoice(data['audioUrl'], data['senderName'] ?? 'BİLİNMEYEN');
          }
        }
      }
    });
  }

  Future<void> _playIncomingVoice(String url, [String? senderName]) async {
    if (_tabController.index != 1) return; // Sadece Telsiz sekmesinde çal

    if (mounted) {
      setState(() {
        _isReceivingVoice = true;
        _receivingVoiceSenderName = senderName;
      });
    }
    
    try {
      try {
        await _sfxPlayer.play(AssetSource('audio/beep.wav'));
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}

      if (url.startsWith('base64:')) {
        // iOS BytesSource çalma güvenilir değil — geçici dosyaya yaz ve oradan çal
        final bytes = base64Decode(url.substring(7));
        final dir = await getTemporaryDirectory();
        final tmpFile = File('${dir.path}/incoming_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await tmpFile.writeAsBytes(bytes);
        await _audioPlayer.play(DeviceFileSource(tmpFile.path));
        // Temizlik
        _audioPlayer.onPlayerComplete.first.then((_) async {
          try { await tmpFile.delete(); } catch (_) {}
        });
      } else {
        await _audioPlayer.play(UrlSource(url));
      }

      // Çalma bitince göstergeyi sıfırla
      await _audioPlayer.onPlayerComplete.first.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
    } catch (_) {
      // Hata olsa da gösterge takılı kalmasın
    } finally {
      try {
        await _sfxPlayer.play(AssetSource('audio/beep.wav'));
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isReceivingVoice = false;
          _receivingVoiceSenderName = null;
        });
      }
    }
  }

  Widget _buildWalkieTalkieTab() {
    if (_teamId == null) return const SizedBox.shrink();
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Telsiz Ekranı
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('FREQ', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(_isReceivingVoice ? 'RX' : (_isRecordingVoice ? 'TX' : 'STBY'), 
                      style: TextStyle(
                        color: _isReceivingVoice ? Colors.green : (_isRecordingVoice ? Colors.red : Colors.green.withOpacity(0.5)),
                        fontSize: 12, fontWeight: FontWeight.bold
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isReceivingVoice 
                    ? (_receivingVoiceSenderName?.toUpperCase() ?? 'ALINIYOR...') 
                    : (_isRecordingVoice ? 'KONUŞUYORSUNUZ' : (_teamName?.toUpperCase() ?? 'EKİP')), 
                  style: GoogleFonts.shareTechMono(
                    color: _isRecordingVoice ? Colors.redAccent : Colors.greenAccent, 
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 2
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('UHF/VHF CH-1', style: GoogleFonts.shareTechMono(color: Colors.green.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          
          // LED Göstergeler
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLedIndicator(color: Colors.red, isOn: _isRecordingVoice, label: 'TX'),
              const SizedBox(width: 40),
              _buildLedIndicator(color: Colors.green, isOn: _isReceivingVoice, label: 'RX'),
            ],
          ),
          
          // PTT Butonu
          GestureDetector(
            onLongPressStart: (_) async {
              if (!_isPremiumUser) {
                PremiumService.showPremiumRequired(context, 'Walkie-Talkie Modu');
                return;
              }
              _isPressingPtt = true;
              if (await _audioRecorder.hasPermission()) {
                try { Vibration.vibrate(duration: 100, amplitude: 255); } catch (_) {}
                try { await _sfxPlayer.play(AssetSource('audio/beep.wav')); } catch (_) {}
                await Future.delayed(const Duration(milliseconds: 200));
                
                if (!_isPressingPtt) return;
                
                final dir = await getTemporaryDirectory();
                final path = '${dir.path}/wt_${DateTime.now().millisecondsSinceEpoch}.m4a';
                
                try {
                await _audioRecorder.start(
                  const RecordConfig(
                    encoder: AudioEncoder.aacLc,
                    sampleRate: 44100,
                    bitRate: 96000,
                    numChannels: 1,
                  ),
                  path: path,
                );
                  if (_isPressingPtt) {
                    setState(() {
                      _isRecordingVoice = true;
                      _currentRecordingPath = path;
                    });
                  } else {
                    await _audioRecorder.stop();
                  }
                } catch(e) {
                  debugPrint("PTT Start Error: $e");
                }
              }
            },
            onLongPressEnd: (_) async {
              _isPressingPtt = false;
              if (!_isPremiumUser || !_isRecordingVoice) return;
              try {
                final path = await _audioRecorder.stop();
                setState(() => _isRecordingVoice = false);
                try { Vibration.vibrate(duration: 50, amplitude: 100); } catch (_) {}
                try { await _sfxPlayer.play(AssetSource('audio/beep.wav')); } catch (_) {}
                
                if (path != null) {
                  _sendVoiceMessage(path);
                }
              } catch (e) {
                setState(() => _isRecordingVoice = false);
              }
            },
            onLongPressCancel: () async {
              _isPressingPtt = false;
              if (_isRecordingVoice) {
                try { await _audioRecorder.stop(); } catch(_) {}
                setState(() => _isRecordingVoice = false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _isRecordingVoice 
                    ? [Colors.red.shade800, Colors.red.shade900, Colors.black]
                    : [const Color(0xFF333333), const Color(0xFF1A1A1A), Colors.black],
                  stops: const [0.6, 0.9, 1.0],
                ),
                boxShadow: _isRecordingVoice 
                  ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)]
                  : [BoxShadow(color: Colors.black, blurRadius: 15, spreadRadius: 5, offset: const Offset(0, 5))],
                border: Border.all(color: Colors.white10, width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 60, color: _isRecordingVoice ? Colors.white : Colors.white54),
                    const SizedBox(height: 10),
                    Text('PUSH\nTO TALK', textAlign: TextAlign.center, style: TextStyle(color: _isRecordingVoice ? Colors.white : Colors.white54, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('Telsiz sekmesi açıkken gelen tüm mesajlar hoparlörünüzden otomatik çalar.', 
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          
          // MESH MODU BUTONU (İnternetsiz İletişim İçin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
              onPressed: () {
                // Mesh Ekranına git
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MeshNetworkScreen()));
              },
              icon: const Icon(Icons.wifi_tethering, size: 18),
              label: const Text('İNTERNETSİZ MESH MODUNA GEÇ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedIndicator({required Color color, required bool isOn, required String label}) {
    return Column(
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOn ? color : color.withOpacity(0.2),
            boxShadow: isOn ? [BoxShadow(color: color, blurRadius: 10, spreadRadius: 2)] : null,
            border: Border.all(color: Colors.white24, width: 1),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLiveMapTab() {
    if (_teamId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('team_id', isEqualTo: _teamId).snapshots(),
      builder: (ctx, usersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').where('isEvidence', isEqualTo: true).snapshots(),
          builder: (ctx, evidenceSnap) {
            final userDocs = usersSnap.data?.docs ?? [];
            final evidenceDocs = evidenceSnap.data?.docs ?? [];

            // Harita için marker'lar ve izler (trails)
        List<Marker> markers = [];
        List<Polyline<Object>> trails = [];
        List<Widget> memberCards = [];
        bool anySos = false;
        String sosName = '';
        String? teamGuideUid;

        for (final doc in userDocs) {
          final d = doc.data() as Map<String, dynamic>;
          final lat = (d['last_lat'] as num?)?.toDouble();
          final lng = (d['last_lng'] as num?)?.toDouble();
          final name = d['name'] ?? 'Bilinmeyen';
          final pic = d['profile_pic_url'] ?? '';
          final email = d['email'] ?? '';
          final uid = doc.id;
          final isMe = uid == _myUid;
          final isGhost = d['ghost_mode'] ?? false;
          final isSOS = d['is_sos'] ?? false;
          final isGuide = d['is_guide'] ?? (email == 'sercanoral65@gmail.com' || d['role'] == 'leader');

          if (isGuide) teamGuideUid = uid;

          if (isSOS) {
            anySos = true;
            sosName = name;
          }

          if (isGhost && !isMe) continue; // Hayalet Modundaysa diğerlerine gizle

          // Canlı İz (Trail) Verilerini Topla - Sadece yürüyüş aktifken göster
          // STALE TRAIL FILTER: 2 saatten eski verileri haritada gösterme (Kullanıcı talebi)
          final lastSeen = (d['last_seen'] as Timestamp?)?.toDate();
          final isRecentlySeen = lastSeen != null && DateTime.now().difference(lastSeen).inHours < 2;

          if (d['live_trail'] != null && d['is_recording'] == true && isRecentlySeen) {
            final List trailData = d['live_trail'];
            final List<LatLng> points = trailData
                .where((p) => (p['lat'] as num).toDouble() != 0 && (p['lng'] as num).toDouble() != 0)
                .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                .toList();
            if (points.isNotEmpty) {
              trails.add(Polyline<Object>(
                points: points,
                strokeWidth: 3.0,
                color: (isSOS ? Colors.redAccent : (isMe ? kTGreen : kTOrange)).withOpacity(0.6),
              ));
            }
          }
          
          // Planlanan Rota (Kullanıcının seçtiği veya birini takip ettiği rota)
          if (d['planned_route'] != null && d['is_recording'] == true) {
            final List planData = d['planned_route'];
            final List<LatLng> planPoints = planData
                .where((p) => (p['lat'] as num).toDouble() != 0 && (p['lng'] as num).toDouble() != 0)
                .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                .toList();
            if (planPoints.isNotEmpty) {
              final followingName = d['following_name'];
              trails.add(Polyline<Object>(
                points: planPoints,
                strokeWidth: 5.0,
                color: Colors.cyanAccent.withOpacity(0.9),
                pattern: StrokePattern.dashed(segments: [15, 15]),
              ));

              // Eğer birini takip ediyorsa haritaya bir metin ekleyelim
              if (followingName != null && planPoints.isNotEmpty) {
                markers.add(Marker(
                  point: planPoints.first,
                  width: 120,
                  height: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.cyanAccent, width: 1),
                    ),
                    child: Text(
                      '$name ➔ $followingName',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ));
              }
            }
          }

          if (lat != null && lng != null) {
            markers.add(Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () => _showMemberTacticalInfo(d, uid, isMe, isSOS, isGuide),
                child: _buildMapMarker(name, pic, isMe, isSOS, isGuide, isRecording: d['is_recording'] == true),
              ),
            ));
          }

          // Üye kart
          memberCards.add(_buildMemberCard(d, uid, isMe, isSOS, isGuide));
        }

        // Delil markerları ekle
        for (final evDoc in evidenceDocs) {
          final evData = evDoc.data() as Map<String, dynamic>;
          final lat = (evData['lat'] as num?)?.toDouble();
          final lng = (evData['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            markers.add(Marker(
              point: LatLng(lat, lng),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  showDialog(context: context, builder: (_) => Dialog(
                    backgroundColor: kTCard,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (evData['image'] != null && evData['image'].toString().startsWith('base64:'))
                          Image.memory(base64Decode(evData['image'].toString().substring(7)))
                        else if (evData['image'] != null && evData['image'].toString().isNotEmpty)
                          Image.network(evData['image'].toString()),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Gönderen: ${evData['senderName']}\nBULGU / DELİL', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
                        if (evData['senderId'] == _myUid || _myRole == 'leader')
                          TextButton(
                            onPressed: () {
                              FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').doc(evDoc.id).delete();
                              Navigator.pop(context);
                            }, 
                            child: const Text('Sil', style: TextStyle(color: Colors.red))
                          )
                      ]
                    )
                  ));
                },
                child: Container(
                  decoration: BoxDecoration(color: Colors.black87, shape: BoxShape.circle, border: Border.all(color: Colors.yellow, width: 2)),
                  child: const Icon(Icons.camera_alt, color: Colors.yellow, size: 24),
                ),
              )
            ));
          }
        }

            // Harita merkezi hesapla
            LatLng center = const LatLng(39.0, 35.0);
            if (markers.isNotEmpty) {
              double sumLat = 0, sumLng = 0;
              for (final m in markers) {
                sumLat += m.point.latitude;
                sumLng += m.point.longitude;
              }
              center = LatLng(sumLat / markers.length, sumLng / markers.length);
            }

            return Column(
              children: [
                // Canlı harita
                Expanded(
                  flex: 6,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: markers.length > 1 ? 5.0 : 12.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _isPremiumUser 
                                ? 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1Ijoic2VyY2Fub3JhbGwiLCJhIjoiY21vdGxneTR1MDZkNjJ1czl5OG4xZGRtNSJ9.aZd3CyiISCcxlcR0hXkhhQ'
                                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.mountaineering_app',
                            maxZoom: 22,
                            maxNativeZoom: _isPremiumUser ? 20 : 19,
                          ),
                          PolylineLayer<Object>(polylines: [
                            ...trails.cast<Polyline<Object>>(),
                            if (_navigationRoute != null) _navigationRoute!,
                          ]),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                      // Canlı badge
                      Positioned(
                        top: 12, right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_myRole == 'leader' || _myUid == teamGuideUid)
                              GestureDetector(
                                onTap: _resetTeamMap,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.refresh, color: Colors.redAccent, size: 12),
                                      const SizedBox(width: 4),
                                      Text('HARİTAYI SIFIRLA', style: GoogleFonts.shareTechMono(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: kTGreen.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: kTGreen, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text('CANLI', style: GoogleFonts.shareTechMono(color: kTGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Ekip kodu overlay
                      Positioned(
                        top: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.groups, color: kTOrange, size: 14),
                              const SizedBox(width: 6),
                              Text(_teamName ?? _teamId ?? '', style: GoogleFonts.shareTechMono(color: kTOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      // ACİL DURUM BANNERI
                      if (anySos)
                        Positioned(
                          top: 50, left: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'ACİL DURUM: $sosName yardım bekliyor',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Üye listesi
                Container(
                  height: 190,
                  color: kTBg,
                  child: userDocs.isEmpty
                      ? const Center(child: Text('Henüz konum paylaşan üye yok', style: TextStyle(color: Colors.white38, fontSize: 13)))
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          children: memberCards,
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMapMarker(String name, String pic, bool isMe, bool isSOS, bool isGuide, {bool isRecording = false}) {
    ImageProvider? imgProv;
    if (pic.startsWith('base64:')) {
      try { imgProv = MemoryImage(base64Decode(pic.substring(7))); } catch (_) {}
    } else if (pic.isNotEmpty) {
      imgProv = NetworkImage(pic);
    }
    
    Color mainColor = isSOS ? Colors.redAccent : (isMe ? kTGreen : kTOrange);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSOS) const Text('🔥 SOS', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            if (isGuide) Text('REHBER', style: GoogleFonts.shareTechMono(color: kTOrange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            if (isRecording && !isSOS) Text('• TAKİPTE', style: GoogleFonts.shareTechMono(color: kTGreen, fontSize: 8, fontWeight: FontWeight.bold)),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: mainColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withOpacity(isSOS ? 0.4 + (0.4 * _pulseController.value) : 0.5),
                    blurRadius: isSOS ? 8 + (12 * _pulseController.value) : 8,
                    spreadRadius: isSOS ? (4 * _pulseController.value) : 0,
                  )
                ],
              ),
              child: ClipOval(
                child: imgProv != null
                    ? Image(image: imgProv, fit: BoxFit.cover)
                    : Container(color: kTCard, child: Icon(Icons.person, color: mainColor, size: 20)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
                border: isSOS ? Border.all(color: Colors.redAccent) : null,
              ),
              child: Text(name.split(' ').first, style: TextStyle(color: mainColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> d, String uid, bool isMe, bool isSOS, bool isGuide) {
    final name = d['name'] ?? 'Bilinmeyen';
    final pic = d['profile_pic_url'] ?? '';
    final lat = (d['last_lat'] as num?)?.toDouble();
    final lng = (d['last_lng'] as num?)?.toDouble();
    final elevation = (d['last_elevation'] as num?)?.toDouble();
    final isRecording = d['is_recording'] ?? false;

    ImageProvider? imgProv;
    if (pic.startsWith('base64:')) {
      try { imgProv = MemoryImage(base64Decode(pic.substring(7))); } catch (_) {}
    } else if (pic.isNotEmpty) {
      imgProv = NetworkImage(pic);
    }
    
    Color borderColor = isSOS ? Colors.redAccent : (isMe ? kTGreen.withOpacity(0.5) : (isRecording ? kTOrange.withOpacity(0.4) : Colors.white12));

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: uid))),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kTCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isMe || isRecording || isSOS ? 1.5 : 1,
          ),
          boxShadow: isSOS ? [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 8)] : (isMe ? [BoxShadow(color: kTGreen.withOpacity(0.1), blurRadius: 8)] : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kTOrange.withOpacity(0.2),
                  backgroundImage: imgProv,
                  child: imgProv == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: kTOrange, fontWeight: FontWeight.bold, fontSize: 14)) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.split(' ').first, style: TextStyle(color: isSOS ? Colors.redAccent : (isMe ? kTGreen : Colors.white), fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      if (isMe) const Text('BEN', style: TextStyle(color: kTGreen, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      if (isGuide) const Text('REHBER', style: TextStyle(color: kTOrange, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      if (isSOS) const Text('CANLI KONUM', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (lat != null && lng != null) ...[
              _buildMiniStat(Icons.location_on, '${lat.toStringAsFixed(4)}°N', kTOrange),
              const SizedBox(height: 4),
              _buildMiniStat(Icons.explore, '${lng.toStringAsFixed(4)}°E', Colors.lightBlueAccent),
              if (elevation != null && elevation > 0) ...[
                const SizedBox(height: 4),
                _buildMiniStat(Icons.height, '${elevation.toInt()} m', kTGreen),
              ],
            ] else
              Row(children: [
                Icon(Icons.location_off, color: Colors.white24, size: 12),
                const SizedBox(width: 4),
                const Text('Konum yok', style: TextStyle(color: Colors.white24, fontSize: 11)),
              ]),
            if (isRecording) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: kTOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: kTOrange.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: kTOrange, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('TAKİP AKTİF', style: TextStyle(color: kTOrange, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 11),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildNoTeamScreen() {
    return Scaffold(
      backgroundColor: kTBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('EKİP', style: GoogleFonts.outfit(color: kTOrange, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kTOrange.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: kTOrange.withOpacity(0.2)),
                ),
                child: const Icon(Icons.groups_2_outlined, color: kTOrange, size: 60),
              ),
              const SizedBox(height: 28),
              Text('Ekibiniz Yok', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Bir ekip kurarak ya da mevcut bir ekibe katılarak ekibinizle anlık konum paylaşabilir ve grup mesajlaşması yapabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _createTeam,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.black),
                  label: Text('YENİ EKİP KUR', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTOrange,
                    side: BorderSide(color: kTOrange.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _joinTeam,
                  icon: const Icon(Icons.login),
                  label: Text('EKİBE KATIL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarTab() {
    if (_teamId == null) return const SizedBox.shrink();

    if (!_isPremiumUser) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            const Text('Canlı Takım Radarı', style: TextStyle(color: kTOrange, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Ekip üyelerinizin mesafe ve yönlerini çevrimdışı pusula teknolojisiyle radar üzerinden takip etmek için Rota+ Premium\'a geçin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kTOrange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => PremiumService.showPremiumRequired(context, 'Canlı Takım Radarı'),
              icon: const Icon(Icons.stars, color: Colors.black),
              label: const Text('PREMIUM DESTEĞİ AL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('members').snapshots(),
      builder: (ctx, memberSnap) {
        final memberIds = memberSnap.data?.docs.map((d) => d.id).toList() ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: memberIds.isEmpty ? ['_none_'] : memberIds)
              .snapshots(),
          builder: (ctx, usersSnap) {
            final userDocs = usersSnap.data?.docs ?? [];
            if (userDocs.isEmpty) {
              return const Center(child: Text("Üye konumu bulunamadı.", style: TextStyle(color: Colors.white38)));
            }

            return StreamBuilder<CompassEvent>(
              stream: FlutterCompass.events,
              builder: (ctx, compassSnap) {
                double heading = compassSnap.data?.heading ?? 0;

                return StreamBuilder<Position>(
                  stream: _radarLocationStream,
                  builder: (ctx, posSnap) {
                    // Try to get a position: stream data, or a default/fallback to prevent infinite loading on emulators
                    Position? myPos = posSnap.data;

                    if (myPos == null) {
                      return FutureBuilder<Position?>(
                        future: Geolocator.getLastKnownPosition(),
                        builder: (ctx, futureSnap) {
                          if (futureSnap.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(color: kTOrange),
                                  const SizedBox(height: 16),
                                  Text("Sizin konumunuz aranıyor...", style: GoogleFonts.shareTechMono(color: Colors.white54)),
                                ],
                              ),
                            );
                          }
                          
                          if (futureSnap.data != null) {
                            myPos = futureSnap.data;
                            return _buildRadarContent(userDocs, myPos!, heading);
                          } else {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_off, color: Colors.redAccent, size: 48),
                                  const SizedBox(height: 16),
                                  Text("GPS konumu alınamıyor.\nLütfen konumunuzu açın veya hareket edin.", textAlign: TextAlign.center, style: GoogleFonts.shareTechMono(color: Colors.white54)),
                                ],
                              ),
                            );
                          }
                        }
                      );
                    }

                    return _buildRadarContent(userDocs, myPos!, heading);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRadarContent(List<DocumentSnapshot> userDocs, Position myPos, double heading) {
    List<Widget> radarPoints = [];
    for (final doc in userDocs) {
      final uid = doc.id;
      if (uid == _myUid) continue; // Radar'da kendimizi çizmeyelim

      final d = doc.data() as Map<String, dynamic>;
      final targetLat = (d['last_lat'] as num?)?.toDouble();
      final targetLng = (d['last_lng'] as num?)?.toDouble();
      final name = d['name'] ?? 'Bilinmeyen';
      final targetElev = (d['last_elevation'] as num?)?.toDouble();
      final isSOS = d['is_sos'] ?? false;
      final isGhost = d['ghost_mode'] ?? false;

      if (isGhost) continue; // Hayalet Modu aktifse radarda görünmez

      if (targetLat != null && targetLng != null) {
        double distance = Geolocator.distanceBetween(myPos.latitude, myPos.longitude, targetLat, targetLng);
        double bearing = Geolocator.bearingBetween(myPos.latitude, myPos.longitude, targetLat, targetLng);
        
        double relBearing = bearing - heading;
        double rad = relBearing * (pi / 180.0);

        // Radar merkezine uzaklığı oranla (örnek maks 5000 metre radar yarıçapı)
        double radarRadius = MediaQuery.of(context).size.width * 0.4;
        double distanceScale = (distance / 5000).clamp(0.0, 1.0);
        double plotRadius = radarRadius * distanceScale;


        double x = plotRadius * sin(rad);
        double y = -plotRadius * cos(rad); // eksi çünkü y ekranın üstüne doğru azalır

        // Premium Özelliği: Rakım Farkı Gösterimi
        String altStr = '';
        if (_isPremiumUser && targetElev != null) {
          double elevDiff = targetElev - myPos.altitude;
          altStr = '\n${elevDiff >= 0 ? '▲' : '▼'}${elevDiff.abs().toInt()}m';
        }
        
        Color dotColor = isSOS ? Colors.redAccent : kTOrange;

        radarPoints.add(
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(x, y),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isSOS ? 16 : 12, height: isSOS ? 16 : 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: dotColor.withOpacity(0.8), blurRadius: isSOS ? 8 : 4, spreadRadius: isSOS ? 4 : 2)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4), border: isSOS ? Border.all(color: Colors.redAccent) : null),
                    child: Text(
                      isSOS ? '🔥 SOS\n${name.split(' ').first}\n${distance.toInt()}m$altStr' : '${name.split(' ').first}\n${distance.toInt()}m$altStr', 
                      textAlign: TextAlign.center, 
                      style: GoogleFonts.shareTechMono(color: isSOS ? Colors.white : Colors.white, fontSize: 9, fontWeight: isSOS ? FontWeight.bold : FontWeight.normal)
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar arkaplanı
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.width * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kTGreen.withOpacity(0.05),
              border: Border.all(color: kTGreen.withOpacity(0.3), width: 2),
            ),
          ),
          Container(width: MediaQuery.of(context).size.width * 0.6, height: MediaQuery.of(context).size.width * 0.6, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kTGreen.withOpacity(0.2), width: 1))),
          Container(width: MediaQuery.of(context).size.width * 0.3, height: MediaQuery.of(context).size.width * 0.3, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kTGreen.withOpacity(0.1), width: 1))),
          // Hedef (Biz)
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: kTGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: kTGreen, blurRadius: 10)])),
          // Çapraz çizgiler
          Container(width: 1, height: MediaQuery.of(context).size.width * 0.9, color: kTGreen.withOpacity(0.2)),
          Container(height: 1, width: MediaQuery.of(context).size.width * 0.9, color: kTGreen.withOpacity(0.2)),
          // Pusula yönleri
          Positioned(top: MediaQuery.of(context).size.height * 0.05, child: Text('K', style: GoogleFonts.shareTechMono(color: kTGreen, fontWeight: FontWeight.bold))),
          Positioned(bottom: MediaQuery.of(context).size.height * 0.05, child: Text('G', style: GoogleFonts.shareTechMono(color: kTGreen, fontWeight: FontWeight.bold))),
          Positioned(right: MediaQuery.of(context).size.width * 0.05, child: Text('D', style: GoogleFonts.shareTechMono(color: kTGreen, fontWeight: FontWeight.bold))),
          Positioned(left: MediaQuery.of(context).size.width * 0.05, child: Text('B', style: GoogleFonts.shareTechMono(color: kTGreen, fontWeight: FontWeight.bold))),
          
          // Radar Dalgası Animasyonu
          AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, child) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.9 * _pulseController.value,
                height: MediaQuery.of(context).size.width * 0.9 * _pulseController.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kTGreen.withOpacity(1.0 - _pulseController.value), width: 2),
                ),
              );
            },
          ),

          // Takım arkadaşları
          ...radarPoints,
        ],
      ),
    );
  }

  Polyline? _navigationRoute;

  void _showMemberTacticalInfo(Map<String, dynamic> d, String uid, bool isMe, bool isSOS, bool isGuide) async {
    final name = d['name'] ?? 'Bilinmeyen';
    final pic = d['profile_pic_url'] ?? '';
    final lat = (d['last_lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (d['last_lng'] as num?)?.toDouble() ?? 0.0;
    final elevation = (d['last_elevation'] as num?)?.toDouble() ?? 0.0;
    final battery = d['battery_level'] ?? 0;
    final isRecording = d['is_recording'] ?? false;
    final lastSeen = d['last_seen'] as Timestamp?;
    
    String timeStr = 'BİLİNMİYOR';
    if (lastSeen != null) {
      final diff = DateTime.now().difference(lastSeen.toDate());
      if (diff.inMinutes < 1) timeStr = 'ŞİMDİ';
      else timeStr = '${diff.inMinutes} DK ÖNCE';
    }

    // Başlangıç noktası ismi (izden al)
    String startName = 'BİLİNMİYOR';
    if (d['live_trail'] != null && (d['live_trail'] as List).isNotEmpty) {
      final firstPoint = d['live_trail'][0];
      startName = await RoutingService.getAddress(firstPoint['lat'], firstPoint['lng']);
    }

    // Hedef noktası ismi (anlık konumdan al)
    String endName = await RoutingService.getAddress(lat, lng);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isMe ? kTGreen : kTOrange,
                  child: pic.isNotEmpty 
                    ? ClipOval(child: pic.startsWith('base64:') 
                        ? Image.memory(base64Decode(pic.substring(7)), fit: BoxFit.cover, width: 60, height: 60)
                        : Image.network(pic, fit: BoxFit.cover, width: 60, height: 60))
                    : const Icon(Icons.person, color: Colors.black, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1)),
                      Row(
                        children: [
                          if (isGuide) Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: kTOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: kTOrange)),
                            child: Text('REHBER', style: GoogleFonts.shareTechMono(color: kTOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                          Text(isSOS ? 'DURUM: KRİTİK (SOS)' : (isRecording ? 'DURUM: ROTA TAKİBİNDE' : 'DURUM: AKTİF'), style: GoogleFonts.shareTechMono(color: isSOS ? Colors.redAccent : (isRecording ? kTGreen : Colors.white38), fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white24), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            
            // NEREDEN NEREYE
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: kTGreen, size: 14),
                      const SizedBox(width: 8),
                      const Text('BAŞLANGIÇ:', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(startName, style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.flag, color: kTOrange, size: 14),
                      const SizedBox(width: 8),
                      const Text('GÜNCEL HEDEF:', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(endName, style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTacticalMetric('RAKIM', '${elevation.toInt()}m', Icons.height),
                _buildTacticalMetric('BATARYA', '%$battery', Icons.battery_charging_full),
                _buildTacticalMetric('SENKRON', timeStr, Icons.sync),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildLocationRow('ENLEM', lat.toStringAsFixed(6)),
                  const SizedBox(height: 8),
                  _buildLocationRow('BOYLAM', lng.toStringAsFixed(6)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: uid)));
                    },
                    icon: const Icon(Icons.person_search, size: 18),
                    label: const Text('PROFİLİ GÖR'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMe ? null : () async {
                      Navigator.pop(context);
                      // Takip Et Rota Çizme
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Rota hesaplanıyor...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
                        backgroundColor: kTOrange,
                      ));
                      
                      // Mevcut konumumu bul
                      final myPos = await Geolocator.getCurrentPosition();
                      final routeInfo = await RoutingService.getRoute([
                        LatLng(myPos.latitude, myPos.longitude),
                        LatLng(lat, lng),
                      ]);

                      if (routeInfo != null) {
                        // 1. Ekip haritasında göster
                        setState(() {
                          _navigationRoute = Polyline(
                            points: routeInfo.coordinates,
                            strokeWidth: 4.0,
                            color: Colors.blueAccent,
                          );
                        });

                        // 2. Veritabanına "Aktif Rota" olarak kaydet (Canlı Takip ekranı için - Yerel)
                        final noktalarMap = routeInfo.coordinates.map((p) => {
                          'lat': p.latitude,
                          'lng': p.longitude,
                        }).toList();
                        
                        final routeId = await DatabaseHelper.instance.rotaKaydet(
                          '$name Takibi', 
                          noktalarMap,
                          baslangicAdi: 'Mevcut Konumum',
                          bitisAdi: '$name Konumu',
                        );
                        await DatabaseHelper.instance.rotayiAktifYap(routeId);

                        // 3. Bulut Senkronizasyonu: Ekip üyeleri de görsün
                        final myUid = FirebaseAuth.instance.currentUser?.uid;
                        if (myUid != null) {
                          FirebaseFirestore.instance.collection('users').doc(myUid).update({
                            'planned_route': noktalarMap,
                            'following_uid': uid,
                            'following_name': name,
                          });
                        }

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('✅ Rota çizildi! Ekip haritasında $name takibi herkes tarafından görülüyor.', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
                          backgroundColor: kTGreen,
                          duration: const Duration(seconds: 4),
                        ));
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Rota bulunamadı.'), backgroundColor: Colors.red));
                      }
                    },
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('TAKİP ET'),
                    style: ElevatedButton.styleFrom(backgroundColor: kTOrange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kTOrange, size: 20),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 11)),
        Text(value, style: GoogleFonts.shareTechMono(color: kTGreen, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }


  Future<void> _resetTeamMap() async {
    if (_teamId == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTCard,
        title: const Text('Haritayı Sıfırla', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Tüm ekip üyelerinin canlı izleri temizlenecek ve takip oturumları kapatılacak. Emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EVET, SIFIRLA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Ekipteki tüm üyeleri bul
      final usersSnap = await FirebaseFirestore.instance.collection('users').where('team_id', isEqualTo: _teamId).get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in usersSnap.docs) {
        batch.update(doc.reference, {
          'is_recording': false,
          'live_trail': [],
          'is_sos': false,
        });
      }
      
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Tüm ekip rotaları ve takip durumları sıfırlandı.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sıfırlama hatası: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showTeamSettings() {
    if (_teamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ekipten ayrıldınız veya bir ekibiniz yok.')));
      return;
    }
    
    if (_membersStream == null) {
      _setupTeamStreams();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: kTBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('EKİP BİLGİSİ', style: GoogleFonts.outfit(color: kTOrange, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(_teamName ?? 'İsimsiz Ekip', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 24),
                  const Text('ÜYELER', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _membersStream,
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kTOrange));
                        final members = snap.data!.docs;
                        
                        return ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (ctx, i) {
                            final mUid = members[i].id;
                            final mData = members[i].data() as Map<String, dynamic>;
                            final mRole = mData['role'] ?? 'member';
                            
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(mUid).get(),
                              builder: (ctx, userSnap) {
                                final uData = userSnap.data?.data() as Map<String, dynamic>?;
                                final name = uData?['name'] ?? 'Yükleniyor...';
                                final pic = uData?['profile_pic_url'] ?? '';
                                final isMe = mUid == _myUid;
                                final isLeader = mRole == 'leader';

                                ImageProvider? imgProv;
                                if (pic.startsWith('base64:')) {
                                  try { imgProv = MemoryImage(base64Decode(pic.substring(7))); } catch (_) {}
                                } else if (pic.isNotEmpty) {
                                  imgProv = NetworkImage(pic);
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: kTCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: isLeader ? kTOrange.withOpacity(0.3) : Colors.white10)),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: kTOrange.withOpacity(0.1),
                                        backgroundImage: imgProv,
                                        child: imgProv == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: kTOrange, fontSize: 14)) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                            Text(isLeader ? 'EKİP LİDERİ' : 'ÜYE', style: TextStyle(color: isLeader ? kTOrange : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      if (_myRole == 'leader' && !isMe && !isLeader)
                                        IconButton(
                                          icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 20),
                                          onPressed: () => _confirmKick(mUid, name),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _confirmKick(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTCard,
        title: const Text('Üyeyi Çıkar', style: TextStyle(color: Colors.redAccent)),
        content: Text('$name isimli üyeyi ekipten çıkarmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ÇIKAR'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      _kickMember(uid);
    }
  }

  Future<void> _kickMember(String targetUid) async {
    if (_teamId == null) return;
    try {
      // 1. Üyeyi ekipten sil
      await FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('members').doc(targetUid).delete();
      
      // 2. Üyenin kendi dökümanından ekip bilgisini sil
      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'team_id': FieldValue.delete(),
        'team_name': FieldValue.delete(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üye başarıyla çıkarıldı.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildSafetyDashboard() {
    int safeCount = _memberSafetyStatus.values.where((s) => s == kStatusSafe).length;
    int assistanceCount = _memberSafetyStatus.values.where((s) => s == kStatusAssistance).length;
    int totalCount = _memberSafetyStatus.length;
    
    String myStatus = _memberSafetyStatus[_myUid] ?? kStatusUnknown;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTCard,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EKİP GÜVENLİK DURUMU', style: GoogleFonts.shareTechMono(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: assistanceCount > 0 ? Colors.redAccent.withOpacity(0.2) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  assistanceCount > 0 ? '$assistanceCount YARDIM GEREKLİ' : 'HERKES GÜVENDE',
                  style: GoogleFonts.shareTechMono(
                    color: assistanceCount > 0 ? Colors.redAccent : kTGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusIndicator('GÜVENDE', safeCount, totalCount, Colors.green),
              const SizedBox(width: 8),
              _buildStatusIndicator('YARDIM', assistanceCount, totalCount, Colors.redAccent),
              const Spacer(),
              // Kendi durumunu güncelleme
              Row(
                children: [
                  _buildMyStatusButton(
                    icon: Icons.check_circle_outline,
                    color: kTGreen,
                    isActive: myStatus == kStatusSafe,
                    onTap: () => _updateMySafetyStatus(kStatusSafe),
                  ),
                  const SizedBox(width: 8),
                  _buildMyStatusButton(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    isActive: myStatus == kStatusAssistance,
                    onTap: () => _updateMySafetyStatus(kStatusAssistance),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, int total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('/$total', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMyStatusButton({required IconData icon, required Color color, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? color : Colors.white10),
          boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)] : null,
        ),
        child: Icon(icon, color: isActive ? color : Colors.white24, size: 20),
      ),
    );
  }

  Future<void> _updateMySafetyStatus(String status) async {
    if (_myUid == null) return;
    
    // Titreşim ver
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }
    } catch (_) {}

    try {
      await FirebaseFirestore.instance.collection('users').doc(_myUid).update({
        'safety_status': status,
        'last_safety_update': FieldValue.serverTimestamp(),
      });
      
      if (status == kStatusAssistance) {
        // Yardım lazımsa ekibe mesaj da at
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_myUid).get();
        final name = userDoc.data()?['name'] ?? userDoc.data()?['username'] ?? 'Bir üye';
        
        await FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').add({
          'senderId': 'system',
          'senderName': 'SİSTEM UYARISI',
          'text': '🚨 $name ACİL YARDIM ÇAĞRISI GÖNDERDİ! Lütfen koordinatlarını kontrol edin.',
          'type': 'system_alert',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Status Update Error: $e");
    }
  }
}

