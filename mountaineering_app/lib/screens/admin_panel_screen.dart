import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kCardBg = Color(0xFF141414);
  static const Color kGreen = Color(0xFF62FF4C);

  late TabController _tabController;

  // Duyuru
  final TextEditingController _duyuruBaslikCtrl = TextEditingController();
  final TextEditingController _duyuruIcerikCtrl = TextEditingController();
  String _duyuruSeviye = 'normal'; // normal | warning | critical
  bool _duyuruGonderiyor = false;

  // Stats
  int _totalUsers = 0;
  int _premiumUsers = 0;
  int _totalPosts = 0;

  // Data
  List<QueryDocumentSnapshot> _users = [];
  List<QueryDocumentSnapshot> _posts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Map markers (real user locations)
  List<Map<String, dynamic>> _liveMarkers = [];
  List<QueryDocumentSnapshot> _guideApps = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _duyuruBaslikCtrl.dispose();
    _duyuruIcerikCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadUsers(), _loadPosts(), _loadMapData(), _loadGuideApps()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('kayit_tarihi', descending: true)
          .get();
      if (!mounted) return;
      setState(() {
        _users = snap.docs;
        _totalUsers = snap.docs.length;
        _premiumUsers = snap.docs.where((d) => d.data()['is_premium'] == true).length;
      });
    } catch (e) {
      // Try without ordering if index missing
      try {
        final snap = await FirebaseFirestore.instance.collection('users').get();
        if (!mounted) return;
        setState(() {
          _users = snap.docs;
          _totalUsers = snap.docs.length;
          _premiumUsers = snap.docs.where((d) => d.data()['is_premium'] == true).length;
        });
      } catch (_) {}
    }
  }

  Future<void> _loadPosts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .get();
      if (!mounted) return;
      setState(() {
        _posts = snap.docs;
        _totalPosts = snap.docs.length;
      });
    } catch (_) {}
  }

  Future<void> _loadMapData() async {
    final List<Map<String, dynamic>> markers = [];
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        // Try sub-collection last location
        try {
          final locSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(doc.id)
              .collection('location_history')
              .orderBy('cihaz_senkronizasyon_saati', descending: true)
              .limit(1)
              .get();
          if (locSnap.docs.isNotEmpty) {
            final loc = locSnap.docs.first.data();
            final lat = (loc['enlem'] as num?)?.toDouble();
            final lng = (loc['boylam'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              markers.add({
                'lat': lat,
                'lng': lng,
                'name': data['name'] ?? 'Kullanıcı',
                'is_premium': data['is_premium'] ?? false,
                'is_online': data['is_online'] ?? false,
                'pic': data['profile_pic_url'] ?? '',
              });
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _liveMarkers = markers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('ROTA+ ADMİN',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 16, color: kOrange)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAll,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : Column(
              children: [
                // Stat Cards
                Container(
                  padding: const EdgeInsets.all(12),
                  color: kBackground,
                  child: Column(
                    children: [
                      Row(children: [
                        _buildStatCard('KULLANICI', _totalUsers.toString(), Icons.people, Colors.blue),
                        const SizedBox(width: 10),
                        _buildStatCard('PREMİUM', _premiumUsers.toString(), Icons.star, Colors.amber),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _buildStatCard('GÖNDERI', _totalPosts.toString(), Icons.article, Colors.green),
                        const SizedBox(width: 10),
                        _buildStatCard('CANLI', _liveMarkers.where((m) => m['is_online'] == true).length.toString(), Icons.location_on, Colors.redAccent),
                      ]),
                    ],
                  ),
                ),

                // TabBar
                Container(
                  color: Colors.black,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: kOrange,
                    labelColor: kOrange,
                    unselectedLabelColor: Colors.white38,
                    isScrollable: true,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    tabs: const [
                      Tab(icon: Icon(Icons.people, size: 18), text: 'KULLANICILAR'),
                      Tab(icon: Icon(Icons.article, size: 18), text: 'GÖNDERİLER'),
                      Tab(icon: Icon(Icons.map, size: 18), text: 'CANLI HARİTA'),
                      Tab(icon: Icon(Icons.verified_user, size: 18), text: 'BAŞVURULAR'),
                      Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'İSTATİSTİK'),
                      Tab(icon: Icon(Icons.campaign, size: 18), text: 'DUYURULAR'),
                      Tab(icon: Icon(Icons.report, size: 18), text: 'ŞİKAYETLER'),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUsersTab(),
                      _buildPostsTab(),
                      _buildLiveMapTab(),
                      _buildGuideAppsTab(),
                      _buildStatsTab(),
                      _buildAnnouncementsTab(),
                      _buildReportsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── USERS TAB ────────────────────────────────────────────────────
  Widget _buildUsersTab() {
    final filtered = _users.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Kullanıcı ara...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: kCardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kOrange)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Icon(Icons.people, color: kOrange, size: 14),
            const SizedBox(width: 6),
            Text('${filtered.length} kullanıcı', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final doc = filtered[i];
              final data = doc.data() as Map<String, dynamic>;
              final isAdmin = data['is_admin'] == true;
              final isPremium = data['is_premium'] == true;
              final isOnline = data['is_online'] == true;
              final name = data['name'] ?? 'Kullanıcı';
              final email = data['email'] ?? '';
              final pic = data['profile_pic_url'] ?? '';
              final Timestamp? kayit = data['kayit_tarihi'];
              final roles = (data['roles'] as List<dynamic>?) ?? [];

              return GestureDetector(
                onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: doc.id))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAdmin ? kOrange.withOpacity(0.08) : kCardBg,
                    border: Border.all(color: isAdmin ? kOrange.withOpacity(0.3) : Colors.white10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: kOrange.withOpacity(0.2),
                            backgroundImage: pic.startsWith('base64:')
                                ? MemoryImage(base64Decode(pic.substring(7))) as ImageProvider
                                : (pic.isNotEmpty ? NetworkImage(pic) as ImageProvider : null),
                            child: pic.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold)) : null,
                          ),
                          if (isOnline)
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 11, height: 11,
                                decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              if (isAdmin) _badge('ADMİN', kOrange),
                              if (isPremium && !isAdmin) _badge('PREMIUM', Colors.amber),
                              ...roles.where((r) => r != 'Admin' && r != 'Premium').map((r) => _badge(r.toString(), Colors.purpleAccent)),
                            ]),
                            Text(email, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            if (kayit != null)
                              Text('Kayıt: ${_formatTs(kayit)}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        color: const Color(0xFF1A1A1A),
                        icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                        onSelected: (v) => _userAction(doc.id, v, isPremium, isAdmin, name),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(value: 'premium', child: Row(children: [Icon(isPremium ? Icons.star_border : Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 8), Text(isPremium ? "Premium'u Kaldır" : 'Premium Yap', style: const TextStyle(color: Colors.white))])),
                          const PopupMenuItem(value: 'badge', child: Row(children: [Icon(Icons.badge, color: Colors.purpleAccent, size: 18), SizedBox(width: 8), Text('Rozet Düzenle', style: TextStyle(color: Colors.white))])),
                          const PopupMenuItem(value: 'admin', child: Row(children: [Icon(Icons.shield, color: kOrange, size: 18), SizedBox(width: 8), Text('Admin Yap/Kaldır', style: TextStyle(color: Colors.white))])),
                          PopupMenuItem(value: 'sil', child: Row(children: [const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), const SizedBox(width: 8), Text(name + ' Sil', style: const TextStyle(color: Colors.redAccent))])),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _userAction(String uid, String action, bool isPremium, bool isAdmin, String name) async {
    if (action == 'premium') {
      final newStatus = !isPremium;
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final currentRoles = List<String>.from(doc.data()?['roles'] ?? []);
        
        if (newStatus) {
          if (!currentRoles.contains('Premium')) currentRoles.add('Premium');
        } else {
          currentRoles.remove('Premium');
        }

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'is_premium': newStatus,
          'is_premium_fixed': newStatus,
          'roles': currentRoles,
          if (newStatus) 'premium_expiry': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3650))) // 10 Yıllık Premium
          else 'premium_expiry': FieldValue.delete(),
        });
        
        _showSnack(newStatus ? '✓ $name premium yapıldı (10 Yıllık + Sabit)!' : 'Premium kaldırıldı.');
        _loadUsers();
      } catch (e) {
        _showSnack('Hata oluştu: $e', error: true);
      }
    } else if (action == 'admin') {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'is_admin': !isAdmin});
      _showSnack(isAdmin ? 'Admin yetkisi kaldırıldı.' : '✓ $name admin yapıldı!');
      _loadUsers();
    } else if (action == 'badge') {
      _showBadgeDialog(uid, name);
    } else if (action == 'sil') {
      final conf = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCardBg,
          title: Text('$name Silinsin mi?', style: const TextStyle(color: Colors.white)),
          content: const Text('Firestore kaydı silinecek.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900), onPressed: () => Navigator.pop(ctx, true), child: const Text('SİL')),
          ],
        ),
      );
      if (conf == true) {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        _showSnack('Kullanıcı silindi.');
        _loadUsers();
      }
    }
  }

  void _showBadgeDialog(String uid, String name) async {
    final allBadges = ['VIP', 'Moderatör', 'Rehber', 'Kurtarma Ekibi', 'Doktor', 'Uzman', 'Beta Tester'];
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final current = List<String>.from((doc.data()?['roles'] as List<dynamic>?) ?? []);
    final selected = List<String>.from(current);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: kCardBg,
          title: Text('$name - Rozetler', style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: allBadges.map((b) => CheckboxListTile(
              value: selected.contains(b),
              onChanged: (v) => setS(() { if (v == true) selected.add(b); else selected.remove(b); }),
              title: Text(b, style: const TextStyle(color: Colors.white)),
              activeColor: kOrange,
              checkColor: Colors.black,
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'roles': selected});
                if (ctx.mounted) { Navigator.pop(ctx); _showSnack('✓ Rozetler güncellendi.'); _loadUsers(); }
              },
              child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── POSTS TAB ────────────────────────────────────────────────────
  Widget _buildPostsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (ctx, i) {
        final doc = _posts[i];
        final data = doc.data() as Map<String, dynamic>;
        final user = data['user'] ?? 'Kullanıcı';
        final desc = data['desc'] ?? '';
        final likes = (data['likes'] as List<dynamic>?)?.length ?? 0;
        final Timestamp? ts = data['timestamp'];
        final postType = data['postType'] ?? 'normal';
        final imageUrl = data['imageUrl'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: kOrange.withOpacity(0.15),
              child: postType == 'route'
                  ? const Icon(Icons.route, color: kOrange, size: 18)
                  : (imageUrl.isNotEmpty ? const Icon(Icons.image, color: kOrange, size: 18) : const Icon(Icons.article, color: kOrange, size: 18)),
            ),
            title: Text(user, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Row(children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 12),
                  const SizedBox(width: 3),
                  Text('$likes', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(width: 10),
                  if (ts != null) Text(_formatTs(ts), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                ]),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () async {
                final conf = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: kCardBg,
                    title: const Text('Gönderiyi Sil', style: TextStyle(color: Colors.white)),
                    content: Text('"$user" kullanıcısının gönderisi silinsin mi?', style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL')),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900), onPressed: () => Navigator.pop(ctx, true), child: const Text('SİL')),
                    ],
                  ),
                );
                if (conf == true) {
                  await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
                  _showSnack('Gönderi silindi.');
                  _loadPosts();
                }
              },
            ),
          ),
        );
      },
    );
  }

  // ── LIVE MAP TAB ─────────────────────────────────────────────────
  Widget _buildLiveMapTab() {
    final onlineCount = _liveMarkers.where((m) => m['is_online'] == true).length;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: kCardBg,
          child: Row(children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('$onlineCount çevrimiçi kullanıcı  ·  ${_liveMarkers.length} konum kaydı',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: _loadMapData,
              child: const Icon(Icons.refresh, color: Colors.white38, size: 18),
            ),
          ]),
        ),
        Expanded(
          child: _liveMarkers.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_off, color: Colors.white12, size: 48),
                  const SizedBox(height: 12),
                  const Text('Henüz konum verisi yok.\nKullanıcılar konum paylaşırsa burada görünür.', style: TextStyle(color: Colors.white30, fontSize: 12), textAlign: TextAlign.center),
                ]))
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _liveMarkers.isNotEmpty
                        ? LatLng(_liveMarkers.first['lat'], _liveMarkers.first['lng'])
                        : const LatLng(39.5, 34.5),
                    initialZoom: _liveMarkers.length == 1 ? 10.0 : 6.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.rota_plus.mountaineering.app',
                    ),
                    MarkerLayer(
                      markers: _liveMarkers.map((m) {
                        final isOnline = m['is_online'] == true;
                        return Marker(
                          point: LatLng(m['lat'], m['lng']),
                          width: 48,
                          height: 58,
                          child: GestureDetector(
                            onTap: () => _showMarkerInfo(context, m),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: isOnline ? kGreen.withOpacity(0.2) : kOrange.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isOnline ? kGreen : kOrange, width: 2),
                                    ),
                                    child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 18),
                                  ),
                                  if (isOnline)
                                    Positioned(
                                      top: 0, right: 0,
                                      child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                                    ),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                  child: Text(m['name'].toString().split(' ').first, style: const TextStyle(color: Colors.white, fontSize: 8)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          color: kCardBg,
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.white24, size: 14),
            SizedBox(width: 8),
            Expanded(child: Text('Kullanıcıların gerçek son konumları gösterilmektedir. Yeşil = çevrimiçi, Turuncu = çevrimdışı.',
                style: TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic))),
          ]),
        ),
      ],
    );
  }

  void _showMarkerInfo(BuildContext ctx, Map<String, dynamic> m) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: m['is_online'] == true ? Colors.greenAccent : Colors.white38, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(m['name'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            if (m['is_premium'] == true) _badge('PREMIUM', Colors.amber),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.location_on, color: kOrange, size: 14),
            const SizedBox(width: 6),
            Text('${m['lat'].toStringAsFixed(5)}, ${m['lng'].toStringAsFixed(5)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Text(m['is_online'] == true ? '🟢 Şu an çevrimiçi' : '⚫ Çevrimdışı', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
    );
  }

  // ── GUIDE APPS TAB ──────────────────────────────────────────────
  Widget _buildGuideAppsTab() {
    if (_guideApps.isEmpty) {
      return const Center(child: Text('Bekleyen başvuru bulunamadı.', style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _guideApps.length,
      itemBuilder: (ctx, i) {
        final doc = _guideApps[i];
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Kullanıcı';
        final email = data['email'] ?? '';
        final status = data['status'] ?? 'pending';
        final isPdf = data['is_pdf'] == true;
        final base64Cert = data['certificate_base64'] ?? '';
        final fileName = data['file_name'] ?? 'belge.png';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: status == 'pending' ? kOrange.withOpacity(0.3) : Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: kOrange.withOpacity(0.1), child: Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: kOrange, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(email, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ]),
                  ),
                  _badge(status.toUpperCase(), status == 'approved' ? kGreen : (status == 'rejected' ? Colors.redAccent : Colors.amber)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              Text('Dosya: $fileName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, padding: const EdgeInsets.symmetric(vertical: 8)),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('DOSYAYI GÖR', style: TextStyle(fontSize: 11)),
                      onPressed: () => _viewCertificate(name, base64Cert, isPdf),
                    ),
                  ),
                  if (status == 'pending') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: kGreen),
                      onPressed: () => _processGuideApp(doc.id, data['uid'], true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      onPressed: () => _processGuideApp(doc.id, data['uid'], false),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewCertificate(String name, String base64Data, bool isPdf) {
    if (base64Data.startsWith('base64:')) base64Data = base64Data.substring(7);
    final bytes = base64Decode(base64Data);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(name + ' - Sertifika', style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: isPdf
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 64), SizedBox(height: 16), Text('PDF içeriği burada gösterilecek (PDF Viewer entegrasyonu gerekir)', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)]))
              : InteractiveViewer(child: Image.memory(bytes)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT'))],
      ),
    );
  }

  void _processGuideApp(String appId, String userUid, bool approved) async {
    try {
      if (approved) {
        // Kullanıcıya REHBER rozeti ekle
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userUid).get();
        List roles = List.from((userDoc.data()?['roles'] as List?) ?? []);
        if (!roles.contains('Rehber')) roles.add('Rehber');
        await FirebaseFirestore.instance.collection('users').doc(userUid).update({'roles': roles});
      }
      
      await FirebaseFirestore.instance.collection('guide_applications').doc(appId).update({
        'status': approved ? 'approved' : 'rejected',
      });
      
      _showSnack(approved ? '✓ Başvuru onaylandı!' : 'Başvuru reddedildi.');
      _loadGuideApps();
      _loadUsers();
    } catch (e) {
      _showSnack('İşlem başarısız: $e', error: true);
    }
  }

  // ── ANNOUNCEMENTS TAB ──────────────────────────────────────────────
  Widget _buildAnnouncementsTab() {
    return Column(
      children: [
        // ── Duyuru Oluşturma Formu ──────────────────────────────────
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kOrange.withOpacity(0.3)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setS) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign, color: kOrange, size: 20),
                    const SizedBox(width: 8),
                    Text('Yeni Duyuru',
                        style: GoogleFonts.outfit(
                            color: kOrange, fontWeight: FontWeight.w900, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                // Başlık
                TextField(
                  controller: _duyuruBaslikCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Duyuru başlığı...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kOrange)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                // İçerik
                TextField(
                  controller: _duyuruIcerikCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Duyuru içeriği...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kOrange)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 10),
                // Seviye Seçimi
                Row(
                  children: [
                    const Text('Seviye: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 8),
                    for (final sev in [
                      ('normal', Colors.blue, Icons.info_outline),
                      ('warning', Colors.amber, Icons.warning_amber_outlined),
                      ('critical', Colors.redAccent, Icons.error_outline),
                    ])
                      GestureDetector(
                        onTap: () => setS(() => _duyuruSeviye = sev.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _duyuruSeviye == sev.$1
                                ? sev.$2.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _duyuruSeviye == sev.$1
                                  ? sev.$2
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sev.$3, color: sev.$2, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                sev.$1.toUpperCase(),
                                style: TextStyle(
                                    color: sev.$2, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _duyuruGonderiyor
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.black, size: 18),
                    label: Text(
                      _duyuruGonderiyor ? 'GÖNDERİLİYOR...' : 'DUYURUYU YAYINLA',
                      style: GoogleFonts.outfit(
                          color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    onPressed: _duyuruGonderiyor ? null : () => _duyuruYayinla(setS),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Mevcut Duyurular ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.list_alt, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text('Mevcut Duyurular',
                  style: GoogleFonts.outfit(
                      color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kOrange));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Henüz duyuru yok.',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final sev = d['level'] ?? 'normal';
                  final Color sevColor = sev == 'critical'
                      ? Colors.redAccent
                      : sev == 'warning'
                          ? Colors.amber
                          : Colors.blue;
                  final IconData sevIcon = sev == 'critical'
                      ? Icons.error_outline
                      : sev == 'warning'
                          ? Icons.warning_amber_outlined
                          : Icons.info_outline;
                  final Timestamp? ts = d['timestamp'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sevColor.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sevColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(sevIcon, color: sevColor, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['title'] ?? '',
                                  style: TextStyle(
                                      color: sevColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              if ((d['body'] ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(d['body'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                ),
                              if (ts != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(_formatTs(ts),
                                      style: const TextStyle(
                                          color: Colors.white24, fontSize: 10)),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('announcements')
                                .doc(docs[i].id)
                                .delete();
                            _showSnack('Duyuru silindi.');
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _duyuruYayinla(StateSetter setS) async {
    final baslik = _duyuruBaslikCtrl.text.trim();
    final icerik = _duyuruIcerikCtrl.text.trim();
    if (baslik.isEmpty) {
      _showSnack('Başlık boş olamaz!', error: true);
      return;
    }
    setS(() => _duyuruGonderiyor = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': baslik,
        'body': icerik,
        'level': _duyuruSeviye,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _duyuruBaslikCtrl.clear();
      _duyuruIcerikCtrl.clear();
      _showSnack('✓ Duyuru yayınlandı!');
    } catch (e) {
      _showSnack('Hata: $e', error: true);
    } finally {
      setS(() => _duyuruGonderiyor = false);
    }
  }

  // ── STATS TAB ────────────────────────────────────────────────────
  Widget _buildStatsTab() {
    final premiumPct = _totalUsers > 0 ? (_premiumUsers / _totalUsers * 100).toStringAsFixed(1) : '0';
    final onlineNow = _liveMarkers.where((m) => m['is_online'] == true).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatSection('📊 Kullanıcı İstatistikleri', [
          _statRow('Toplam Kullanıcı', '$_totalUsers'),
          _statRow('Premium Üye', '$_premiumUsers (%$premiumPct)'),
          _statRow('Şu An Çevrimiçi', '$onlineNow'),
          _statRow('Konum Verisi Olan', '${_liveMarkers.length}'),
        ]),
        const SizedBox(height: 16),
        _buildStatSection('📝 İçerik İstatistikleri', [
          _statRow('Toplam Gönderi', '$_totalPosts'),
          _statRow('Rota Paylaşımı', '${_posts.where((d) => (d.data() as Map)['postType'] == 'route').length}'),
          _statRow('Fotoğraflı Gönderi', '${_posts.where((d) => ((d.data() as Map)['imageUrl'] ?? '').toString().isNotEmpty).length}'),
        ]),
        const SizedBox(height: 16),
        _buildStatSection('🌍 Platform', [
          _statRow('Firestore Koleksiyonları', 'users, posts, chats, notifications'),
          _statRow('Veri Kaynağı', '☁️ Firebase Firestore (Gerçek Zamanlı)'),
        ]),
      ],
    );
  }

  Widget _buildStatSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const Divider(height: 1, color: Colors.white10),
          ...children,
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────
  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color, size: 18), const Spacer(), if (value != '0') Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))]),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formatTs(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadGuideApps() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('guide_applications').orderBy('timestamp', descending: true).get();
      if (!mounted) return;
      setState(() => _guideApps = snap.docs);
    } catch (_) {
      try {
        final snap = await FirebaseFirestore.instance.collection('guide_applications').get();
        if (!mounted) return;
        setState(() => _guideApps = snap.docs);
      } catch (_) {}
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade900 : const Color(0xFF1E1E1E),
      duration: const Duration(seconds: 2),
    ));
  }
  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Henüz şikayet yok.", style: TextStyle(color: Colors.white54, fontSize: 16)));
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final doc = reports[index];
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? 'unknown';
            final reporter = data['reporter'] ?? '';
            
            bool isPostReport = type == 'report_post';
            
            return Card(
              color: kCardBg,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isPostReport ? Icons.article : Icons.person_off, color: isPostReport ? Colors.orange : Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(isPostReport ? 'GÖNDERİ ŞİKAYETİ' : 'KULLANICI ENGELLEME', style: TextStyle(color: isPostReport ? Colors.orange : Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    Text('Şikayet Eden UID: $reporter', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    if (isPostReport) ...[
                      Text('Şikayet Edilen Post ID: ${data['post_id']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Şikayet Edilen UID: ${data['reported_user']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ] else ...[
                      Text('Engellenen UID: ${data['blocked_user'] ?? data['reported_user'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('reports').doc(doc.id).delete();
                            _showSnack('Rapor silindi/kapatıldı.');
                          },
                          child: const Text('RAPORU SİL', style: TextStyle(color: Colors.white54)),
                        ),
                        const SizedBox(width: 8),
                        if (isPostReport)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                            onPressed: () async {
                              final postId = data['post_id'];
                              if (postId != null) {
                                await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                              }
                              await FirebaseFirestore.instance.collection('reports').doc(doc.id).delete();
                              _showSnack('Gönderi ve rapor silindi!');
                            },
                            icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                            label: const Text('GÖNDERİYİ SİL', style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
