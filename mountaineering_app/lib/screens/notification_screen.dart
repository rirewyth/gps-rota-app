import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

const String _kAdminEmailNotif = 'sercanoral65@gmail.com';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kCardBg = Color(0xFF141414);

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      return const Scaffold(
        backgroundColor: kBackground,
        body: Center(child: Text('Giriş yapılmadı.', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('Acil Durum Bildirimleri', style: GoogleFonts.outfit(color: kOrange, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (FirebaseAuth.instance.currentUser?.email == _kAdminEmailNotif)
            IconButton(
              icon: const Icon(Icons.campaign, color: kOrange),
              tooltip: 'Acil Durum Duyurusu Gönder',
              onPressed: () => _showBroadcastDialog(context),
            ),
          TextButton(
            onPressed: () async {
              final col = FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(myUid)
                  .collection('items');
              final items = await col.where('isRead', isEqualTo: false).get();
              for (final doc in items.docs) {
                await doc.reference.update({'isRead': true});
              }
            },
            child: const Text('Tümünü Oku', style: TextStyle(color: kOrange, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .doc(myUid)
            .collection('items')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kOrange));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 72, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('Henüz acil durum bildirimi yok.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            );
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final data = items[i].data() as Map<String, dynamic>;
              final type = data['type'] ?? 'follow';
              final fromUserId = data['fromUserId'] ?? '';
              final fromUserName = data['fromUserName'] ?? 'Birisi';
              final fromUserPic = data['fromUserPic'] ?? '';
              final text = data['text'] ?? '';
              final isRead = data['isRead'] ?? false;
              final chatId = data['chatId'] ?? '';
              final docId = items[i].id;

              final Timestamp? ts = data['timestamp'];
              final timeStr = ts != null ? _formatTime(ts.toDate()) : '';

              return InkWell(
                onTap: () async {
                  // Mark as read
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(myUid)
                      .collection('items')
                      .doc(docId)
                      .update({'isRead': true});

                  if (!context.mounted) return;
                  if (type == 'follow' && fromUserId.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileScreen(targetUserId: fromUserId),
                    ));
                  } else if (type == 'message' && fromUserId.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(targetUserId: fromUserId, targetUserName: fromUserName),
                    ));
                  } else if (type == 'admin') {
                    // Admin bildirimleri okunarak kapatılır
                  }
                },
                child: Container(
                  color: isRead ? Colors.transparent : kOrange.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: kOrange.withOpacity(0.2),
                            backgroundImage: fromUserPic.startsWith('base64:')
                                ? MemoryImage(base64Decode(fromUserPic.substring(7)))
                                : (fromUserPic.isNotEmpty ? NetworkImage(fromUserPic) : null) as ImageProvider?,
                            child: (fromUserPic.isEmpty)
                                ? Text(
                                    fromUserName.isNotEmpty ? fromUserName[0].toUpperCase() : '?',
                                    style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: type == 'follow' 
                                    ? Colors.blueAccent 
                                    : type == 'like' 
                                        ? Colors.redAccent 
                                        : type == 'team_sos' || type == 'sos'
                                            ? Colors.red
                                            : kOrange,
                                shape: BoxShape.circle,
                                border: Border.all(color: kBackground, width: 1.5),
                              ),
                              child: Icon(
                                type == 'follow'
                                    ? Icons.person_add
                                    : type == 'like'
                                        ? Icons.favorite
                                        : type == 'team_sos' || type == 'sos'
                                            ? Icons.warning_amber_rounded
                                            : Icons.message,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: fromUserName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  TextSpan(
                                    text: ' $text',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  void _showBroadcastDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          bool sending = false;
          return AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: const [
              Icon(Icons.campaign, color: kOrange, size: 24),
              SizedBox(width: 10),
              Text('Acil Durum Duyurusu Gönder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.purpleAccent, size: 14),
                    SizedBox(width: 8),
                    Expanded(child: Text('Bu acil durum duyurusu uygulamadaki TÜM kullanıcılara gönderilecek.', style: TextStyle(color: Colors.purpleAccent, fontSize: 11))),
                  ]),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Acil durum mesajını girin...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kOrange)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: sending ? null : () async {
                  final msg = ctrl.text.trim();
                  if (msg.isEmpty) return;
                  setD(() => sending = true);
                  try {
                    final users = await FirebaseFirestore.instance.collection('users').get();
                    final batches = <WriteBatch>[];
                    WriteBatch currentBatch = FirebaseFirestore.instance.batch();
                    int count = 0;
                    for (final userDoc in users.docs) {
                      final notifRef = FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(userDoc.id)
                          .collection('items')
                          .doc();
                      currentBatch.set(notifRef, {
                        'type': 'admin',
                        'fromUserId': 'admin',
                        'fromUserName': 'Rota Plus Emniyetteyim Yönetim',
                        'fromUserPic': '',
                        'text': msg,
                        'isRead': false,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      count++;
                      if (count % 450 == 0) {
                        batches.add(currentBatch);
                        currentBatch = FirebaseFirestore.instance.batch();
                      }
                    }
                    batches.add(currentBatch);
                    for (final b in batches) { await b.commit(); }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✔ Bildirim ${users.docs.length} kullanıcıya gönderildi!'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    }
                  } catch (e) {
                    setD(() => sending = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
                icon: const Icon(Icons.send, color: Colors.black, size: 16),
                label: const Text('GÖNDER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Bildirim gönderme yardımcı fonksiyonu
class NotificationService {
  static Future<void> sendFollowNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    String fromUserPic = '',
  }) async {
    if (toUserId == fromUserId) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(toUserId)
        .collection('items')
        .add({
      'type': 'follow',
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPic': fromUserPic,
      'text': 'seni takip etmeye başladı.',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendMessageNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String messageText,
    String fromUserPic = '',
  }) async {
    if (toUserId == fromUserId) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(toUserId)
        .collection('items')
        .add({
      'type': 'message',
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPic': fromUserPic,
      'text': 'sana mesaj gönderdi: "$messageText"',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendLikeNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    String fromUserPic = '',
  }) async {
    if (toUserId == fromUserId) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(toUserId)
        .collection('items')
        .add({
      'type': 'like',
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPic': fromUserPic,
      'text': 'gönderini beğendi.',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendTeamSOSNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    String fromUserPic = '',
  }) async {
    if (toUserId == fromUserId) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(toUserId)
        .collection('items')
        .add({
      'type': 'team_sos',
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPic': fromUserPic,
      'text': 'acıl durum bildirdi! Hemen konumunu kontrol edin.',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
