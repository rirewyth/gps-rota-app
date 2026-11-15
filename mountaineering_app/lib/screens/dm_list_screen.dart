import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../services/tactical_styles.dart';

const Color kOrange = TacticalStyles.kPrimaryContainer;
const Color kBackground = TacticalStyles.kSurface;
const Color kCardBg = TacticalStyles.kSurfaceLow;

class DmListScreen extends StatefulWidget {
  const DmListScreen({Key? key}) : super(key: key);

  @override
  State<DmListScreen> createState() => _DmListScreenState();
}

class _DmListScreenState extends State<DmListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(
        backgroundColor: kBackground,
        body: Center(child: Text('Giriş yapılmadı.', style: TextStyle(color: Colors.white))),
      );
    }

    final myUid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: TacticalStyles.kOnSurface),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kOrange.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kOrange.withOpacity(0.35)),
              ),
              child: const Icon(Icons.forum_outlined, color: TacticalStyles.kPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'ROTA+',
                        style: TacticalStyles.headline(
                          color: TacticalStyles.kOnSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TacticalStyles.kPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'MESAJLAR',
                          style: TacticalStyles.labelMicro(
                            color: TacticalStyles.kPrimary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Operatörler Arası Güvenli İletişim',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TacticalStyles.labelCaps(
                      color: TacticalStyles.kOnSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(height: 1, child: ColoredBox(color: TacticalStyles.kOutlineVariant)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('chats')
            .where('participants', arrayContains: myUid)
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
                  Icon(Icons.mark_email_unread_outlined, color: kOrange.withOpacity(0.5), size: 60),
                  const SizedBox(height: 16),
                  const Text('Henüz mesajın yok.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Profil sayfasından birine mesaj gönderebilirsin.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: chats.length,
            itemBuilder: (ctx, idx) {
              final chatData = chats[idx].data() as Map<String, dynamic>;
              final List participants = chatData['participants'] ?? [];
              final String otherUid = participants.firstWhere((id) => id != myUid, orElse: () => '');
              final String lastMsg = chatData['last_message'] ?? '...';
              
              if (otherUid.isEmpty) return const SizedBox.shrink();

              // Fetch other user's info
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                     return const SizedBox.shrink();
                  }

                  final uData = userSnap.data!.data() as Map<String, dynamic>;
                  final name = uData['name'] ?? 'Bilinmeyen';
                  final username = uData['username'] ?? '';
                  final picUrl = uData['profile_pic_url'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TacticalPressable(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                          targetUserId: otherUid,
                          targetUserName: name,
                        )));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: TacticalStyles.glassCardDecoration(radius: 16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: otherUid)),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kOrange.withOpacity(0.45), width: 1.5),
                                ),
                                child: CircleAvatar(
                                  radius: 23,
                                  backgroundColor: kOrange.withOpacity(0.18),
                                  backgroundImage: picUrl.isNotEmpty
                                    ? (picUrl.startsWith('base64:')
                                        ? MemoryImage(base64Decode(picUrl.substring(7)))
                                        : NetworkImage(picUrl) as ImageProvider)
                                    : null,
                                  child: picUrl.isEmpty
                                    ? Text(name[0].toUpperCase(), style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 17))
                                    : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username.isNotEmpty ? '@$username' : name,
                                    style: TacticalStyles.headline(color: TacticalStyles.kOnSurface, fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    lastMsg,
                                    style: TacticalStyles.body(color: TacticalStyles.kOnSurfaceVariant, fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, color: TacticalStyles.kOutline, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
