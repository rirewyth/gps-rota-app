import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);

class FollowersScreen extends StatelessWidget {
  final String userId;
  final String type; // 'followers' or 'following'
  
  const FollowersScreen({Key? key, required this.userId, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(type == 'followers' ? 'Takipçiler' : 'Takip Edilenler', 
          style: GoogleFonts.outfit(color: kOrange, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kOrange));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Kullanıcı bulunamadı', style: TextStyle(color: Colors.white54)));
          }
          
          final uData = snapshot.data!.data() as Map<String, dynamic>?;
          if (uData == null) return const SizedBox.shrink();
          
          List userIds = uData[type] is List ? uData[type] : [];
          
          if (userIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(type == 'followers' ? Icons.people_outline : Icons.person_search, color: kOrange.withOpacity(0.5), size: 60),
                  const SizedBox(height: 16),
                  Text(type == 'followers' ? 'Henüz takipçi yok.' : 'Henüz kimse takip edilmiyor.', 
                    style: const TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (ctx, idx) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userIds[idx]).get(),
                builder: (ctx, uSnap) {
                  if (!uSnap.hasData || !uSnap.data!.exists) return const SizedBox.shrink();
                  
                  final d = uSnap.data!.data() as Map<String, dynamic>;
                  final name = d['name'] ?? 'Bilinmeyen';
                  final username = d['username'] ?? '';
                  final picUrl = d['profile_pic_url'] ?? '';
                  final String role = d['role'] ?? '';
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: kOrange.withOpacity(0.2),
                      backgroundImage: picUrl.isNotEmpty 
                        ? (picUrl.startsWith('base64:') 
                            ? MemoryImage(base64Decode(picUrl.substring(7)))
                            : NetworkImage(picUrl) as ImageProvider?)
                        : null,
                      child: picUrl.isEmpty
                        ? Text(name[0].toUpperCase(), style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold))
                        : null,
                    ),
                    title: Text(username.isNotEmpty ? '@$username' : name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: role == 'V.I.P Üye' ? const Icon(Icons.stars, color: Colors.amber, size: 20) : 
                             role == 'Acil Durum Lideri' ? const Icon(Icons.verified, color: Colors.blueAccent, size: 20) : null,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: userIds[idx])));
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
