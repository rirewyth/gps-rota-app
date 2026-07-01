import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'profile_screen.dart';
import 'dm_list_screen.dart' hide kCardBg, kOrange, kBackground;
import '../database_helper.dart';
import 'live_tracking_screen.dart' hide kCardBg, kOrange, kBackground;
import '../utils/app_state.dart';
import 'notification_screen.dart';
import '../services/ad_service.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({Key? key}) : super(key: key);

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kCardBg = Color(0xFF141414);

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _postDescController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;
  final Set<String> _dismissedAnnouncements = {}; // session-dismissed
  final Map<String, Map<String, dynamic>> _userCache = {}; // profil cache (resim flickering önler)
  int _currentAnnouncementIndex = 0;

  static const String adminEmail = 'sercanoral65@gmail.com';

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  bool get _isAdmin => _currentUser?.email == adminEmail;

  List<String> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    
    // İlk olarak lokalden yükle (hızlı açılış için)
    setState(() {
      _blockedUsers = prefs.getStringList('blocked_users_list') ?? [];
    });

    // Sonra Firestore'dan güncel listeyi alıp eşitle (Cihazlar arası senkronizasyon)
    if (_currentUser != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('blocked_users')) {
            final firestoreBlocked = List<String>.from(data['blocked_users'] ?? []);
            if (firestoreBlocked.length != _blockedUsers.length || !firestoreBlocked.every((e) => _blockedUsers.contains(e))) {
              setState(() {
                _blockedUsers = firestoreBlocked;
              });
              await prefs.setStringList('blocked_users_list', firestoreBlocked);
            }
          }
        }
      } catch (e) {
        debugPrint('Blocked users fetch error: $e');
      }
    }
  }

  Future<void> _blockUser(String userIdToBlock) async {
    if (_blockedUsers.contains(userIdToBlock)) return;
    setState(() {
      _blockedUsers.add(userIdToBlock);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_users_list', _blockedUsers);
    
    // Notify developer and update local array (per App Store requirement)
    if (_currentUser != null) {
      // 1. Şikayet raporu oluştur
      FirebaseFirestore.instance.collection('reports').add({
        'type': 'block_user',
        'reporter': _currentUser!.uid,
        'blocked_user': userIdToBlock,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // 2. Kendi kullanıcı belgeme 'blocked_users' dizisine ekle (DM engeli vb. için kalıcı)
      FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({
        'blocked_users': FieldValue.arrayUnion([userIdToBlock])
      }, SetOptions(merge: true));
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi. Gönderileri artık görünmeyecek.'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _reportPost(String postId, String reportedUserId) async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance.collection('reports').add({
      'type': 'report_post',
      'reporter': _currentUser!.uid,
      'reported_user': reportedUserId,
      'post_id': postId,
      'timestamp': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İçerik şikayet edildi. 24 saat içinde incelenecektir.'), backgroundColor: Colors.green));
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<bool> _createPost({Map<String, dynamic>? routeData}) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen önce giriş yapın!')));
      return false;
    }

    final desc = _postDescController.text.trim();
    if (desc.isEmpty && _selectedImage == null && routeData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir açıklama veya fotoğraf ekleyin!')));
      return false;
    }

    setState(() => _isUploading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Rota Kullanıcısı';
      final userEmail = userDoc.data()?['email'] ?? _currentUser!.email ?? '';
      final isPremium = await AdService.checkPremiumStatus();

      String imageUrl = '';
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final base64Image = base64Encode(bytes);
        imageUrl = 'base64:$base64Image';
      }

      final postData = {
        'user': userName,
        'userEmail': userEmail,
        'userId': _currentUser!.uid,
        'isPremium': isPremium,
        'desc': desc,
        'imageUrl': imageUrl,
        'likes': [],
        'commentsCount': 0,
        'timestamp': FieldValue.serverTimestamp(),
        if (routeData != null) 'routeData': routeData,
        if (routeData != null) 'postType': 'route',
      };

      await FirebaseFirestore.instance.collection('posts').add(postData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gönderi paylaşıldı! ✓'), backgroundColor: Colors.green),
        );
      }
      _postDescController.clear();
      _selectedImage = null;
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── Comments Bottom Sheet ──────────────────────────────────────
  void _showCommentsBottomSheet(String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final commentController = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: kOrange, size: 18),
                          SizedBox(width: 8),
                          Text('Yorumlar', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .doc(postId)
                            .collection('comments')
                            .orderBy('timestamp', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kOrange));
                          final comments = snapshot.data!.docs;
                          if (comments.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white12),
                                  const SizedBox(height: 12),
                                  const Text('İlk yorumu sen yap!', style: TextStyle(color: Colors.white38, fontSize: 14)),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: comments.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemBuilder: (ctx, idx) {
                              final c = comments[idx].data() as Map<String, dynamic>;
                              final commentUserId = c['userId'] ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
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
                                          String initial = (c['userName'] ?? 'K').substring(0, 1).toUpperCase();
                                          
                                          if (uSnap.hasData && uSnap.data!.exists) {
                                            final userData = uSnap.data!.data() as Map<String, dynamic>?;
                                            picUrl = userData?['profile_pic_url'] ?? '';
                                          }
                                          
                                          return CircleAvatar(
                                            radius: 16,
                                            backgroundColor: kOrange.withOpacity(0.2),
                                            backgroundImage: picUrl.startsWith('base64:')
                                                ? MemoryImage(base64Decode(picUrl.substring(7)))
                                                : (picUrl.isNotEmpty ? NetworkImage(picUrl) : null) as ImageProvider?,
                                            child: picUrl.isEmpty
                                                ? Text(initial, style: const TextStyle(color: kOrange, fontSize: 12))
                                                : null,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
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
                                              child: Text(c['userName'] ?? 'Kullanıcı',
                                                  style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(c['text'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_currentUser != null && (_currentUser!.uid == commentUserId || _isAdmin))
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
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
                                            await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').doc(comments[idx].id).delete();
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yorum silindi.'), backgroundColor: Colors.black87));
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
                    // Yorum input — her zaman görünür
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
                                autofocus: false,
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
                              if (text.isEmpty || _currentUser == null) return;

                              final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
                              final name = userDoc.data()?['name'] ?? 'Kullanıcı';
                              final username = userDoc.data()?['username'] ?? '';

                              await FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').add({
                                'userId': _currentUser!.uid,
                                'userName': username.isNotEmpty ? '@$username' : name,
                                'text': text,
                                'timestamp': FieldValue.serverTimestamp(),
                              });

                              commentController.clear();
                              setSheetState(() {});
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
              ),
            );
          },
        );
      },
    );
  }

  // ─── Create Post Sheet ──────────────────────────────────────────
  void _showCreatePostSheet() {
    _postDescController.clear();
    _selectedImage = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.add_box_outlined, color: kOrange, size: 22),
                          const SizedBox(width: 8),
                          const Text('Yeni Gönderi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kOrange.withOpacity(0.3)),
                            ),
                            child: const Text('Fotoğraf isteğe bağlı', style: TextStyle(color: kOrange, fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Image picker
                      GestureDetector(
                        onTap: () async {
                          await _pickImage();
                          setStateSheet(() {});
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: _selectedImage != null ? 200 : 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _selectedImage != null ? kOrange : Colors.white12,
                              width: _selectedImage != null ? 2 : 1,
                            ),
                          ),
                          child: _selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(
                                        color: kOrange.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_a_photo_outlined, color: kOrange, size: 28),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text('Fotoğraf Seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    const Text('Galeriden seç', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                  ],
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 8, right: 8,
                                      child: GestureDetector(
                                        onTap: () => setStateSheet(() => _selectedImage = null),
                                        child: Container(
                                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Text input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _postDescController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'Ne paylaşmak istiyorsunuz?',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Share button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kOrange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: _isUploading
                              ? null
                              : () async {
                                  setStateSheet(() => _isUploading = true);
                                  bool success = await _createPost();
                                  if (!success && mounted) setStateSheet(() => _isUploading = false);
                                },
                          child: _isUploading
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                                    const SizedBox(width: 8),
                                    Text('PAYLAŞ', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Likes Dialog ───────────────────────────────────────────────
  void _showLikesDialog(List likes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
        height: 400,
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Text('${likes.length} Beğeni', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: ListView.builder(
                itemCount: likes.length,
                itemBuilder: (ctx, i) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(likes[i]).get(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const ListTile(title: Text('...', style: TextStyle(color: Colors.white38)));
                      final d = snap.data!.data() as Map<String, dynamic>?;
                      final name = d?['name'] ?? 'Kullanıcı';
                      final username = d?['username'] ?? '';
                      final pic = d?['profile_pic_url'] ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kOrange.withOpacity(0.2),
                          backgroundImage: pic.startsWith('base64:')
                              ? MemoryImage(base64Decode(pic.substring(7)))
                              : (pic.isNotEmpty ? NetworkImage(pic) : null) as ImageProvider?,
                          child: pic.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: kOrange)) : null,
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: username.isNotEmpty ? Text('@$username', style: const TextStyle(color: Colors.white38, fontSize: 12)) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: likes[i])));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(String postId, List likes) async {
    if (_currentUser == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final isLiked = likes.contains(_currentUser!.uid);

    if (isLiked) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([_currentUser!.uid])
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([_currentUser!.uid])
      });

      // Send notification to post owner
      try {
        final postDoc = await postRef.get();
        final postData = postDoc.data();
        if (postData != null) {
          final postOwnerId = postData['userId'];
          final postOwnerName = postData['user'] ?? 'Birisi';
          
          final myUserDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
          final myName = myUserDoc.data()?['name'] ?? 'Bir kullanıcı';
          final myPic = myUserDoc.data()?['profile_pic_url'] ?? '';

          if (postOwnerId != null && postOwnerId != _currentUser!.uid) {
            await NotificationService.sendLikeNotification(
              toUserId: postOwnerId,
              fromUserId: _currentUser!.uid,
              fromUserName: myName,
              fromUserPic: myPic,
            );
          }
        }
      } catch (e) {
        debugPrint('Like notification error: $e');
      }
    }
  }

  void _sharePost(String userName, String desc, String postId, BuildContext context) {
    final text = '📱 Rota+ Acil Durum & SOS\n'
        '👤 $userName şunu paylaştı:\n'
        '${desc.isNotEmpty ? '"$desc"' : '(Fotoğraf gönderi)'}\n\n'
        '🔗 Rota+ uygulamasında görüntüleyin.';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      text,
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  void _banUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text('$userName Kullanıcısını Yasakla', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Bu kullanıcı banlandığında gönderileri gizlenecek.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(userId).update({'is_banned': true});
              if (ctx.mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$userName yasaklandı.'), backgroundColor: Colors.redAccent));
            },
            child: const Text('YASAKLA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _adminDeletePost(String postId) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi silindi.'), backgroundColor: Colors.redAccent));
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
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kOrange)),
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

  Widget _buildUserName(String userName, String userEmail, bool isPremium) {
    final bool isOwner = userEmail == adminEmail;
    if (isOwner) {
      return ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF6B00), Color(0xFFFFD700), Color(0xFFFF6B00)],
            stops: [0.0, 0.33, 0.66, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds);
        },
        child: Text(
          userName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14,
              shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 8)]),
        ),
      );
    }
    return Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ROTA+ ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
            Text('ACİL DURUM', style: GoogleFonts.outfit(color: kOrange, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, fontStyle: FontStyle.italic)),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              'ACİL DURUM AKIŞI',
              style: GoogleFonts.shareTechMono(color: kOrange, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_unread_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DmListScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostSheet,
        backgroundColor: kOrange,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          _buildAnnouncementBanner(),
          Expanded(child: _buildSocialFeedTab()),
        ],
      ),
    );
  }

  // ── Duyuru Bannerı ─────────────────────────────────────────────
  Widget _buildAnnouncementBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs.where((d) {
          return !_dismissedAnnouncements.contains(d.id);
        }).toList();
        if (docs.isEmpty) return const SizedBox.shrink();

        // En önemli seviye'yi öne çek
        docs.sort((a, b) {
          const order = {'critical': 0, 'warning': 1, 'normal': 2};
          final la = (a.data() as Map)['level'] ?? 'normal';
          final lb = (b.data() as Map)['level'] ?? 'normal';
          return (order[la] ?? 2).compareTo(order[lb] ?? 2);
        });

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              child: PageView(
                onPageChanged: (idx) {
                  if (mounted) {
                    setState(() => _currentAnnouncementIndex = idx);
                  }
                },
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final sev = d['level'] ?? 'normal';
                  final Color sevColor = sev == 'critical'
                      ? Colors.redAccent
                      : sev == 'warning'
                          ? Colors.amber
                          : const Color(0xFF4FC3F7);
                  final IconData sevIcon = sev == 'critical'
                      ? Icons.error_outline
                      : sev == 'warning'
                          ? Icons.warning_amber_outlined
                          : Icons.campaign;

                  return AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: sevColor.withOpacity(0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: sevColor.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: -5,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                // Sol renkli şerit ve ikon alanı
                                Container(
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: sevColor.withOpacity(0.15),
                                    border: Border(right: BorderSide(color: sevColor.withOpacity(0.3), width: 1)),
                                  ),
                                  child: Center(
                                    child: Icon(sevIcon, color: sevColor, size: 24),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              (d['title'] ?? '').toUpperCase(),
                                              style: GoogleFonts.outfit(
                                                color: sevColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () => setState(() => _dismissedAnnouncements.add(doc.id)),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.05),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, color: Colors.white38, size: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              d['body'] ?? '',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white.withOpacity(0.85),
                                                fontSize: 12,
                                                height: 1.4,
                                              ),
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
                        ),
                      ),
                  );
                }).toList(),
              ),
            ),
            if (docs.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(docs.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentAnnouncementIndex == index ? 8 : 6,
                      height: _currentAnnouncementIndex == index ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentAnnouncementIndex == index ? Colors.white : Colors.white24,
                      ),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSocialFeedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: kOrange, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Akış yüklenemedi.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign, color: kOrange.withOpacity(0.4), size: 80),
                const SizedBox(height: 16),
                const Text("Henüz paylaşım yok.\nİlk paylaşımı sen yap!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final posts = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['userId'] as String? ?? '';
          return !_blockedUsers.contains(uid);
        }).toList();
        
        // Premium değilse aralara reklam yerleştir
        final List<dynamic> feedItems = [];
        for (int i = 0; i < posts.length; i++) {
          feedItems.add(posts[i]);
          // Her 5 postta bir reklam (Eğer premium değilse)
          if ((i + 1) % 5 == 0) {
            feedItems.add('AD');
          }
        }

        return ListView.builder(
          itemCount: feedItems.length,
          itemBuilder: (context, index) {
            final item = feedItems[index];

            if (item == 'AD') {
              return FutureBuilder<bool>(
                future: AdService.checkPremiumStatus(),
                builder: (context, premSnap) {
                  if (premSnap.data == true) return const SizedBox.shrink();
                  return const _InlineAdWidget();
                },
              );
            }

            final postDoc = item as DocumentSnapshot;
            final data = postDoc.data() as Map<String, dynamic>;

            final String docId = postDoc.id;
            final String user = data['user'] ?? 'Bilinmeyen';
            final String userEmail = data['userEmail'] ?? '';
            final bool isPremium = data['isPremium'] ?? false;
            final String desc = data['desc'] ?? '';
            final String imageUrl = data['imageUrl'] ?? '';
            final List likes = data['likes'] is List ? data['likes'] : [];
            final bool isLiked = _currentUser != null && likes.contains(_currentUser!.uid);
            final String userId = data['userId'] ?? '';
            final bool isVerified = userEmail == adminEmail || isPremium;
            final bool isMyPost = _currentUser != null && _currentUser!.uid == userId;
            final bool isOwnProfile = _currentUser != null && _currentUser!.uid == userId;
            final Map<String, dynamic>? routeData = data['routeData'];
            final String postType = data['postType'] ?? '';

            // Kullanıcı profilini cache'le (resim flickering önler)
            if (!_userCache.containsKey(userId) && userId.isNotEmpty) {
              FirebaseFirestore.instance.collection('users').doc(userId).get().then((snap) {
                if (snap.exists && mounted) {
                  setState(() => _userCache[userId] = snap.data() as Map<String, dynamic>);
                }
              });
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Builder(builder: (ctx) {
                      final cached = _userCache[userId];
                      String picUrl = cached?['profile_pic_url'] ?? '';
                      bool isBanned = cached?['is_banned'] ?? false;
                      if (isBanned && !_isAdmin) return const SizedBox.shrink();

                      return Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (userId.isNotEmpty) {
                                if (isOwnProfile) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: userId)));
                                }
                              }
                            },
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: kOrange.withOpacity(0.2),
                              backgroundImage: picUrl.startsWith('base64:')
                                  ? MemoryImage(base64Decode(picUrl.substring(7)))
                                  : (picUrl.isNotEmpty ? NetworkImage(picUrl) : null) as ImageProvider?,
                              child: picUrl.isEmpty
                                  ? Text(user.isNotEmpty ? user[0].toUpperCase() : '?', style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (userId.isNotEmpty) {
                                    if (isOwnProfile) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                                    } else {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: userId)));
                                    }
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildUserName(user, userEmail, isPremium),
                                        const SizedBox(width: 4),
                                        if (!isVerified && isPremium) const Icon(Icons.stars, color: Colors.amber, size: 14),
                                        if (isVerified)
                                          Container(
                                            margin: const EdgeInsets.only(left: 2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 6)],
                                            ),
                                            child: const Icon(Icons.verified, color: Colors.blueAccent, size: 15),
                                          ),
                                        if (postType == 'route')
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF62FF4C).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF62FF4C).withOpacity(0.4)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.route, size: 10, color: Color(0xFF62FF4C)),
                                                SizedBox(width: 3),
                                                Text('ROTA', style: TextStyle(fontSize: 9, color: Color(0xFF62FF4C), fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54),
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    await FirebaseFirestore.instance.collection('posts').doc(docId).delete();
                                  } else if (value == 'edit') {
                                    _showEditPostDialog(docId, desc);
                                  } else if (value == 'report') {
                                    _reportPost(docId, userId);
                                  } else if (value == 'block') {
                                    _blockUser(userId);
                                  } else if (value == 'ban' && _isAdmin) {
                                    _banUser(userId, user);
                                  } else if (value == 'admin_delete' && _isAdmin) {
                                    _adminDeletePost(docId);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (isMyPost) ...[
                                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                    const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
                                  ],
                                  if (_isAdmin && !isMyPost) ...[
                                    const PopupMenuItem(
                                      value: 'admin_delete',
                                      child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 16), SizedBox(width: 8), Text('Admin: Sil', style: TextStyle(color: Colors.red))]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'ban',
                                      child: Row(children: [Icon(Icons.block, color: Colors.orange, size: 16), SizedBox(width: 8), Text('Admin: Yasakla', style: TextStyle(color: Colors.orange))]),
                                    ),
                                  ],
                                  if (_currentUser != null && !isMyPost) ...[
                                    const PopupMenuItem(
                                      value: 'report',
                                      child: Row(children: [Icon(Icons.flag, color: Colors.orange, size: 16), SizedBox(width: 8), Text('Şikayet Et', style: TextStyle(color: Colors.orange))]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'block',
                                      child: Row(children: [Icon(Icons.block, color: Colors.red, size: 16), SizedBox(width: 8), Text('Kullanıcıyı Engelle', style: TextStyle(color: Colors.red))]),
                                    ),
                                  ],
                                ],
                              )
                          ],
                        );
                      }),
                  ),

                  // Content
                  if (imageUrl.isNotEmpty)
                    GestureDetector(
                      onDoubleTap: () => _toggleLike(docId, likes),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 400),
                        color: Colors.black,
                        child: imageUrl.startsWith('base64:')
                            ? Image.memory(base64Decode(imageUrl.substring(7)), fit: BoxFit.cover)
                            : Image.network(imageUrl, fit: BoxFit.cover),
                      ),
                    )
                  else if (postType == 'route' && routeData != null)
                    _buildSocialRouteCard(routeData)
                  else if (desc.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF141414), kOrange.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text('"$desc"', style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic, height: 1.5)),
                    )
                  else
                    Container(
                      height: 100,
                      width: double.infinity,
                      color: kCardBg,
                      child: Center(child: Icon(Icons.campaign, color: kOrange.withOpacity(0.15), size: 64)),
                    ),

                  // Action row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(docId, likes),
                          onLongPress: () => _showLikesDialog(likes),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.redAccent : Colors.white70,
                                  size: 24,
                                ),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () => _showLikesDialog(likes),
                                  child: Text(
                                    '${likes.length}',
                                    style: TextStyle(
                                      color: isLiked ? Colors.redAccent : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showCommentsBottomSheet(docId),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('posts').doc(docId).collection('comments').snapshots(),
                              builder: (ctx, cSnap) {
                                final count = cSnap.data?.docs.length ?? 0;
                                return Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 22),
                                    const SizedBox(width: 5),
                                    Text('$count', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share_outlined, color: Colors.white54, size: 22),
                          onPressed: () => _sharePost(user, desc, docId),
                        ),
                      ],
                    ),
                  ),

                  if (desc.isNotEmpty && imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: '$user ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            TextSpan(text: desc, style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),

                  const Divider(color: Colors.white10, height: 1),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoutesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('routes').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kOrange));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white38)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_off, color: kOrange.withOpacity(0.3), size: 64),
                const SizedBox(height: 16),
                const Text('Henüz yayınlanmış bir rota bulunamadı.', style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }

        final routes = snapshot.data!.docs;
        return ListView.builder(
          itemCount: routes.length,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemBuilder: (context, index) {
            final routeData = routes[index].data() as Map<String, dynamic>;
            return _buildOfficialRouteCard(routeData);
          },
        );
      },
    );
  }

  Widget _buildOfficialRouteCard(Map<String, dynamic> routeData) {
    final name = routeData['name'] ?? 'İsimsiz Rota';
    final desc = routeData['description'] ?? '';
    final distance = (routeData['distance'] ?? 0.0) as num;
    final points = routeData['points'] as List?;
    final duration = routeData['estimatedTime'] ?? '--';

    final distStr = distance >= 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.toInt()} m';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kOrange.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.navigation_outlined, color: kOrange, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.toUpperCase(), style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
                      const Text('RESMİ ROTA VERİSİ', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTacticalStatChip(Icons.straighten, distStr, Colors.orange),
                _buildTacticalStatChip(Icons.timer, duration, Colors.cyan),
                _buildTacticalStatChip(Icons.push_pin, '${points?.length ?? 0} durak', Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kOrange,
                      side: const BorderSide(color: Colors.white10),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      if (points != null) _showRouteOnMap(points, name);
                    },
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('HARİTA'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (points != null) {
                        final parsedPoints = points.map((e) => {
                          'lat': (e['lat'] as num).toDouble(),
                          'lng': (e['lng'] as num).toDouble()
                        }).toList();
                        final id = await DatabaseHelper.instance.rotaKaydet(name, parsedPoints);
                        await DatabaseHelper.instance.rotayiAktifYap(id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Rota Başlatıldı!'),
                            backgroundColor: kOrange,
                          ));
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveTrackingScreen()));
                        }
                      }
                    },
                    icon: const Icon(Icons.directions_walk, size: 18),
                    label: const Text('YÜRÜ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Zorluk seviyesi hesapla
  Map<String, dynamic> _calcDifficulty(double distKm, double elevGain) {
    if (distKm <= 5 && elevGain <= 300) return {'label': 'KOLAY', 'color': const Color(0xFF62FF4C), 'icon': Icons.sentiment_satisfied_alt};
    if (distKm <= 15 && elevGain <= 800) return {'label': 'ORTA', 'color': Colors.amberAccent, 'icon': Icons.sentiment_neutral};
    if (distKm <= 30 && elevGain <= 1500) return {'label': 'ZOR', 'color': const Color(0xFFFF6B00), 'icon': Icons.sentiment_dissatisfied};
    return {'label': 'EXTREME', 'color': Colors.redAccent, 'icon': Icons.whatshot};
  }

  Widget _buildSocialRouteCard(Map<String, dynamic> routeData) {
    final String name = routeData['name'] ?? 'İsimsiz Rota';
    final double distance = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
    final int duration = (routeData['duration_seconds'] as num?)?.toInt() ?? 0;
    final double elevation = (routeData['elevation_gain'] as num?)?.toDouble() ?? 0.0;
    final int steps = (routeData['steps'] as num?)?.toInt() ?? 0;
    final List coords = routeData['coordinates'] is List ? routeData['coordinates'] : [];
    
    // Zaman damgasını al
    String dateStr = '';
    if (routeData['timestamp'] != null) {
      if (routeData['timestamp'] is Timestamp) {
        final date = (routeData['timestamp'] as Timestamp).toDate();
        dateStr = '${date.day}.${date.month}.${date.year}';
      } else if (routeData['timestamp'] is String) {
        dateStr = routeData['timestamp'].toString().substring(0, 10);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Bilgi: Runner İkonu + Başlık + Badge + Paylaş
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kOrange.withOpacity(0.3)),
                ),
                child: const Icon(Icons.directions_run, color: kOrange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kOrange.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Canlı Takip',
                        style: GoogleFonts.outfit(color: kOrange, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final String rName = routeData['name'] ?? 'İsimsiz Rota';
                  final List rCoords = routeData['coordinates'] is List ? routeData['coordinates'] : [];
                  if (rCoords.isEmpty) return;
                  final noktalar = rCoords.map((e) => {'lat': (e['lat'] as num).toDouble(), 'lng': (e['lng'] as num).toDouble()}).toList();
                  final id = await DatabaseHelper.instance.rotaKaydet(rName, noktalar);
                  await DatabaseHelper.instance.rotayiAktifYap(id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota aktifleştirildi!'), backgroundColor: kOrange));
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveTrackingScreen()));
                  }
                },
                icon: const Icon(Icons.directions_run, size: 16),
                label: const Text('Yürü'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF62FF4C),
                  side: const BorderSide(color: Color(0xFF62FF4C)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Güzergah: Başlangıç ve Bitiş
          Row(
            children: [
              const Column(
                children: [
                  Icon(Icons.trip_origin, color: Colors.greenAccent, size: 18),
                  SizedBox(height: 4),
                  SizedBox(width: 2, height: 20, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white10))),
                  SizedBox(height: 4),
                  Icon(Icons.flag, color: Colors.redAccent, size: 18),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeData['from'] ?? 'Canlı Takip Başlangıcı',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      routeData['to'] ?? 'Canlı Takip Bitişi',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // İstatistik Kutucukları (Chips)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatChip('${distance.toInt()} m', Icons.straighten, kOrange),
              _buildStatChip('${duration ~/ 60} dk', Icons.timer_outlined, Colors.cyanAccent),
              _buildStatChip('${elevation.toInt()} m İrtifa', Icons.height, Colors.purpleAccent),
              _buildStatChip('$steps adım', Icons.directions_walk, Colors.yellowAccent),
            ],
          ),

          const SizedBox(height: 20),

          // Alt Bilgi: Nokta sayısı ve Tarih
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${coords.length} nokta',
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),

          // Harita Önizleme
          if (coords.length >= 2) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: () => _showRouteOnMap(coords, name),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: _FeedMiniMap(coords: coords),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          // Rota Başlat Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final noktalar = coords.map((e) => {'lat': (e['lat'] as num).toDouble(), 'lng': (e['lng'] as num).toDouble()}).toList();
                final id = await DatabaseHelper.instance.rotaKaydet(name, noktalar);
                await DatabaseHelper.instance.rotayiAktifYap(id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rota aktifleştirildi!'), backgroundColor: kOrange));
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveTrackingScreen()));
                }
              },
              icon: const Icon(Icons.directions_walk, color: Colors.black, size: 18),
              label: const Text('Bu Rotayı Yürü', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> routeData) {
    // This is for the "Rotalarım" profile screen tab (Profile personal routes)
    return _buildUserRouteCard(routeData);
  }

  Widget _buildUserRouteCard(Map<String, dynamic> routeData) {
    final name = routeData['name'] ?? 'İsimsiz Rota';
    final distance = (routeData['distance'] ?? 0.0) as num;
    final distStr = distance >= 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.toInt()} m';
    final durationSec = (routeData['duration_seconds'] as num?)?.toInt() ?? 0;
    final elevGain = (routeData['elevation_gain'] as num?)?.toDouble() ?? 0;
    final maxAlt = (routeData['max_altitude'] as num?)?.toDouble() ?? 0;
    final List coords = routeData['coordinates'] is List ? routeData['coordinates'] : [];

    String durationStr = '0 dk';
    if (durationSec > 0) {
      final h = durationSec ~/ 3600;
      final m = (durationSec % 3600) ~/ 60;
      durationStr = h > 0 ? '${h}s ${m}dk' : '${m} dk';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kOrange.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.history, color: kOrange, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(name.toUpperCase(), style: GoogleFonts.shareTechMono(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTacticalStatChip(Icons.straighten, distStr, Colors.orange),
                _buildTacticalStatChip(Icons.timer, durationStr, Colors.cyan),
                if (elevGain > 0) _buildTacticalStatChip(Icons.height, '+${elevGain.toInt()}m', Colors.purpleAccent),
                if (maxAlt > 0) _buildTacticalStatChip(Icons.landscape, '${maxAlt.toInt()}m max', Colors.blueAccent),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                if (coords.isNotEmpty)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: kOrange, side: const BorderSide(color: Colors.white10)),
                      onPressed: () => _showRouteOnMap(coords, name),
                      child: const Text('HARİTADA GÖR'),
                    ),
                  ),
                if (coords.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black),
                    onPressed: () async {
                      final noktalar = coords.map((e) => {'lat': (e['lat'] as num).toDouble(), 'lng': (e['lng'] as num).toDouble()}).toList();
                      final id = await DatabaseHelper.instance.rotaKaydet(name, noktalar);
                      await DatabaseHelper.instance.rotayiAktifYap(id);
                      if (mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveTrackingScreen()));
                      }
                    },
                    child: const Text('TEKRAR YÜRÜ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatusLine(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildFeedStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showRouteOnMap(List coords, String routeName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.9,
        decoration: const BoxDecoration(color: Color(0xFF0A0A0A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.route, color: Color(0xFF62FF4C), size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(routeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          const Divider(color: Colors.white10),
          Expanded(child: _RouteMapViewer(coords: coords)),
        ]),
      ),
    );
  }
}


