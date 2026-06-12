import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../storage_helper.dart';
import '../database_helper.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';
import 'followers_screen.dart';
import 'notification_screen.dart';
import 'edit_profile_screen.dart';
import '../utils/app_state.dart';
import 'notification_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'admin_panel_screen.dart';
import '../services/ad_service.dart';
import '../widgets/create_post_sheet.dart';

const List<String> _kAdminEmails = ['sercanoral65@gmail.com', 'admin@rota.plus', 'keser.bora@yandex.com'];

class ProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const ProfileScreen({Key? key, this.targetUserId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kCardBg = Color(0xFF141414);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kGreen = Color(0xFF62FF4C);

  String _userName = '';
  String _usernameField = '';
  String _userEmail = '';
  String _bio = 'Doğayı Keşfet 🌲🏔️\nUlaşılmaz zirvelere...';
  String _profilePicUrl = '';
  List<String> _badges = []; // Çoklu badge desteği
  String _badgeTitle = ''; // legacy fallback
  bool _isPremium = false;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = true;
  bool _isNotFound = false;
  bool _emailVisible = false; // email default gizli

  String _affiliationType = '';
  String _affiliationName = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    var name = await StorageHelper.getUserName();
    var email = await StorageHelper.getUserEmail();
    var premium = await StorageHelper.isPremium();

    int followers = 0;
    int following = 0;
    String bioText = 'Doğayı Keşfet 🌲🏔️\nUlaşılmaz zirvelere...';
    String picUrl = '';
    bool emailVisible = false;
    String badgeTitle = '';
    List<String> badges = [];
    String loadedUsername = '';
    String affType = '';
    String affName = '';

    final user = FirebaseAuth.instance.currentUser;
    final String uidToFetch = widget.targetUserId ?? user?.uid ?? '';

    if (uidToFetch.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uidToFetch).get();
        if (doc.exists) {
          if (widget.targetUserId != null) {
            name = doc.data()?['name'];
            email = doc.data()?['email'] ?? '';
            premium = doc.data()?['is_premium'] ?? false;
          } else {
            // Kendi profilimizse kapsamlı premium kontrolü yap
            premium = await AdService.checkPremiumStatus();
          }
          final List? fList = doc.data()?['followers'];
          final List? fgList = doc.data()?['following'];
          followers = fList?.length ?? doc.data()?['followers_count'] ?? 0;
          following = fgList?.length ?? doc.data()?['following_count'] ?? 0;
          bioText = doc.data()?['bio'] ?? bioText;
          final savedPicUrl = doc.data()?['profile_pic_url'] ?? '';
          if (savedPicUrl.isNotEmpty) picUrl = savedPicUrl;

          // Email visibility - her iki durumda da Firestore'dan al
          emailVisible = doc.data()?['email_visible'] ?? false;
          badgeTitle = doc.data()?['role'] ?? 'Yeni Üye';
          loadedUsername = doc.data()?['username'] ?? '';
          affType = doc.data()?['affiliationType'] ?? '';
          affName = doc.data()?['affiliationName'] ?? '';

          // Çoklu badge
          final rawBadges = doc.data()?['roles'];
          if (rawBadges is List) {
            badges = List<String>.from(rawBadges);
          } else if (badgeTitle.isNotEmpty) {
            badges = [badgeTitle];
          }
        } else {
          _isNotFound = true;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _userName = name ?? 'KULLANICI';
        // E-posta sadece aynı kullanıcıysa VE email_visible=true ise say
        if (widget.targetUserId == null) {
          // Kendi profilimiz
          _userEmail = emailVisible ? (email ?? '') : '';
        } else {
          // Başkasının profili
          _userEmail = emailVisible ? (email ?? '') : '';
        }
        _emailVisible = emailVisible;
        _isPremium = premium;
        _followersCount = followers;
        _followingCount = following;
        _bio = bioText;
        _profilePicUrl = picUrl;
        _badgeTitle = badgeTitle;
        _badges = badges;
        _usernameField = loadedUsername;
        _affiliationType = affType;
        _affiliationName = affName;
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameCtrl = TextEditingController(text: _userName);
    final usernameCtrl = TextEditingController(text: _usernameField);
    final bioCtrl = TextEditingController(text: _bio);
    bool tempEmailVisible = _emailVisible;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit, color: kOrange, size: 20),
              const SizedBox(width: 8),
              Text('Profili Düzenle', style: GoogleFonts.outfit(color: kOrange, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogInput(nameCtrl, 'Ad Soyad', Icons.person_outline),
                const SizedBox(height: 12),
                _buildDialogInput(usernameCtrl, 'Kullanıcı Adı (@)', Icons.alternate_email),
                const SizedBox(height: 12),
                _buildDialogInput(bioCtrl, 'Hakkında (Bio)', Icons.info_outline, maxLines: 3),
                const SizedBox(height: 16),
                // Email visibility toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.white38, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('E-posta Görünür', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('Diğerleri e-postanızı görebilir', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: tempEmailVisible,
                        activeColor: kOrange,
                        onChanged: (v) => setDialogState(() => tempEmailVisible = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                String newName = nameCtrl.text.trim();
                String newBio = bioCtrl.text.trim();
                String newUsername = usernameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
                if (newUsername.startsWith('@')) newUsername = newUsername.substring(1);

                if (newUsername.length < 3) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Kullanıcı adı en az 3 karakter olmalıdır!')));
                  return;
                }

                if (newUsername != _usernameField) {
                  final check = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: newUsername).get();
                  if (check.docs.isNotEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Bu kullanıcı adı alınmış!')));
                    return;
                  }
                }

                await StorageHelper.saveUserName(newName.isEmpty ? 'Kullanıcı' : newName);

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'name': newName,
                      'bio': newBio,
                      'username': newUsername,
                      'email_visible': tempEmailVisible,
                    }, SetOptions(merge: true));
                  } catch (_) {}
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _loadProfile();
              },
              child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kOrange)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 500);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final downloadUrl = 'base64:$base64Image';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profile_pic_url': downloadUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _profilePicUrl = downloadUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resim yüklenemedi: $e'), backgroundColor: Colors.red.shade800));
      }
    }
  }

  Widget _buildAvatarFallback() {
    return Container(
      width: 90, height: 90,
      color: kOrange.withOpacity(0.15),
      child: Center(
        child: Text(
          _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
          style: const TextStyle(color: kOrange, fontSize: 36, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _basTutar(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
  }

  bool get _isOwner => _kAdminEmails.contains(_userEmail) || (widget.targetUserId == null && _kAdminEmails.contains(FirebaseAuth.instance.currentUser?.email));
  bool get _viewerIsAdmin => _kAdminEmails.contains(FirebaseAuth.instance.currentUser?.email);

  // Check if viewing own profile
  bool get _isOwnProfile {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return widget.targetUserId == null || widget.targetUserId == currentUid;
  }

  Widget _buildShimmerName(String name) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFF6B00), Color(0xFFFFD700), Color(0xFFFF6B00)],
        stops: [0.0, 0.33, 0.66, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
      ),
    );
  }

  void _openFollowList(String type) {
    final uidToFetch = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uidToFetch != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersScreen(userId: uidToFetch, type: type)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isNotFound) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, color: Colors.white24, size: 80),
              const SizedBox(height: 24),
              Text('HESAP BULUNAMADI', 
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              const Text('Bu kullanıcı artık mevcut değil.', 
                style: TextStyle(color: Colors.white38, fontSize: 14)),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
                onPressed: () => Navigator.pop(context),
                child: const Text('GERİ DÖN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBackground,
        body: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        leading: widget.targetUserId != null 
          ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))
          : null,
        title: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'ROTA+ ',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
              ),
              TextSpan(
                text: _isOwnProfile ? 'PROFİLİM' : 'PROFİL',
                style: const TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 20, fontStyle: FontStyle.italic, letterSpacing: 2),
              ),
            ],
          ),
        ),
        elevation: 0,
        actions: [
          if (widget.targetUserId == null) ...[
            if (_kAdminEmails.contains(FirebaseAuth.instance.currentUser?.email))
              IconButton(
                icon: const Icon(Icons.admin_panel_settings, color: kOrange),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
              ),
            // Bildirim butonu (badge ile)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(FirebaseAuth.instance.currentUser?.uid ?? 'x')
                  .collection('items')
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (ctx, snap) {
                final unread = snap.data?.docs.length ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_box_outlined, color: Colors.white),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CreatePostSheet(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                _loadProfile();
              },
            ),
          ]
        ],
      ),
      body: DefaultTabController(
        length: 5,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) {
            return [
              SliverToBoxAdapter(child: _buildInstagramHeader()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: kOrange,
                    labelColor: kOrange,
                    unselectedLabelColor: Colors.white38,
                    isScrollable: false,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                    tabs: [
                      Tab(icon: const Icon(Icons.image_outlined, size: 18), text: AppState.tr('FOTO')),
                      Tab(icon: const Icon(Icons.text_snippet_outlined, size: 18), text: AppState.tr('Yazı')),
                      Tab(icon: const Icon(Icons.route, size: 18), text: AppState.tr('Rota')),
                      Tab(icon: const Icon(Icons.favorite_border, size: 18), text: AppState.tr('Beğeni')),
                      Tab(icon: const Icon(Icons.bar_chart, size: 18), text: AppState.tr('İstat')),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPhotosTab(),
              _buildTextsTab(),
              _buildRoutesTab(),
              _buildLikedTab(),
              _buildStatsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstagramHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: _isOwnProfile ? _updateProfilePicture : null,
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isPremium ? Colors.amber : kOrange.withOpacity(0.5),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: kOrange.withOpacity(0.2), blurRadius: 12, spreadRadius: 2),
                        ],
                      ),
                      child: ClipOval(
                        child: _profilePicUrl.isNotEmpty
                            ? (_profilePicUrl.startsWith('base64:')
                                ? Image.memory(
                                    base64Decode(_profilePicUrl.substring(7)),
                                    fit: BoxFit.cover, width: 90, height: 90,
                                    errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                                  )
                                : Image.network(
                                    _profilePicUrl,
                                    fit: BoxFit.cover, width: 90, height: 90,
                                    errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                                  ))
                            : _buildAvatarFallback(),
                      ),
                    ),
                    if (_isOwnProfile)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: kOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 13, color: Colors.black),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Post count from Firestore
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .where('userId', isEqualTo: widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '')
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (snap.hasError) return _buildTopStat('0', AppState.tr('Gönderi'));
                        final count = snap.data?.docs.length ?? 0;
                        return _buildTopStat(count.toString(), AppState.tr('Gönderi'));
                      },
                    ),
                    _buildTopStat(_followersCount.toString(), AppState.tr('Takipçi'), onTap: () => _openFollowList('followers')),
                    _buildTopStat(_followingCount.toString(), AppState.tr('Takip'), onTap: () => _openFollowList('following')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Name + badges
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              if (_isOwner)
                _buildShimmerName(_basTutar(_userName))
              else
                Text(_basTutar(_userName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              if (_isOwner || _isPremium)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.7), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                ),
              // Multiple badges
              ..._badges.map((badge) => _buildRoleBadge(badge)),
            ],
          ),
          if (_affiliationName.isNotEmpty && _affiliationType != 'Bireysel')
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(2),
                border: const Border(left: BorderSide(color: Colors.cyanAccent, width: 3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_affiliationType == 'Dernek' ? Icons.shield_outlined : Icons.flag_outlined, color: Colors.cyanAccent, size: 12),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('$_affiliationType: ${_affiliationName.toUpperCase()}', 
                      style: GoogleFonts.shareTechMono(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          if (_isPremium && !_isOwner)
            const Text('★ Premium Üye', style: TextStyle(color: Colors.amber, fontSize: 12)),
          const SizedBox(height: 6),
          Text(_bio, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          // Email - only if visible
          if (_userEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: Colors.blueAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(_userEmail, style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Action buttons
          if (_isOwnProfile)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(AppState.tr('PROFİLİ DÜZENLE'), Icons.edit_outlined, kCardBg, Colors.white, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _loadProfile());
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(AppState.tr('PAYLAŞ'), Icons.share_outlined, kCardBg, Colors.white, () {
                        Share.share('Rota+ Trekking uygulamasının üyesiyim! #RotaPlus');
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Sertifikalı Rehberlik Modülü
                _buildGuideSection(),
              ],
            )
          else
            Column(
              children: [
                if (_viewerIsAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent.withOpacity(0.15),
                              foregroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showAdminBadgeDialog(widget.targetUserId!),
                            icon: const Icon(Icons.admin_panel_settings, size: 16),
                            label: const Text('Rozet Ekle/Düzenle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.15),
                              foregroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _banUser(widget.targetUserId!),
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text('Yasakla', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return const SizedBox.shrink();
                          if (!snapshot.hasData || FirebaseAuth.instance.currentUser == null) {
                            return const SizedBox.shrink();
                          }
                          final uData = snapshot.data!.data() as Map<String, dynamic>?;
                          List followersList = uData != null && uData['followers'] is List ? uData['followers'] : [];
                          bool isFollowing = followersList.contains(FirebaseAuth.instance.currentUser!.uid);

                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? kCardBg : Colors.white,
                              foregroundColor: isFollowing ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final currentUid = FirebaseAuth.instance.currentUser!.uid;
                              // Kendi profilini takip etme
                              if (widget.targetUserId == currentUid) return;

                              if (isFollowing) {
                                await FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).update({
                                  'followers': FieldValue.arrayRemove([currentUid]),
                                  'followers_count': FieldValue.increment(-1),
                                });
                                await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                                  'following': FieldValue.arrayRemove([widget.targetUserId]),
                                  'following_count': FieldValue.increment(-1),
                                });
                              } else {
                                await FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).update({
                                  'followers': FieldValue.arrayUnion([currentUid]),
                                  'followers_count': FieldValue.increment(1),
                                });
                                await FirebaseFirestore.instance.collection('users').doc(currentUid).update({
                                  'following': FieldValue.arrayUnion([widget.targetUserId]),
                                  'following_count': FieldValue.increment(1),
                                });

                                // Takip bildirimi gönder
                                final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                                final myName = myDoc.data()?['name'] ?? 'Birisi';
                                final myPic = myDoc.data()?['profile_pic_url'] ?? '';
                                await NotificationService.sendFollowNotification(
                                  toUserId: widget.targetUserId!,
                                  fromUserId: currentUid,
                                  fromUserName: myName,
                                  fromUserPic: myPic,
                                );
                              }
                              _loadProfile();
                            },
                            child: Text(isFollowing ? AppState.tr('Takiptesin') : AppState.tr('Takip Et'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (widget.targetUserId != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ChatScreen(targetUserId: widget.targetUserId!, targetUserName: _userName),
                            ));
                          }
                        },
                        child: Text(AppState.tr('Mesaj Gönder'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }


  Widget _buildRoleBadge(String role) {
    IconData icon;
    Color color;
    switch (role) {
      case 'REHBER':
        icon = Icons.verified_user;
        color = kOrange;
        break;
      case 'V.I.P Üye':
        icon = Icons.stars;
        color = Colors.amber;
        break;
      case 'Acil Durum Lideri':
        icon = Icons.security;
        color = Colors.blueAccent;
        break;
      case 'Arazi Sporcusu':
        icon = Icons.terrain;
        color = kGreen;
        break;
      case 'Moderatör':
        icon = Icons.shield;
        color = Colors.purpleAccent;
        break;
      case 'Kurtarma Uzmanı':
        icon = Icons.health_and_safety;
        color = Colors.redAccent;
        break;
      case 'Premium':
        icon = Icons.workspace_premium;
        color = Colors.amber;
        break;
      default:
        icon = Icons.fiber_new;
        color = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(role, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _banUser(String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Kullanıcıyı Yasakla', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Bu kullanıcı banlandığında gönderileri gizlenecek.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(userId).update({'is_banned': true});
              if (ctx.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı yasaklandı.'), backgroundColor: Colors.redAccent));
            },
            child: const Text('YASAKLA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Admin: Çoklu badge yönetimi
  void _showAdminBadgeDialog(String uId) {
    final allRoles = ['Yeni Üye', 'Arazi Sporcusu', 'V.I.P Üye', 'Acil Durum Lideri', 'Moderatör', 'Kurtarma Uzmanı'];
    List<String> selectedBadges = List.from(_badges);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: kCardBg,
          title: const Text('Rozet Ekle / Düzenle', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Birden fazla seçebilirsiniz:', style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 12),
                ...allRoles.map((r) => CheckboxListTile(
                  value: selectedBadges.contains(r),
                  title: _buildRoleBadge(r),
                  activeColor: kOrange,
                  checkColor: Colors.black,
                  dense: true,
                  onChanged: (v) {
                    setD(() {
                      if (v == true) {
                        selectedBadges.add(r);
                      } else {
                        selectedBadges.remove(r);
                      }
                    });
                  },
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(uId).update({
                  'roles': selectedBadges,
                  'role': selectedBadges.isNotEmpty ? selectedBadges.first : 'Yeni Üye',
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadProfile();
              },
              child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStat(String val, String title, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridFeed() {
    final String uidToFetch = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uidToFetch.isEmpty) {
      return const Center(child: Text("Hata: Kullanıcı bulunamadı.", style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uidToFetch)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white12),
                const SizedBox(height: 16),
                const Text("Henüz Gönderi Yok", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_isOwnProfile)
                  const Text("İlk gönderini paylaş!", style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }

        final posts = snapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postDoc = posts[index];
            final post = postDoc.data() as Map<String, dynamic>;
            final imageUrl = post['imageUrl'] ?? '';
            final desc = post['desc'] ?? '';
            final List likesList = post['likes'] is List ? post['likes'] : [];
            final int likesCount = likesList.length;
            final String postType = post['postType'] ?? '';

            return GestureDetector(
              onTap: () => _showFirestorePostDetail(postDoc.id, post),
              child: Container(
                color: kCardBg,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      imageUrl.startsWith('base64:')
                          ? Image.memory(base64Decode(imageUrl.substring(7)), fit: BoxFit.cover)
                          : Image.network(imageUrl, fit: BoxFit.cover)
                    else if (postType == 'route')
                      Container(
                        color: const Color(0xFF62FF4C).withOpacity(0.08),
                        child: const Center(child: Icon(Icons.route, color: Color(0xFF62FF4C), size: 32)),
                      )
                    else
                      Container(
                        color: const Color(0xFF1A1A1A),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    // Likes overlay
                    Positioned(
                      bottom: 4, left: 6,
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.white70, size: 12),
                          const SizedBox(width: 2),
                          Text('$likesCount', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
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

  // ─── PHOTOS TAB ──────────────────────────────────────────────────────────────
  Widget _buildPhotosTab() {
    final String uid = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts')
          .where('userId', isEqualTo: uid).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white38, fontSize: 11)));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        final posts = (snapshot.data?.docs ?? []).where((d) {
          return ((d.data() as Map<String, dynamic>)['imageUrl'] ?? '').isNotEmpty;
        }).toList();
        if (posts.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.photo_library_outlined, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('Henüz Fotograf Yok', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isOwnProfile) const Text('Fotografli gonderi paylas!', style: TextStyle(color: Colors.white38)),
          ]));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final post = posts[i].data() as Map<String, dynamic>;
            final img = post['imageUrl'] ?? '';
            final likes = post['likes'] is List ? (post['likes'] as List).length : 0;
            return GestureDetector(
              onTap: () => _showFirestorePostDetail(posts[i].id, post),
              child: Stack(fit: StackFit.expand, children: [
                Container(color: kCardBg,
                  child: img.startsWith('base64:')
                      ? Image.memory(base64Decode(img.substring(7)), fit: BoxFit.cover)
                      : Image.network(img, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24))),
                Positioned(bottom: 4, left: 6,
                  child: Row(children: [
                    const Icon(Icons.favorite, color: Colors.white70, size: 12),
                    const SizedBox(width: 2),
                    Text('$likes', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ])),
              ]),
            );
          },
        );
      },
    );
  }

  // ─── TEXTS TAB ───────────────────────────────────────────────────────────────
  Widget _buildTextsTab() {
    final String uid = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts')
          .where('userId', isEqualTo: uid).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white38, fontSize: 11)));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        final posts = (snapshot.data?.docs ?? []).where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['imageUrl'] ?? '').isEmpty && (data['postType'] ?? '') != 'route';
        }).toList();
        if (posts.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.text_snippet_outlined, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('Henüz Yazi Yok', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isOwnProfile) const Text('Dusuncelerini paylas!', style: TextStyle(color: Colors.white38)),
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          itemBuilder: (ctx, i) {
            final post = posts[i].data() as Map<String, dynamic>;
            final desc = post['desc'] ?? '';
            final likes = post['likes'] is List ? (post['likes'] as List).length : 0;
            final Timestamp? ts = post['timestamp'];
            return GestureDetector(
              onTap: () => _showFirestorePostDetail(posts[i].id, post),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(desc, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.favorite, color: Colors.redAccent, size: 14),
                    const SizedBox(width: 4),
                    Text('$likes', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const Spacer(),
                    if (ts != null) Text('${ts.toDate().day}.${ts.toDate().month}.${ts.toDate().year}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ─── ROUTES TAB ──────────────────────────────────────────────────────────────
  Widget _buildRoutesTab() {
    final String uid = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).collection('routes')
          .orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        // Hata göster (index eksikliği, izin hatası vb.)
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: kOrange, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Rotalar yüklenemedi:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }
        final routes = snapshot.data?.docs ?? [];
        if (routes.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.route, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('Henüz Rota Yok', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_isOwnProfile) ...[
              const Text('Rota veya Takip sekmesinden aktivite yap!',
                  style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // Manuel rota ekleme butonu
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _showManualRouteDialog(uid),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Manuel Rota Ekle', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ]));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: routes.length,
          itemBuilder: (ctx, i) {
            final r = routes[i].data() as Map<String, dynamic>;
            final name = r['name'] ?? 'İsimsiz Rota';
            final from = r['from'] ?? '';
            final to = r['to'] ?? '';
            final dist = (r['distance'] ?? 0).toDouble();
            final distStr = dist > 1000 ? '${(dist / 1000).toStringAsFixed(2)} km' : '${dist.toInt()} m';
            final Timestamp? ts = r['timestamp'];
            final source = r['source'] ?? '';
            final durationSec = (r['duration_seconds'] as num?)?.toInt() ?? 0;
            final elevGain = (r['elevation_gain'] as num?)?.toDouble() ?? 0;
            final maxAlt = (r['max_altitude'] as num?)?.toDouble() ?? 0;
            final steps = (r['steps'] as num?)?.toInt() ?? 0;
            final pointCount = (r['pointCount'] as num?)?.toInt() ?? (r['coordinates'] as List?)?.length ?? 0;

            String durationStr = '';
            if (durationSec > 0) {
              final h = durationSec ~/ 3600;
              final m = (durationSec % 3600) ~/ 60;
              durationStr = h > 0 ? '${h}s ${m}d' : '${m} dk';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: kCardBg, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: source == 'live_tracking'
                    ? kOrange.withOpacity(0.3)
                    : const Color(0xFF62FF4C).withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (source == 'live_tracking' ? kOrange : const Color(0xFF62FF4C)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        source == 'live_tracking' ? Icons.directions_run : Icons.route,
                        color: source == 'live_tracking' ? kOrange : const Color(0xFF62FF4C),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        if (source == 'live_tracking')
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Canlı Takip', style: TextStyle(color: kOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    )),
                    if (_isOwnProfile)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _shareRouteFromProfile(routes[i].id, r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: kOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: kOrange.withOpacity(0.4))),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.share, color: kOrange, size: 13),
                                SizedBox(width: 4),
                                Text('Paylaş', style: TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteRoute(routes[i].id, name),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
                              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                            ),
                          ),
                        ],
                      ),
                  ]),
                  if (from.isNotEmpty || to.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if (from.isNotEmpty) Row(children: [const Icon(Icons.trip_origin, color: Color(0xFF62FF4C), size: 12), const SizedBox(width: 6), Expanded(child: Text(from, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                    if (to.isNotEmpty) ...[const SizedBox(height: 4), Row(children: [const Icon(Icons.flag, color: Colors.redAccent, size: 12), const SizedBox(width: 6), Expanded(child: Text(to, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))])],
                  ],
                  const SizedBox(height: 10),
                  // İstatistikler
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildRouteStatChip(Icons.straighten, distStr, kOrange),
                      if (durationStr.isNotEmpty) _buildRouteStatChip(Icons.timer_outlined, durationStr, Colors.lightBlueAccent),
                      if (elevGain > 0) _buildRouteStatChip(Icons.trending_up, '${elevGain.toInt()} m', kGreen),
                      if (maxAlt > 0) _buildRouteStatChip(Icons.height, '${maxAlt.toInt()} m Tepe', Colors.purpleAccent),
                      if (steps > 0) _buildRouteStatChip(Icons.directions_walk, '$steps adım', Colors.amberAccent),
                      if (pointCount > 0) _buildRouteStatChip(Icons.location_on_outlined, '$pointCount nokta', Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    if (ts != null) Text('${ts.toDate().day}.${ts.toDate().month}.${ts.toDate().year}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    const Spacer(),
                    // "Bu Rotayı Yürü" butonu - başkaları için
                    if (!_isOwnProfile && (r['coordinates'] as List?)?.isNotEmpty == true)
                      GestureDetector(
                        onTap: () => _walkThisRoute(r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: kGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kGreen.withOpacity(0.4)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.directions_run, color: Color(0xFF62FF4C), size: 13),
                            SizedBox(width: 4),
                            Text('Bu Rotayı Yürü', style: TextStyle(color: Color(0xFF62FF4C), fontSize: 11, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRouteStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11), const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _walkThisRoute(Map<String, dynamic> routeData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.directions_run, color: Color(0xFF62FF4C), size: 22),
          SizedBox(width: 8),
          Expanded(child: Text('Bu Rotayı Yürü', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${routeData['name'] ?? 'Bu rota'}', style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            const Text('Bu rotayı yürümek için "Takip" sekmesinden GPS takibini başlatın ve rotanız boyunca ilerlediğinizde istatistikleriniz kaydedilecektir.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            const Text('İPUCU: Rota koordinatları Rota sekmesinde görüntülenebilir.', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT', style: TextStyle(color: Colors.white38))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              final coordsRaw = routeData['coordinates'] as List?;
              if (coordsRaw != null) {
                final noktalar = coordsRaw.map((e) => {'lat': (e['lat'] as num).toDouble(), 'lng': (e['lng'] as num).toDouble()}).toList();
                await DatabaseHelper.instance.rotaKaydet(
                  routeData['name'] ?? 'İçe Aktarılan Rota',
                  noktalar,
                  baslangicAdi: routeData['from'] ?? '',
                  bitisAdi: routeData['to'] ?? '',
                  distance: (routeData['distance'] as num?)?.toDouble() ?? 0.0,
                  durationSeconds: (routeData['duration_seconds'] as num?)?.toInt() ?? 0,
                  elevationGain: (routeData['elevation_gain'] as num?)?.toDouble() ?? 0.0,
                  maxAltitude: (routeData['max_altitude'] as num?)?.toDouble() ?? 0.0,
                  steps: (routeData['steps'] as num?)?.toInt() ?? 0,
                  source: routeData['source'] ?? '',
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Rota kaydedildi! "Rota" sekmesinden seçip takibe başlayabilirsiniz.'),
                backgroundColor: Color(0xFF43A047),
              ));
            },
            icon: const Icon(Icons.play_arrow, color: Colors.black, size: 18),
            label: const Text('TAKIBI BAŞLAT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showManualRouteDialog(String uid) {
    final nameCtrl = TextEditingController();
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final elevCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.add_location_alt, color: kOrange, size: 22),
          SizedBox(width: 8),
          Text('Manuel Rota Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogInput(nameCtrl, 'Rota Adı *', Icons.route),
              const SizedBox(height: 10),
              _buildDialogInput(fromCtrl, 'Başlangıç Noktası', Icons.trip_origin),
              const SizedBox(height: 10),
              _buildDialogInput(toCtrl, 'Bitiş / Zirve', Icons.flag),
              const SizedBox(height: 10),
              _buildDialogInput(distCtrl, 'Mesafe (metre)', Icons.straighten),
              const SizedBox(height: 10),
              _buildDialogInput(durationCtrl, 'Süre (dakika)', Icons.timer_outlined),
              const SizedBox(height: 10),
              _buildDialogInput(elevCtrl, 'İrtifa Kazanımı (metre)', Icons.trending_up),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white38))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Rota adı zorunludur!')));
                return;
              }
              final dist = double.tryParse(distCtrl.text.trim()) ?? 0;
              final dur = int.tryParse(durationCtrl.text.trim());
              final elev = double.tryParse(elevCtrl.text.trim()) ?? 0;
              try {
                await FirebaseFirestore.instance
                    .collection('users').doc(uid).collection('routes').add({
                  'name': name,
                  'from': fromCtrl.text.trim(),
                  'to': toCtrl.text.trim(),
                  'distance': dist,
                  'duration_seconds': dur != null ? dur * 60 : 0,
                  'elevation_gain': elev,
                  'source': 'manual',
                  'timestamp': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Rota eklendi!'), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
              }
            },
            icon: const Icon(Icons.save, color: Colors.black, size: 16),
            label: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  // ─── LIKED TAB ───────────────────────────────────────────────────────────────

  Widget _buildLikedTab() {
    final String uid = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    if (!_isOwnProfile) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_outline, size: 48, color: Colors.white24),
        SizedBox(height: 12),
        Text('Bu bilgi gizlidir.', style: TextStyle(color: Colors.white38, fontSize: 14)),
      ]));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts')
          .where('likes', arrayContains: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white38, fontSize: 11)));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        final posts = snapshot.data?.docs ?? [];
        if (posts.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.white12),
            SizedBox(height: 16),
            Text('Henüz Begeni Yok', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Begendigin gonderiler burada gorunecek.', style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
          ]));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: posts.length,
          itemBuilder: (ctx, i) {
            final post = posts[i].data() as Map<String, dynamic>;
            final img = post['imageUrl'] ?? '';
            final desc = post['desc'] ?? '';
            final postType = post['postType'] ?? '';
            final likes = post['likes'] is List ? (post['likes'] as List).length : 0;
            return GestureDetector(
              onTap: () => _showFirestorePostDetail(posts[i].id, post),
              child: Container(color: kCardBg, child: Stack(fit: StackFit.expand, children: [
                if (img.isNotEmpty)
                  img.startsWith('base64:')
                      ? Image.memory(base64Decode(img.substring(7)), fit: BoxFit.cover)
                      : Image.network(img, fit: BoxFit.cover)
                else if (postType == 'route')
                  Container(color: const Color(0xFF62FF4C).withOpacity(0.08), child: const Center(child: Icon(Icons.route, color: Color(0xFF62FF4C), size: 32)))
                else
                  Container(color: const Color(0xFF1A1A1A), child: Center(child: Padding(padding: const EdgeInsets.all(6),
                    child: Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)))),
                Positioned(bottom: 4, left: 6, child: Row(children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 12),
                  const SizedBox(width: 2),
                  Text('$likes', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ])),
              ])),
            );
          },
        );
      },
    );
  }

  // ─── SHARE ROUTE FROM PROFILE ─────────────────────────────────────────────────
  Future<void> _shareRouteFromProfile(String routeId, Map<String, dynamic> rd) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: rd['name'] ?? '');
    final descCtrl = TextEditingController();
    final dist = (rd['distance'] ?? 0).toDouble();
    final distStr = dist > 1000 ? '${(dist / 1000).toStringAsFixed(2)} km' : '${dist.toInt()} m';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.route, color: Color(0xFF62FF4C), size: 22),
          SizedBox(width: 8),
          Text('Rotayi Paylas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF62FF4C).withOpacity(0.3))),
            child: Column(children: [
              if ((rd['from'] ?? '').isNotEmpty) Row(children: [const Icon(Icons.trip_origin, color: Color(0xFF62FF4C), size: 12), const SizedBox(width: 6), Expanded(child: Text(rd['from'], style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))]),
              if ((rd['to'] ?? '').isNotEmpty) ...[const SizedBox(height: 4), Row(children: [const Icon(Icons.flag, color: Colors.redAccent, size: 12), const SizedBox(width: 6), Expanded(child: Text(rd['to'], style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))])],
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _buildShareStatWidget('Mesafe', distStr),
                _buildShareStatWidget('Nokta', '${(rd['coordinates'] as List?)?.length ?? rd['pointCount'] ?? 0}'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: 'Rota Adi (ör: A\'dan B\'ye)', labelStyle: const TextStyle(color: Colors.white38, fontSize: 12), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kOrange)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), maxLines: 2,
            decoration: InputDecoration(hintText: 'Aciklama ekle... (istege bagli)', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF62FF4C))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('IPTAL', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('PAYLAS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Kullanici';
      final userEmail = userDoc.data()?['email'] ?? '';
      final isPremium = userDoc.data()?['is_premium'] ?? false;
      final List coords = rd['coordinates'] ?? [];
      final List<Map<String, dynamic>> downsampled = coords.length > 100
          ? List.generate(100, (i) { final idx = (i * (coords.length - 1) / 99).round(); return {'lat': coords[idx]['lat'], 'lng': coords[idx]['lng']}; })
          : List<Map<String, dynamic>>.from(coords.map((c) => {'lat': c['lat'], 'lng': c['lng']}));

      await FirebaseFirestore.instance.collection('posts').add({
        'user': userName, 'userEmail': userEmail, 'userId': user.uid, 'isPremium': isPremium,
        'desc': descCtrl.text.trim(), 'imageUrl': '', 'likes': [], 'postType': 'route',
        'routeData': {
          'name': nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : (rd['name'] ?? 'Rota'),
          'from': rd['from'] ?? '',
          'to': rd['to'] ?? '',
          'distance': rd['distance'] ?? 0,
          'pointCount': coords.length,
          'coordinates': downsampled,
          // Canlı takipten gelen istatistikler
          'duration_seconds': rd['duration_seconds'] ?? 0,
          'elevation_gain': rd['elevation_gain'] ?? 0,
          'max_altitude': rd['max_altitude'] ?? 0,
          'steps': rd['steps'] ?? 0,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota akisa paylasildi!'), backgroundColor: Color(0xFF43A047)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteRoute(String routeId, String routeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Rotayı Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('"$routeName" rotasını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İPTAL', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SİL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('routes').doc(routeId).delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota silindi.'), backgroundColor: Colors.black87));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme hatası: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildShareStatWidget(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]);
  }

  void _showFirestorePostDetail(String postId, Map<String, dynamic> post) {
    final imageUrl = post['imageUrl'] ?? '';
    final desc = post['desc'] ?? '';
    final List likesList = post['likes'] is List ? post['likes'] : [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  // Handle + Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                        (post['userId'] == currentUid)
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54),
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } else if (value == 'edit') {
                                    Navigator.pop(ctx);
                                    _showEditPostDialog(postId, desc);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                  PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
                                ],
                              )
                            : const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  // Image
                  if (imageUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 280),
                      color: Colors.black,
                      child: imageUrl.startsWith('base64:')
                          ? Image.memory(base64Decode(imageUrl.substring(7)), fit: BoxFit.cover)
                          : Image.network(imageUrl, fit: BoxFit.cover),
                    )
                  else if (desc.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Text('"$desc"', style: const TextStyle(color: Colors.white, fontSize: 18, fontStyle: FontStyle.italic, height: 1.5)),
                    ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        StatefulBuilder(
                          builder: (ctx2, setLikeState) {
                            final isLiked = currentUid != null && likesList.contains(currentUid);
                            return GestureDetector(
                              onTap: () async {
                                if (currentUid == null) return;
                                final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
                                if (isLiked) {
                                  await postRef.update({'likes': FieldValue.arrayRemove([currentUid])});
                                  likesList.remove(currentUid);
                                } else {
                                  await postRef.update({'likes': FieldValue.arrayUnion([currentUid])});
                                  likesList.add(currentUid);
                                }
                                setLikeState(() {});
                                setSheetState(() {});
                              },
                              child: Row(
                                children: [
                                  Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.redAccent : Colors.white, size: 26),
                                  const SizedBox(width: 6),
                                  Text('${likesList.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').snapshots(),
                          builder: (ctx3, cSnap) {
                            final count = cSnap.data?.docs.length ?? 0;
                            return Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
                                const SizedBox(width: 6),
                                Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (imageUrl.isNotEmpty && desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                    ),

                  // Comment list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').orderBy('timestamp', descending: false).snapshots(),
                      builder: (ctx, cSnap) {
                        if (!cSnap.hasData) return const Center(child: CircularProgressIndicator(color: kOrange));
                        final comments = cSnap.data!.docs;
                        if (comments.isEmpty) {
                          return const Center(child: Text('Henüz yorum yok.', style: TextStyle(color: Colors.white38)));
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: comments.length,
                          itemBuilder: (ctx, i) {
                            final c = comments[i].data() as Map<String, dynamic>;
                            final commentUserId = c['userId'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (commentUserId.isNotEmpty) {
                                        Navigator.pop(ctx);
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => ProfileScreen(targetUserId: commentUserId),
                                        ));
                                      }
                                    },
                                    child: FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('users').doc(commentUserId).get(),
                                      builder: (ctx, uSnap) {
                                        String picUrl = '';
                                        if (uSnap.hasData && uSnap.data!.exists) {
                                          picUrl = (uSnap.data!.data() as Map<String, dynamic>)['profile_pic_url'] ?? '';
                                        }
                                        return CircleAvatar(
                                          radius: 14,
                                          backgroundColor: kOrange.withOpacity(0.2),
                                          backgroundImage: picUrl.startsWith('base64:')
                                              ? MemoryImage(base64Decode(picUrl.substring(7)))
                                              : (picUrl.isNotEmpty ? NetworkImage(picUrl) : null) as ImageProvider?,
                                          child: picUrl.isEmpty ? Text((c['userName'] ?? 'K').substring(0, 1).toUpperCase(), style: const TextStyle(color: kOrange, fontSize: 11)) : null,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (commentUserId.isNotEmpty) {
                                              Navigator.pop(ctx);
                                              Navigator.push(context, MaterialPageRoute(
                                                builder: (_) => ProfileScreen(targetUserId: commentUserId),
                                              ));
                                            }
                                          },
                                          child: Text(c['userName'] ?? '', style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        Text(c['text'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  if (currentUid != null && (currentUid == commentUserId || _viewerIsAdmin))
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        bool confirm = await showDialog(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            backgroundColor: const Color(0xFF141414),
                                            title: const Text('Yorumu Sil', style: TextStyle(color: Colors.white)),
                                            content: const Text('Bu yorumu silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                onPressed: () => Navigator.pop(c, true),
                                                child: const Text('SİL', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        ) ?? false;
                                        if (confirm) {
                                          await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').doc(comments[i].id).delete();
                                        }
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

                  // Comment input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: commentController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Yorum ekle...',
                                hintStyle: TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty || currentUid == null) return;

                            final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
                            final name = userDoc.data()?['name'] ?? 'Kullanıcı';
                            final username = userDoc.data()?['username'] ?? '';

                            await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').add({
                              'userId': currentUid,
                              'userName': username.isNotEmpty ? '@$username' : name,
                              'text': text,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            commentController.clear();
                          },
                          child: Container(
                            width: 40, height: 40,
                            decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
                            child: const Icon(Icons.send, color: Colors.black, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPostDialog(String postId, String currentDesc) {
    final controller = TextEditingController(text: currentDesc);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Gönderiyi Düzenle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Açıklama...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('posts').doc(postId).update({'desc': controller.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('KAYDET', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final String uidToFetch = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uidToFetch).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Eğer başkasının profilindeysek ve izin yoksa gizli bilgi gösterelim
          if (!_isOwnProfile) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.white24),
              const SizedBox(height: 12),
              Text(AppState.tr('Bu bilgi gizlidir.'), style: const TextStyle(color: Colors.white38, fontSize: 14)),
            ]));
          }
          return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white38, fontSize: 11)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }

        double totalDist = 0;
        bool isPremium = false;
        String email = '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          totalDist = (data['total_distance'] ?? 0).toDouble();
          isPremium = data['is_premium'] ?? false;
          email = data['email'] ?? '';
        }

        final double distanceKm = totalDist / 1000;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KİŞİSEL VİTRİN VE BAŞARILAR',
                  style: TextStyle(color: kOrange, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Toplam Yürünen Mesafe', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text('${distanceKm.toStringAsFixed(1)} KM',
                        style: const TextStyle(color: kOrange, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('ROZETLER', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBadgeCard(
                      imagePath: 'assets/badges/badge_bronze_10km_1776324001012.png',
                      title: 'Bronz Ayak',
                      desc: '10 KM barajı',
                      earned: distanceKm >= 10,
                    ),
                    const SizedBox(width: 12),
                    _buildBadgeCard(
                      imagePath: 'assets/badges/badge_silver_50km_1776324073001.png',
                      title: 'Gümüş Rota',
                      desc: '50 KM barajı',
                      earned: distanceKm >= 50,
                    ),
                    const SizedBox(width: 12),
                    _buildBadgeCard(
                      imagePath: 'assets/badges/badge_gold_100km_1776324088846.png',
                      title: 'Altın Keşif',
                      desc: '100 KM barajı',
                      earned: distanceKm >= 100,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('ÖZEL STATÜLER', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              if (isPremium)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12)),
                  child: const ListTile(
                    leading: Icon(Icons.stars, color: Colors.amber, size: 32),
                    title: Text('Premium Üye', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    subtitle: Text('Tüm özelliklere sınırsız erişim', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),

              if (_kAdminEmails.contains(email))
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12)),
                  child: const ListTile(
                    leading: Icon(Icons.verified, color: Colors.blueAccent, size: 32),
                    title: Text('Acil Durum Lideri', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    subtitle: Text('Onaylı sistem yöneticisi/lideri', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),

              // Show assigned badges
              if (_badges.isNotEmpty && _badges.first != 'Yeni Üye') ...[
                const SizedBox(height: 24),
                const Text('ATANMIŞ ROZETLER', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _badges.map((b) => _buildRoleBadge(b)).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeCard({required String imagePath, required String title, required String desc, required bool earned}) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: earned ? kOrange.withOpacity(0.5) : Colors.white12, width: 1.5),
        boxShadow: earned ? [BoxShadow(color: kOrange.withOpacity(0.1), blurRadius: 12)] : null,
      ),
      child: Column(
        children: [
          Opacity(
            opacity: earned ? 1.0 : 0.2,
            child: Image.asset(imagePath, width: 64, height: 64, fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.shield, color: Colors.amber, size: 60)),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: earned ? kOrange : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _uploadCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      final pickedFile = result.files.first;
      
      // Mobil cihazlarda withData bazen null dönebilir, path üzerinden okuyalım
      List<int>? bytes = pickedFile.bytes;
      if (bytes == null && pickedFile.path != null) {
        bytes = await File(pickedFile.path!).readAsBytes();
      }
      
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya okunamadı!')));
        return;
      }

      // Firestore 1MB limit kontrolü (Base64 boyutu %33 artırır)
      final sizeInBytes = bytes.length;
      if (sizeInBytes > 800 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: Dosya boyutu çok büyük (${(sizeInBytes / 1024).toStringAsFixed(1)} KB). Lütfen 800KB altında bir dosya seçin veya PDF\'i sıkıştırın.'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);
      
      final base64Content = base64Encode(bytes);
      final fileName = pickedFile.name;
      final isPdf = fileName.toLowerCase().endsWith('.pdf');
      final nameToWrite = _userName ?? user.displayName ?? 'Kullanıcı';
      final emailToWrite = user.email ?? '';
      
      // Rehberlik başvurusu oluştur
      await FirebaseFirestore.instance.collection('guide_applications').doc(user.uid).set({
        'uid': user.uid,
        'email': emailToWrite,
        'name': nameToWrite,
        'certificate_base64': 'base64:$base64Content',
        'file_name': fileName,
        'is_pdf': isPdf,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Belge yüklendi! Yönetici onayı bekleniyor.'),
          backgroundColor: kGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Hata detayını göster (Permission denied mı yoksa başka bir şey mi?)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Widget _buildGuideSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('guide_applications').doc(user.uid).snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          // İzin hatası ise sessizce none state göster veya admin uyarısı yap
          return const SizedBox.shrink();
        }
        final data = snap.data?.data() as Map<String, dynamic>?;
        final status = data?['status'] ?? 'none';
        final isGuide = _badges.contains('REHBER') || _kAdminEmails.contains(user.email);

        if (isGuide) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kOrange)),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: kOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SERTİFİKALI REHBER', style: GoogleFonts.shareTechMono(color: kOrange, fontWeight: FontWeight.bold)),
                      const Text('TDF Onaylı Uzman Dağ Mihmandarı', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: Row(
            children: [
              const Icon(Icons.hiking, color: Colors.white38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sertifikalı Rehber Ol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      status == 'pending' ? 'Onay Bekleniyor...' : 'TDF Yürüyüş Liderliği belgeni yükle.',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (status != 'pending')
                ElevatedButton(
                  onPressed: _uploadCertificate,
                  style: ElevatedButton.styleFrom(backgroundColor: kOrange, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('BELGE YÜKLE', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      },
    );
  }

}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.black, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
