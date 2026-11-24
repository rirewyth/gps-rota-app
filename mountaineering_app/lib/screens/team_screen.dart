import 'dart:async';
import 'dart:convert';
import 'dart:ui';
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
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import '../services/premium_service.dart';
import '../storage_helper.dart';
import '../services/routing_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/tactical_styles.dart';
import 'profile_screen.dart';
import '../database_helper.dart';
import 'mesh_network_screen.dart';
import '../utils/location_permission_helper.dart';

const Color kTOrange = TacticalStyles.kPrimaryContainer;
const Color kTBg = TacticalStyles.kSurface;
const Color kTCard = TacticalStyles.kSurfaceLow;
const Color kTGreen = TacticalStyles.kTertiary;

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
  
  final MapController _mapController = MapController();
  bool _isFirstLocationFetch = true;
  LatLng? _myLatLng;
  
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

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadTeam();
    _startLocationSync();
    _radarLocationStream = Geolocator.getPositionStream(
      locationSettings: Platform.isIOS
          ? AppleSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              allowBackgroundLocationUpdates: true,
            )
          : const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
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

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        final loc = LatLng(last.latitude, last.longitude);
        setState(() => _myLatLng = loc);
        if (_isFirstLocationFetch) {
          try {
            _mapController.move(loc, 14.5);
            _isFirstLocationFetch = false;
          } catch (_) {}
        }
      }
      final current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        final loc = LatLng(current.latitude, current.longitude);
        setState(() => _myLatLng = loc);
        if (_isFirstLocationFetch) {
          try {
            _mapController.move(loc, 14.5);
            _isFirstLocationFetch = false;
          } catch (_) {}
        }
      }
    } catch (_) {}

    _syncStream = Geolocator.getPositionStream(
      locationSettings: Platform.isIOS
          ? AppleSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 10,
              allowBackgroundLocationUpdates: true,
            )
          : const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 10),
    ).listen((pos) {
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLatLng = loc);
      
      if (_isFirstLocationFetch) {
        try {
          _mapController.move(loc, 14.5);
          _isFirstLocationFetch = false;
        } catch (_) {}
      }
      
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
                fillColor: TacticalStyles.kSurfaceLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kTOrange)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Özel Kod (İsteğe Bağlı, Örn: IDADIK)',
                hintStyle: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38, fontWeight: FontWeight.normal),
                filled: true,
                fillColor: TacticalStyles.kSurfaceLowest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kTOrange)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Boş bırakırsanız rastgele kod oluşturulur.', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kTOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'code': codeCtrl.text.trim().toUpperCase()}),
            child: const Text('OLUŞTUR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white24),
                filled: true,
                fillColor: TacticalStyles.kSurfaceLowest,
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
            child: const Text('KATIL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      return const Scaffold(
        backgroundColor: TacticalStyles.kSurface,
        body: Center(
          child: CircularProgressIndicator(color: TacticalStyles.kPrimaryContainer),
        ),
      );
    }

    if (_teamId == null) {
      return _buildNoTeamScreen();
    }

    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TacticalStyles.kPrimaryContainer.withOpacity(0.14),
                border: Border.all(
                  color: TacticalStyles.kPrimaryContainer.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: TacticalStyles.kPrimaryContainer,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'ACİL DURUM ',
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                            color: TacticalStyles.kTextPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                        ),
                        TextSpan(
                          text: 'EKİBİM',
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                            color: TacticalStyles.kPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'EKİP: ${_teamName?.toUpperCase() ?? _teamId ?? 'AKTİF'}',
                    style: TacticalStyles.monoLabel(
                      color: TacticalStyles.kTextSecondary,
                      size: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Davet kodu paylaş
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TacticalStyles.kSurfaceHigh,
                border: Border.all(color: TacticalStyles.kOutlineVariant),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: TacticalStyles.kTextPrimary,
                size: 17,
              ),
            ),
            tooltip: 'Davet Et',
            onPressed: () => _showInviteSheet(),
          ),
          // Grup Bilgisi / Üyeler
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TacticalStyles.kSurfaceHigh,
                border: Border.all(color: TacticalStyles.kOutlineVariant),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: TacticalStyles.kTextPrimary,
                size: 17,
              ),
            ),
            tooltip: 'Ekip Bilgisi',
            onPressed: () => _showTeamSettings(),
          ),
          // Ekipten ayrıl
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TacticalStyles.kErrorContainer.withOpacity(0.22),
                border: Border.all(color: TacticalStyles.kError.withOpacity(0.25)),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: TacticalStyles.kError,
                size: 17,
              ),
            ),
            tooltip: 'Ekipten Ayrıl',
            onPressed: _leaveTeam,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TacticalStyles.kSurfaceLowest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: TacticalStyles.kGlassBorder),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: TacticalStyles.kPrimaryContainer,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: TacticalStyles.kPrimaryContainer.withOpacity(0.32),
                    blurRadius: 16,
                  ),
                ],
              ),
              labelColor: TacticalStyles.kSurfaceLowest,
              unselectedLabelColor: TacticalStyles.kOnSurfaceVariant,
              labelStyle: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
              unselectedLabelStyle: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_rounded, size: 13),
                      SizedBox(width: 4),
                      Text('MESAJLA'),
                    ],
                  ),
                ),
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cell_tower_rounded, size: 13),
                      SizedBox(width: 4),
                      Text('TELSİZ'),
                    ],
                  ),
                ),
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore_rounded, size: 13),
                      SizedBox(width: 4),
                      Text('CANLI'),
                    ],
                  ),
                ),
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar_rounded, size: 13),
                      SizedBox(width: 4),
                      Text('RADAR'),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                color: TacticalStyles.kSurfaceLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kTOrange.withOpacity(0.5)),
              ),
              child: Text(
                _teamId!,
                style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 4),
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
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    label: const Text('KOPYALA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          final dir = await getTemporaryDirectory();
          final tmpFile = File('${dir.path}/team_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
          await tmpFile.writeAsBytes(bytes);
          await _audioPlayer.setFilePath(tmpFile.path);
          _audioPlayer.play();
        } else {
          await _audioPlayer.setUrl(url);
          _audioPlayer.play();
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
      
      debugPrint("================ TELSİZ KAYIT ================");
      debugPrint("Dosya Yolu: $path");
      debugPrint("Dosya Boyutu: $fileSize byte");
      debugPrint("Codec: AAC (AudioEncoder.aacLc)");
      debugPrint("Container: .m4a");
      debugPrint("Sample Rate: 44100");
      debugPrint("Channel Count: 1");
      debugPrint("============================================");

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
    
    if (_membersStream == null || _messagesStream == null || _activeStreamTeamId != _teamId) {
      _setupTeamStreams();
    }
    
    final msgCtrl = TextEditingController();

    return Column(
      children: [
        _buildSafetyDashboard(),
        
        // Ekip Üyeleri Butonu (Liquid Glass Strip)
        GestureDetector(
          onTap: _showTeamSettings,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: TacticalStyles.glassCardDecoration(radius: 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: TacticalStyles.kPrimaryContainer.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: TacticalStyles.kPrimaryContainer.withOpacity(0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: TacticalStyles.kPrimaryContainer,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ekip Üyeleri',
                        style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                          color: TacticalStyles.kTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'AKTİF EKİP ÜYELERİ & ROLLER',
                        style: TacticalStyles.monoLabel(
                          color: TacticalStyles.kTextSecondary,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: TacticalStyles.kTextSecondary,
                  size: 20,
                ),
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
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(28),
                    decoration: TacticalStyles.glassCardDecoration(radius: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: TacticalStyles.kSurfaceLowest,
                            border: Border.all(color: TacticalStyles.kOutlineVariant),
                          ),
                          child: const Icon(
                            Icons.forum_rounded,
                            size: 30,
                            color: TacticalStyles.kPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz mesaj yok.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                            color: TacticalStyles.kTextPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ekibinizle iletişime geçin!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                            color: TacticalStyles.kTextSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            radius: 15,
                            backgroundColor: TacticalStyles.kPrimaryContainer.withOpacity(0.2),
                            backgroundImage: imgProv,
                            child: imgProv == null
                                ? Text(
                                    sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: TacticalStyles.kPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        sender.split(' ').first,
                                        style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                                          color: TacticalStyles.kPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (_memberRoles[data['senderId']] == 'leader') ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: TacticalStyles.kPrimaryContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'REHBER',
                                            style: TacticalStyles.monoLabel(
                                              color: Colors.white,
                                              size: 7.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                                decoration: BoxDecoration(
                                  color: data['type'] == 'system_alert'
                                      ? TacticalStyles.kErrorContainer.withOpacity(0.28)
                                      : (isMe ? TacticalStyles.kSurfaceHigh : TacticalStyles.kSurfaceContainer),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: Border.all(
                                    color: data['type'] == 'system_alert'
                                        ? TacticalStyles.kPrimaryContainer.withOpacity(0.6)
                                        : (isMe
                                            ? TacticalStyles.kPrimary.withOpacity(0.45)
                                            : TacticalStyles.kTertiary.withOpacity(0.35)),
                                    width: 1,
                                  ),
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
                                                  borderRadius: BorderRadius.circular(10),
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
                                            Text(
                                              text,
                                              style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                                child: Text(
                                  timeStr,
                                  style: TacticalStyles.monoValue(
                                    color: TacticalStyles.kTextSecondary.withOpacity(0.75),
                                    size: 9.5,
                                  ),
                                ),
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

        // Mesaj gönder (Outdoor Input Dock)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: TacticalStyles.kSurfaceLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TacticalStyles.kOutlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _sendEvidence,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSurfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TacticalStyles.kOutlineVariant,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: TacticalStyles.kPrimaryContainer,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSurfaceLowest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: TacticalStyles.kOutlineVariant),
                  ),
                  child: TextField(
                    controller: msgCtrl,
                    style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                      color: TacticalStyles.kTextPrimary,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ekibine mesaj yaz...',
                      hintStyle: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                        color: TacticalStyles.kTextSecondary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('🎤 Walkie-Talkie için basılı tutun', style: TextStyle(fontWeight: FontWeight.bold)), 
                    backgroundColor: kTOrange,
                    duration: Duration(seconds: 2),
                  ));
                },
                onLongPressStart: (_) async {
                  
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
                  if (!_isRecordingVoice) return;
                  
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isRecordingVoice
                        ? TacticalStyles.kErrorContainer
                        : TacticalStyles.kSurfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecordingVoice
                          ? TacticalStyles.kError
                          : TacticalStyles.kOutlineVariant,
                    ),
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: _isRecordingVoice
                        ? Colors.white
                        : TacticalStyles.kTextSecondary,
                    size: 19,
                  ),
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
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: TacticalStyles.kPrimaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
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
        await _sfxPlayer.setAsset('assets/audio/beep.wav');
        _sfxPlayer.play();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}

      if (url.startsWith('base64:')) {
        // iOS BytesSource çalma güvenilir değil — geçici dosyaya yaz ve oradan çal
        final bytes = base64Decode(url.substring(7));
        final dir = await getTemporaryDirectory();
        final tmpFile = File('${dir.path}/incoming_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await tmpFile.writeAsBytes(bytes);
        
        final decodedSize = await tmpFile.length();
        debugPrint("================ TELSİZ OYNATMA ================");
        debugPrint("Çözülen Geçici Dosya Uzantısı: .m4a");
        debugPrint("Çözülen Dosya Boyutu: $decodedSize byte");

        try {
          await _audioPlayer.setFilePath(tmpFile.path);
          _audioPlayer.play();
        } catch (e) {
          debugPrint("AudioPlayers Oynatma Hatası: $e");
        }
        debugPrint("================================================");

        // Temizlik
        _audioPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed).then((_) async {
          try { await tmpFile.delete(); } catch (_) {}
        });
      } else {
        await _audioPlayer.setUrl(url);
        _audioPlayer.play();
      }

      // Çalma bitince göstergeyi sıfırla
      await _audioPlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed).timeout(
        const Duration(seconds: 30),
        onTimeout: () => PlayerState(false, ProcessingState.completed),
      );
    } catch (_) {
      // Hata olsa da gösterge takılı kalmasın
    } finally {
      try {
        await _sfxPlayer.setAsset('assets/audio/beep.wav');
        _sfxPlayer.play();
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
      padding: const EdgeInsets.only(bottom: 20),
      decoration: const BoxDecoration(
        color: TacticalStyles.kSurface,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Telsiz Ekranı
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: TacticalStyles.kSurfaceLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isRecordingVoice
                    ? TacticalStyles.kError.withOpacity(0.5)
                    : TacticalStyles.kOutlineVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TELSİZ KANALI',
                      style: TacticalStyles.monoLabel(
                        color: TacticalStyles.kTertiary,
                        size: 10,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_isReceivingVoice
                                ? TacticalStyles.kTertiary
                                : (_isRecordingVoice
                                    ? TacticalStyles.kError
                                    : TacticalStyles.kSurfaceHigh))
                            .withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _isReceivingVoice
                            ? 'ALINIYOR'
                            : (_isRecordingVoice ? 'GÖNDERİLİYOR' : 'HAZIR'),
                        style: TacticalStyles.monoLabel(
                          color: _isReceivingVoice
                              ? TacticalStyles.kTertiary
                              : (_isRecordingVoice
                                  ? TacticalStyles.kError
                                  : TacticalStyles.kTextSecondary),
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isReceivingVoice 
                    ? (_receivingVoiceSenderName?.toUpperCase() ?? 'ALINIYOR...') 
                    : (_isRecordingVoice ? 'KONUŞUYORSUNUZ' : (_teamName?.toUpperCase() ?? 'EKİP')), 
                  style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                    color: _isRecordingVoice
                        ? TacticalStyles.kError
                        : TacticalStyles.kTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'EKİP SESLİ İLETİŞİM HATTI',
                  style: TacticalStyles.monoValue(
                    color: TacticalStyles.kTextSecondary,
                    size: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // LED Göstergeler
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLedIndicator(color: TacticalStyles.kError, isOn: _isRecordingVoice, label: 'GÖNDER'),
              const SizedBox(width: 48),
              _buildLedIndicator(color: TacticalStyles.kTertiary, isOn: _isReceivingVoice, label: 'DİNLE'),
            ],
          ),
          
          // PTT Butonu
          GestureDetector(
            onLongPressStart: (_) async {
              _isPressingPtt = true;
              if (await _audioRecorder.hasPermission()) {
                try { Vibration.vibrate(duration: 100, amplitude: 255); } catch (_) {}
                try { await _sfxPlayer.setAsset('assets/audio/beep.wav'); _sfxPlayer.play(); } catch (_) {}
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
              if (!_isRecordingVoice) return;
              try {
                final path = await _audioRecorder.stop();
                setState(() => _isRecordingVoice = false);
                try { Vibration.vibrate(duration: 50, amplitude: 100); } catch (_) {}
                try { await _sfxPlayer.setAsset('assets/audio/beep.wav'); _sfxPlayer.play(); } catch (_) {}
                
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
              duration: const Duration(milliseconds: 120),
              width: 184,
              height: 184,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecordingVoice
                    ? TacticalStyles.kPrimaryContainer
                    : TacticalStyles.kSurfaceHigh,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: _isRecordingVoice
                      ? TacticalStyles.kPrimary
                      : TacticalStyles.kOutlineVariant,
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      size: 56,
                      color: _isRecordingVoice
                          ? Colors.white
                          : TacticalStyles.kPrimaryContainer,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'BASILI TUT\nKONUŞ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                        color: _isRecordingVoice
                            ? Colors.white
                            : TacticalStyles.kTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Telsiz sekmesi açıkken gelen tüm mesajlar hoparlörünüzden otomatik çalar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                color: TacticalStyles.kTextSecondary,
                fontSize: 11,
              ),
            ),
          ),
          
          // MESH MODU BUTONU (İnternetsiz İletişim İçin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: TacticalStyles.kSecondaryContainer.withOpacity(0.08),
                foregroundColor: TacticalStyles.kSecondaryContainer,
                side: BorderSide(
                  color: TacticalStyles.kSecondaryContainer.withOpacity(0.45),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MeshNetworkScreen()));
              },
              icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
              label: Text(
                'İNTERNETSİZ MESH MODUNA GEÇ',
                style: TacticalStyles.monoLabel(
                  color: TacticalStyles.kSecondaryContainer,
                  size: 11,
                ),
              ),
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

  Future<void> _sendQuickTacticalSignal(String code, String label, String emoji) async {
    if (_teamId == null || _teamId!.trim().isEmpty) return;
    try {
      LatLng? loc = _myLatLng;
      if (loc == null) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            loc = LatLng(last.latitude, last.longitude);
          } else {
            final curr = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
            ).timeout(const Duration(seconds: 4));
            loc = LatLng(curr.latitude, curr.longitude);
          }
          if (mounted && loc != null) {
            setState(() => _myLatLng = loc);
          }
        } catch (_) {}
      }

      if (loc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konum alınamadı! Haritada pin bırakmak için GPS sinyalini bekleyin.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return;
      }

      final storedName = (await StorageHelper.getUserName())?.trim();
      final senderName = (storedName != null && storedName.isNotEmpty)
          ? storedName
          : (FirebaseAuth.instance.currentUser?.displayName ?? 'Operatör');

      await FirebaseFirestore.instance
          .collection('teams')
          .doc(_teamId!.trim())
          .collection('messages')
          .add({
        'type': 'tactical_signal',
        'signalCode': code,
        'signalLabel': label,
        'signalEmoji': emoji,
        'text': '$emoji TAKTİK SİNYAL: $label ($senderName)',
        'senderId': _myUid,
        'senderName': senderName,
        'lat': loc.latitude,
        'lng': loc.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$emoji "$label" sinyali ekibe gönderildi!'),
            backgroundColor: TacticalStyles.kTertiary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sinyal gönderilemedi: $e')),
        );
      }
    }
  }

  Future<void> _clearMyTacticalSignals() async {
    if (_teamId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(_teamId)
          .collection('messages')
          .where('type', isEqualTo: 'tactical_signal')
          .get();
      int removed = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['senderId'] == _myUid || _myRole == 'leader') {
          await doc.reference.delete();
          removed++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removed > 0
                  ? '$removed adet taktik sinyal pini haritadan kaldırıldı.'
                  : 'Kaldırılabilecek sinyal bulunamadı.',
            ),
            backgroundColor: TacticalStyles.kSurfaceHigh,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sinyaller temizlenemedi: $e')),
        );
      }
    }
  }

  void _showSignalOptionsSheet(String docId, Map<String, dynamic> sig) {
    final emoji = (sig['signalEmoji'] ?? '📍').toString();
    final label = (sig['signalLabel'] ?? 'Sinyal').toString();
    final senderName = (sig['senderName'] ?? 'Operatör').toString();
    final canDelete = sig['senderId'] == _myUid || _myRole == 'leader';

    showModalBottomSheet(
      context: context,
      backgroundColor: TacticalStyles.kSurfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TacticalStyles.headline(
                          color: TacticalStyles.kOnSurface,
                          size: 17,
                        ),
                      ),
                      Text(
                        'Gönderen: $senderName',
                        style: TacticalStyles.body(
                          color: TacticalStyles.kOnSurfaceVariant,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canDelete) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TacticalStyles.kError,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('teams')
                        .doc(_teamId)
                        .collection('messages')
                        .doc(docId)
                        .delete();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'BU SİNYALİ HARİTADAN KALDIR',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSignalBar() {
    final signals = [
      {'code': 'camp', 'label': 'Kamp Kuruldu', 'emoji': '⛺', 'color': TacticalStyles.kTertiary},
      {'code': 'water', 'label': 'Su Bulundu', 'emoji': '💧', 'color': Colors.lightBlueAccent},
      {'code': 'blocked', 'label': 'Geçit Kapalı', 'emoji': '⛔', 'color': TacticalStyles.kError},
      {'code': 'rest', 'label': 'Mola / Yavaşla', 'emoji': '⏸️', 'color': kTOrange},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...signals.map((s) {
            final color = s['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _sendQuickTacticalSignal(
                  s['code'] as String,
                  s['label'] as String,
                  s['emoji'] as String,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSurfaceLow.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s['emoji'] as String, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        s['label'] as String,
                        style: TacticalStyles.labelMicro(
                          color: TacticalStyles.kOnSurface,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _clearMyTacticalSignals,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TacticalStyles.kError.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: TacticalStyles.kError.withOpacity(0.55)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_clear_rounded, color: TacticalStyles.kError, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    'Pinleri Kaldır',
                    style: TacticalStyles.labelMicro(
                      color: TacticalStyles.kError,
                      size: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').where('type', isEqualTo: 'tactical_signal').snapshots(),
              builder: (ctx, signalSnap) {
                final userDocs = usersSnap.data?.docs ?? [];
                final evidenceDocs = evidenceSnap.data?.docs ?? [];
                final signalDocs = signalSnap.data?.docs ?? [];

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
              width: 100,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  showDialog(context: context, builder: (_) => Dialog(
                    backgroundColor: kTCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.yellow, width: 2)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (evData['image'] != null && evData['image'].toString().startsWith('base64:'))
                          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: Image.memory(base64Decode(evData['image'].toString().substring(7))))
                        else if (evData['image'] != null && evData['image'].toString().isNotEmpty)
                          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: Image.network(evData['image'].toString())),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text('📸 BULGU / DELİL', style: TextStyle(color: Colors.yellow, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Text('Gönderen: ${evData['senderName']}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                        if (evData['senderId'] == _myUid || _myRole == 'leader')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8), foregroundColor: Colors.white),
                              onPressed: () {
                                FirebaseFirestore.instance.collection('teams').doc(_teamId).collection('messages').doc(evDoc.id).delete();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Delili Sil'),
                            ),
                          )
                      ]
                    )
                  ));
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade800,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.yellow.withOpacity(0.6), blurRadius: 10, spreadRadius: 3),
                        ],
                      ),
                      child: const Icon(Icons.saved_search, color: Colors.black, size: 22),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.yellow.shade800, width: 1.5),
                      ),
                      child: Text(
                        'DELİL: ${evData['senderName']?.split(' ')[0] ?? ''}',
                        style: const TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            ));
          }
        }

        // Taktiksel Hızlı Durum Pinleri
        for (final sigDoc in signalDocs) {
          final sig = sigDoc.data() as Map<String, dynamic>;
          final sLat = (sig['lat'] as num?)?.toDouble();
          final sLng = (sig['lng'] as num?)?.toDouble();
          if (sLat == null || sLng == null) continue;
          final emoji = (sig['signalEmoji'] ?? '📍').toString();
          final sLabel = (sig['signalLabel'] ?? 'Sinyal').toString();
          markers.add(
            Marker(
              point: LatLng(sLat, sLng),
              width: 118,
              height: 56,
              child: GestureDetector(
                onTap: () => _showSignalOptionsSheet(sigDoc.id, sig),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TacticalStyles.kSurfaceLowest.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: TacticalStyles.kPrimary.withOpacity(0.75)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '$emoji $sLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TacticalStyles.labelMicro(color: Colors.white, size: 9.5),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.close_rounded, size: 10, color: Colors.white54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

            // Harita merkezi: Öncelikle kullanıcının kendi konumu
            LatLng center = _myLatLng ?? const LatLng(39.0, 35.0);
            if (_myLatLng == null && markers.isNotEmpty) {
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
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: _myLatLng != null ? 14.5 : (markers.length > 1 ? 5.0 : 13.0),
                          onMapReady: () {
                            if (_myLatLng != null) {
                              try {
                                _mapController.move(_myLatLng!, 14.5);
                              } catch (_) {}
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _isPremiumUser 
                                ? 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1Ijoic2VyY2Fub3JhbGwiLCJhIjoiY21vdGxneTR1MDZkNjJ1czl5OG4xZGRtNSJ9.aZd3CyiISCcxlcR0hXkhhQ'
                                : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
                            userAgentPackageName: 'com.rotaplus',
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
                      // Hızlı Taktiksel Durum Kodları (1-Tap Team Signals)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: _buildQuickSignalBar(),
                      ),
                      // Canlı badge
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_myRole == 'leader' || _myUid == teamGuideUid)
                              GestureDetector(
                                onTap: _resetTeamMap,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: TacticalStyles.kSurfaceLow.withOpacity(0.86),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: TacticalStyles.kError.withOpacity(0.45),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.refresh_rounded,
                                        color: TacticalStyles.kError,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'HARİTAYI SIFIRLA',
                                        style: TacticalStyles.monoLabel(
                                          color: TacticalStyles.kError,
                                          size: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: TacticalStyles.kSurfaceLow.withOpacity(0.86),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: TacticalStyles.kTertiary.withOpacity(0.45),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: TacticalStyles.kTertiary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: TacticalStyles.kTertiary.withOpacity(0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CANLI',
                                    style: TacticalStyles.monoLabel(
                                      color: TacticalStyles.kTertiary,
                                      size: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Ekip kodu overlay
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: TacticalStyles.kSurfaceLow.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: TacticalStyles.kOutlineVariant),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                color: TacticalStyles.kPrimaryContainer,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _teamName ?? _teamId ?? '',
                                style: TacticalStyles.monoLabel(
                                  color: TacticalStyles.kTextPrimary,
                                  size: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ACİL DURUM BANNERI
                      if (anySos)
                        Positioned(
                          top: 50,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: TacticalStyles.kErrorContainer.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: TacticalStyles.kError),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'ACİL DURUM: $sosName yardım bekliyor',
                                    style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Üye listesi (Aktif Operatifler — Tactical Liquid Glass Carousel)
                Container(
                  height: 168,
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(
                    color: TacticalStyles.kSurface,
                    border: Border(
                      top: BorderSide(color: TacticalStyles.kGlassBorder),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AKTİF OPERATİFLER (${userDocs.length})',
                              style: TacticalStyles.labelCaps(
                                color: TacticalStyles.kOnSurfaceVariant,
                                size: 10,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.cell_tower_rounded,
                                  color: TacticalStyles.kSecondaryContainer,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'MESH AĞI AKTİF',
                                  style: TacticalStyles.telemetry(
                                    color: TacticalStyles.kSecondaryContainer,
                                    size: 9.5,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: userDocs.isEmpty
                            ? Center(
                                child: Text(
                                  'Henüz konum paylaşan üye yok',
                                  style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                                    color: TacticalStyles.kTextSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                children: memberCards,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
              },
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
            if (isGuide) Text('REHBER', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            if (isRecording && !isSOS) Text('• TAKİPTE', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTGreen, fontSize: 8, fontWeight: FontWeight.w700)),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: mainColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withOpacity(isSOS ? 0.4 + (0.4 * _pulseController.value) : 0.35),
                    blurRadius: isSOS ? 8 + (10 * _pulseController.value) : 6,
                    spreadRadius: isSOS ? (3 * _pulseController.value) : 0,
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
                color: TacticalStyles.kSurfaceLowest,
                borderRadius: BorderRadius.circular(4),
                border: isSOS ? Border.all(color: Colors.redAccent) : Border.all(color: TacticalStyles.kOutlineVariant),
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
    
    final Color borderColor = isSOS
        ? TacticalStyles.kError
        : (isMe
            ? TacticalStyles.kTertiary.withOpacity(0.55)
            : (isRecording
                ? TacticalStyles.kPrimaryContainer.withOpacity(0.5)
                : TacticalStyles.kOutlineVariant));

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: uid))),
      child: Container(
        width: 175,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TacticalStyles.kSurfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isMe || isRecording || isSOS ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: TacticalStyles.kPrimaryContainer.withOpacity(0.2),
                  backgroundImage: imgProv,
                  child: imgProv == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: TacticalStyles.kPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.split(' ').first,
                        style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], 
                          color: isSOS
                              ? TacticalStyles.kError
                              : (isMe
                                  ? TacticalStyles.kTertiary
                                  : TacticalStyles.kTextPrimary),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isSOS
                            ? 'CANLI SOS'
                            : (isMe
                                ? 'BEN • AKTİF'
                                : (isGuide ? 'REHBER' : 'ÜYE')),
                        style: TacticalStyles.monoLabel(
                          color: isSOS
                              ? TacticalStyles.kError
                              : (isMe
                                  ? TacticalStyles.kTertiary
                                  : TacticalStyles.kPrimary),
                          size: 8.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (lat != null && lng != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${lat.toStringAsFixed(3)}°N ${lng.toStringAsFixed(3)}°E',
                      style: TacticalStyles.monoValue(
                        color: TacticalStyles.kTextSecondary,
                        size: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (elevation != null && elevation > 0)
                    Text(
                      '${elevation.toInt()}m',
                      style: TacticalStyles.monoValue(
                        color: TacticalStyles.kSecondaryContainer,
                        size: 9.5,
                      ),
                    ),
                ],
              )
            else
              Text(
                'KONUM BEKLENİYOR',
                style: TacticalStyles.monoLabel(
                  color: TacticalStyles.kTextSecondary.withOpacity(0.6),
                  size: 8.5,
                ),
              ),
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
        backgroundColor: TacticalStyles.kSurfaceLowest,
        title: Text('EKİP', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontWeight: FontWeight.w800, fontSize: 18)),
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
                  color: kTOrange.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: kTOrange.withOpacity(0.25)),
                ),
                child: const Icon(Icons.groups_2_outlined, color: kTOrange, size: 60),
              ),
              const SizedBox(height: 28),
              Text('Ekibiniz Yok', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                'Bir ekip kurarak ya da mevcut bir ekibe katılarak ekibinizle anlık konum paylaşabilir ve grup mesajlaşması yapabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 14, height: 1.6),
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
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: Text('YENİ EKİP KUR', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
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
                  label: Text('EKİBE KATIL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w700, fontSize: 16)),
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
            Text('Canlı Takım Radarı', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Ekip üyelerinizin mesafe ve yönlerini çevrimdışı pusula teknolojisiyle radar üzerinden takip etmek için Rota+ Premium\'a geçin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kTOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => PremiumService.showPremiumRequired(context, 'Canlı Takım Radarı'),
              icon: const Icon(Icons.stars, color: Colors.white),
              label: Text('PREMIUM DESTEĞİ AL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
                                  Text("Sizin konumunuz aranıyor...", style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white54)),
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
                                  Text("GPS konumu alınamıyor.\nLütfen konumunuzu açın veya hareket edin.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white54)),
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
        
        Color dotColor = isSOS ? TacticalStyles.kError : kTOrange;

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
                      boxShadow: [BoxShadow(color: dotColor.withOpacity(0.5), blurRadius: isSOS ? 6 : 3)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: TacticalStyles.kSurfaceLowest.withOpacity(0.9), borderRadius: BorderRadius.circular(6), border: Border.all(color: isSOS ? TacticalStyles.kError : TacticalStyles.kOutlineVariant)),
                    child: Text(
                      isSOS ? '🔥 SOS\n${name.split(' ').first}\n${distance.toInt()}m$altStr' : '${name.split(' ').first}\n${distance.toInt()}m$altStr', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 9, fontWeight: isSOS ? FontWeight.w700 : FontWeight.w600)
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
              border: Border.all(color: kTGreen.withOpacity(0.3), width: 1.5),
            ),
          ),
          Container(width: MediaQuery.of(context).size.width * 0.6, height: MediaQuery.of(context).size.width * 0.6, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kTGreen.withOpacity(0.2), width: 1))),
          Container(width: MediaQuery.of(context).size.width * 0.3, height: MediaQuery.of(context).size.width * 0.3, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kTGreen.withOpacity(0.1), width: 1))),
          // Hedef (Biz)
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: kTGreen, shape: BoxShape.circle)),
          // Çapraz çizgiler
          Container(width: 1, height: MediaQuery.of(context).size.width * 0.9, color: kTGreen.withOpacity(0.2)),
          Container(height: 1, width: MediaQuery.of(context).size.width * 0.9, color: kTGreen.withOpacity(0.2)),
          // Pusula yönleri
          Positioned(top: MediaQuery.of(context).size.height * 0.05, child: Text('K', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTGreen, fontWeight: FontWeight.w800))),
          Positioned(bottom: MediaQuery.of(context).size.height * 0.05, child: Text('G', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTGreen, fontWeight: FontWeight.w800))),
          Positioned(right: MediaQuery.of(context).size.width * 0.05, child: Text('D', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTGreen, fontWeight: FontWeight.w800))),
          Positioned(left: MediaQuery.of(context).size.width * 0.05, child: Text('B', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTGreen, fontWeight: FontWeight.w800))),
          
          // Radar Dalgası Animasyonu
          AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, child) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.9 * _pulseController.value,
                height: MediaQuery.of(context).size.width * 0.9 * _pulseController.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kTGreen.withOpacity(1.0 - _pulseController.value), width: 1.5),
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
          color: TacticalStyles.kSurfaceLow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: TacticalStyles.kOutlineVariant, width: 1)),
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
                    : const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                      Row(
                        children: [
                          if (isGuide) Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: kTOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: kTOrange)),
                            child: Text('REHBER', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                          Text(isSOS ? 'DURUM: KRİTİK (SOS)' : (isRecording ? 'DURUM: ROTA TAKİBİNDE' : 'DURUM: AKTİF'), style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: isSOS ? TacticalStyles.kError : (isRecording ? kTGreen : Colors.white38), fontSize: 10, fontWeight: FontWeight.w600)),
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
              decoration: BoxDecoration(color: TacticalStyles.kSurfaceLowest, borderRadius: BorderRadius.circular(12), border: Border.all(color: TacticalStyles.kOutlineVariant)),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: kTGreen, size: 14),
                      const SizedBox(width: 8),
                      const Text('BAŞLANGIÇ:', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(startName, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.flag, color: kTOrange, size: 14),
                      const SizedBox(width: 8),
                      const Text('GÜNCEL HEDEF:', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(endName, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
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
              decoration: BoxDecoration(color: TacticalStyles.kSurfaceLowest, borderRadius: BorderRadius.circular(12), border: Border.all(color: TacticalStyles.kOutlineVariant)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: TacticalStyles.kSurfaceHigh, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isMe ? null : () async {
                      Navigator.pop(context);
                      // Takip Et Rota Çizme
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Rota hesaplanıyor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
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
                            color: TacticalStyles.kSecondaryContainer,
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
                    style: ElevatedButton.styleFrom(backgroundColor: kTOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
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
        Text(value, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTGreen, fontSize: 12, fontWeight: FontWeight.w700)),
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
                  Text('EKİP BİLGİSİ', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kTOrange, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
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
                                  decoration: BoxDecoration(color: kTCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: isLeader ? kTOrange.withOpacity(0.3) : TacticalStyles.kOutlineVariant)),
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
    final bool hasAlert = assistanceCount > 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TacticalStyles.kSurfaceContainer.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasAlert
              ? TacticalStyles.kPrimaryContainer.withOpacity(0.45)
              : TacticalStyles.kTertiary.withOpacity(0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: hasAlert ? TacticalStyles.kPrimaryContainer : TacticalStyles.kTertiary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (hasAlert ? TacticalStyles.kPrimaryContainer : TacticalStyles.kTertiary).withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EKİP GÜVENLİK DURUMU',
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kOnSurface,
                      size: 10,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasAlert
                      ? TacticalStyles.kPrimaryContainer.withOpacity(0.18)
                      : TacticalStyles.kTertiary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasAlert
                        ? TacticalStyles.kPrimaryContainer.withOpacity(0.45)
                        : TacticalStyles.kTertiary.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  hasAlert ? '$assistanceCount KRİTİK SİNYAL' : 'HERKES GÜVENDE',
                  style: TacticalStyles.telemetry(
                    color: hasAlert ? TacticalStyles.kPrimary : TacticalStyles.kTertiary,
                    size: 9,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusIndicator('GÜVENDE', safeCount, totalCount, TacticalStyles.kTertiary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusIndicator('KRİTİK', assistanceCount, totalCount, TacticalStyles.kPrimaryContainer),
              ),
              const SizedBox(width: 10),
              // Kendi durumunu güncelleme
              Row(
                children: [
                  _buildMyStatusButton(
                    icon: Icons.check_circle_outline_rounded,
                    color: TacticalStyles.kTertiary,
                    isActive: myStatus == kStatusSafe,
                    onTap: () => _updateMySafetyStatus(kStatusSafe),
                  ),
                  const SizedBox(width: 8),
                  _buildMyStatusButton(
                    icon: Icons.warning_amber_rounded,
                    color: TacticalStyles.kPrimaryContainer,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: TacticalStyles.kSurfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TacticalStyles.labelMicro(
                  color: color,
                  size: 8.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.spaceGrotesk(
                      color: TacticalStyles.kOnSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    '/$total',
                    style: TacticalStyles.telemetry(
                      color: TacticalStyles.kOutline,
                      size: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Icon(
            label == 'GÜVENDE' ? Icons.verified_user_rounded : Icons.emergency_share_rounded,
            color: color.withOpacity(0.5),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatusButton({required IconData icon, required Color color, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : TacticalStyles.kSurfaceLowest,
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? color : Colors.white.withOpacity(0.08)),
          boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : null,
        ),
        child: Icon(icon, color: isActive ? color : TacticalStyles.kTextSecondary, size: 19),
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