// ─── Inline route map viewer using Mapbox ────────────────────────────────
class _RouteMapViewer extends StatefulWidget {
  final List coords;
  const _RouteMapViewer({required this.coords});

  @override
  State<_RouteMapViewer> createState() => _RouteMapViewerState();
}

class _RouteMapViewerState extends State<_RouteMapViewer> {
  mbx.MapboxMap? _mapboxMap;

  void _onMapCreated(mbx.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    final points = widget.coords.map((c) => ll.LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble())).toList();
    if (points.isEmpty) return;

    final polylineManager = await _mapboxMap?.annotations.createPolylineAnnotationManager();
    final pointManager = await _mapboxMap?.annotations.createCircleAnnotationManager();

    // Rota Çizimi
    final line = mbx.PolylineAnnotationOptions(
      geometry: mbx.LineString(coordinates: points.map((p) => mbx.Position(p.longitude, p.latitude)).toList()),
      lineColor: const Color(0xFF62FF4C).value,
      lineWidth: 3.5,
    );
    await polylineManager?.create(line);

    // Başlangıç ve Bitiş İşaretçileri
    final startMarker = mbx.CircleAnnotationOptions(
      geometry: mbx.Point(coordinates: mbx.Position(points.first.longitude, points.first.latitude)),
      circleRadius: 6.0,
      circleColor: const Color(0xFF62FF4C).value,
      circleStrokeWidth: 2.0,
      circleStrokeColor: Colors.white.value,
    );
    await pointManager?.create(startMarker);

