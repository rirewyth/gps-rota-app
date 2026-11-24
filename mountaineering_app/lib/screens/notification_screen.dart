import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import '../services/tactical_styles.dart';

const String _kAdminEmailNotif = 'sercanoral65@gmail.com';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kBackground = TacticalStyles.kSurface;
  static const Color kCardBg = TacticalStyles.kSurfaceLow;

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
        centerTitle: true,
        title: TacticalStyles.appBarPill('BİLDİRİMLER', icon: Icons.notifications_active_outlined),
        backgroundColor: TacticalStyles.kSurfaceLowest,
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
            child: Text('Tümünü Oku', style: TacticalStyles.labelCaps(color: kOrange, size: 10.5)),
          ),
          TextButton(
            onPressed: () async {
              final col = FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(myUid)
                  .collection('items');
              final items = await col.get();
              if (items.docs.isEmpty) return;
              final batch = FirebaseFirestore.instance.batch();
              for (final doc in items.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm bildirimler silindi.'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: Text('Tümünü Sil', style: TacticalStyles.labelCaps(color: Colors.redAccent, size: 10.5)),
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
                  if (type == 'nexus_dispatch' ||
                      data['reportId'] != null ||
                      data['fullAddress'] != null ||
                      type == 'admin') {
                    _showDispatchDetailSheet(context, data);
                  } else if (type == 'follow' && fromUserId.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileScreen(targetUserId: fromUserId),
                    ));
                  } else if (type == 'message' && fromUserId.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(targetUserId: fromUserId, targetUserName: fromUserName),
                    ));
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: TacticalStyles.glassCardDecoration(
                    radius: 16,
                    borderColor: isRead ? null : kOrange.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            Row(
                              children: [
                                Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                if (type == 'nexus_dispatch' || data['reportId'] != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.45)),
                                    ),
                                    child: const Text(
                                      'GÖREV DETAYI İÇİN DOKUN →',
                                      style: TextStyle(color: Colors.cyanAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
            backgroundColor: kCardBg,
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
                    fillColor: TacticalStyles.kSurfaceLowest,
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

  void _showDispatchDetailSheet(BuildContext context, Map<String, dynamic> data) {
    final reportId = (data['reportId'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TacticalStyles.kSurfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: reportId.isNotEmpty
              ? FirebaseFirestore.instance.collection('disaster_reports').doc(reportId).get()
              : Future.value(null),
          builder: (ctx, snap) {
            final rep = snap.data?.data();
            final disasterType = (rep?['disasterType'] ?? data['disasterType'] ?? 'GÖREV YÖNLENDİRME').toString();
            final province = (rep?['province'] ?? data['province'] ?? '').toString().trim();
            final district = (rep?['district'] ?? data['district'] ?? '').toString().trim();
            final neighborhood = (rep?['neighborhood'] ?? data['neighborhood'] ?? '').toString().trim();
            final street = (rep?['street'] ?? data['street'] ?? '').toString().trim();
            final fullAddress = (rep?['fullAddress'] ?? data['fullAddress'] ?? '').toString().trim();
            final dateTimeStr = (rep?['dateTimeStr'] ?? data['dateTimeStr'] ?? '').toString().trim();
            final reporterName = (rep?['reporterName'] ?? data['reporterName'] ?? '').toString().trim();
            final reporterPhone = (rep?['reporterPhone'] ?? data['reporterPhone'] ?? '').toString().trim();
            final summary = (rep?['summary'] ?? data['summary'] ?? '').toString().trim();
            final note = (data['note'] ?? '').toString().trim();
            final rawText = (data['text'] ?? '').toString().trim();
            final imgB64 = (rep?['imageBase64'] ?? '').toString().trim();
            final lat = ((rep?['lat'] ?? data['lat']) as num?)?.toDouble();
            final lng = ((rep?['lng'] ?? data['lng']) as num?)?.toDouble();

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            disasterType.toUpperCase(),
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'KOMUTA MERKEZİ GÖREV RAPORU',
                            style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: TacticalStyles.recessedDecoration(radius: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DETAYLI KONUM & ADRES RAPORU',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _detailRow('İl', province.isNotEmpty ? province : 'Belirtilmedi'),
                          _detailRow('İlçe', district.isNotEmpty ? district : 'Belirtilmedi'),
                          _detailRow('Mahalle', neighborhood.isNotEmpty ? neighborhood : 'Belirtilmedi'),
                          _detailRow('Sokak / Cadde', street.isNotEmpty ? street : 'Belirtilmedi'),
                          if (fullAddress.isNotEmpty) _detailRow('Açık Adres', fullAddress, valueColor: Colors.amberAccent),
                          _detailRow(
                            'GPS Koordinatı',
                            (lat != null && lng != null)
                                ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                                : 'Konum yok',
                            valueColor: Colors.cyanAccent,
                          ),
                          if (dateTimeStr.isNotEmpty) _detailRow('İhbar Zamanı', dateTimeStr),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: TacticalStyles.recessedDecoration(radius: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'İHBARCI & OLAY ÖZETİ',
                            style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '👤 İhbarcı: ${reporterName.isNotEmpty ? reporterName : '-'}   •   📞 ${reporterPhone.isNotEmpty ? reporterPhone : '-'}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary.isNotEmpty ? summary : rawText,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    if (imgB64.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(imgB64),
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kOrange.withValues(alpha: 0.45)),
                        ),
                        child: Text('📌 Komuta Notu: $note', style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (lat != null && lng != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.directions, color: Colors.white, size: 18),
                              label: const Text('HARİTADA AÇ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        if (lat != null && lng != null && reporterPhone.isNotEmpty) const SizedBox(width: 10),
                        if (reporterPhone.isNotEmpty)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse('tel:${reporterPhone.replaceAll(' ', '')}');
                                await launchUrl(uri);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                              label: const Text('İHBARCIYI ARA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text('$label:', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: valueColor, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
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
