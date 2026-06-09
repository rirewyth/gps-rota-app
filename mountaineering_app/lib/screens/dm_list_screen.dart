import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);

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
        title: Text('Mesajlar', style: GoogleFonts.outfit(color: kOrange, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: otherUid)),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: kOrange.withOpacity(0.2),
                        backgroundImage: picUrl.isNotEmpty
                          ? (picUrl.startsWith('base64:')
                              ? MemoryImage(base64Decode(picUrl.substring(7)))
                              : NetworkImage(picUrl) as ImageProvider)
                          : null,
                        child: picUrl.isEmpty
                          ? Text(name[0].toUpperCase(), style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 18))
                          : null,
                      ),
                    ),
                    title: Text(
                      username.isNotEmpty ? '@$username' : name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      lastMsg,
                      style: const TextStyle(color: Colors.white54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                        targetUserId: otherUid,
                        targetUserName: name,
                      )));
                    },
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