    if (points.length > 1) {
      final endMarker = mbx.CircleAnnotationOptions(
        geometry: mbx.Point(coordinates: mbx.Position(points.last.longitude, points.last.latitude)),
        circleRadius: 6.0,
        circleColor: Colors.redAccent.value,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      );
      await pointManager?.create(endMarker);
    }

    // Kamera Odaklama (Bounds hesaplama basitleştirilmiş)
    final lats = points.map((p) => p.latitude).toList()..sort();
    final lngs = points.map((p) => p.longitude).toList()..sort();
    final centerLat = (lats.first + lats.last) / 2;
    final centerLng = (lngs.first + lngs.last) / 2;

    _mapboxMap?.setCamera(mbx.CameraOptions(
      center: mbx.Point(coordinates: mbx.Position(centerLng, centerLat)),
      zoom: 13.0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.coords.isEmpty) {
      return const Center(child: Text('Koordinat bulunamadı.', style: TextStyle(color: Colors.white54)));
    }

    return mbx.MapWidget(
      key: ValueKey("route_viewer_${widget.coords.hashCode}"),
      onMapCreated: _onMapCreated,
      styleUri: mbx.MapboxStyles.OUTDOORS,
    );
  }
}


// ─── Feed'deki mini rota önizlemesi (Statik Harita) ───
class _FeedMiniMap extends StatelessWidget {
  final List coords;
  const _FeedMiniMap({required this.coords});

  @override
  Widget build(BuildContext context) {
    if (coords.isEmpty) return const SizedBox.shrink();

    final points = coords.map((c) => ll.LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble())).toList();
    
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = fm.LatLngBounds(ll.LatLng(minLat, minLng), ll.LatLng(maxLat, maxLng));

    return AbsorbPointer(
      child: fm.FlutterMap(
        options: fm.MapOptions(
          initialCameraFit: fm.CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(16)),
          interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.none),
        ),
        children: [
          fm.TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
          ),
          fm.PolylineLayer(
            polylines: [
              fm.Polyline(
                points: points,
                color: const Color(0xFF62FF4C),
                strokeWidth: 3.5,
              ),
            ],
          ),
          fm.MarkerLayer(
            markers: [
              fm.Marker(
                point: points.first,
                width: 14, height: 14,
                child: Container(decoration: BoxDecoration(color: const Color(0xFF62FF4C), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
              ),
              if (points.length > 1)
                fm.Marker(
                  point: points.last,
                  width: 14, height: 14,
                  child: Container(decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineAdWidget extends StatefulWidget {
  const _InlineAdWidget({Key? key}) : super(key: key);

  @override
  State<_InlineAdWidget> createState() => _InlineAdWidgetState();
}

class _InlineAdWidgetState extends State<_InlineAdWidget> {
  bool _isLoaded = false;
  Widget? _adWidget;

  @override
  void initState() {
    super.initState();
    _adWidget = AdService().buildNativeAd(
      onAdLoaded: () {
        if (mounted) setState(() => _isLoaded = true);
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) setState(() => _isLoaded = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _adWidget == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AD', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              const Text('Önerilen İçerik', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: _adWidget,
          ),
        ],
      ),
    );
  }

  void _walkThisRoute(Map<String, dynamic> routeData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
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
            Text('${routeData['name'] ?? 'Bu rota'}', style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            const Text('Bu rotayı yürümek için "Takip" sekmesinden GPS takibini başlatın ve rotanız boyunca ilerlediğinizde istatistikleriniz kaydedilecektir.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            const Text('İPUCU: Rota koordinatları Rota sekmesinde görüntülenebilir.', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT', style: TextStyle(color: Colors.white38))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF62FF4C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
                );
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Rota kaydedildi! "Rota" sekmesinden seçip takibe başlayabilirsiniz.'),
                  backgroundColor: Color(0xFF43A047),
                ));
              }
            },
            icon: const Icon(Icons.play_arrow, color: Colors.black, size: 18),
            label: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
