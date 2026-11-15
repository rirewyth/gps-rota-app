import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tactical_styles.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kBackground = TacticalStyles.kSurface;
  static const Color kCardBg = TacticalStyles.kSurfaceLow;
  static const Color kGreen = TacticalStyles.kTertiary;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _unblockUser(String blockedUserId) async {
    if (_currentUser == null) return;

    try {
      // 1. Remove from Firestore
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update({
        'blocked_users': FieldValue.arrayRemove([blockedUserId])
      });

      // 2. Remove from local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final blockedUsers = prefs.getStringList('blocked_users_list') ?? [];
      blockedUsers.remove(blockedUserId);
      await prefs.setStringList('blocked_users_list', blockedUsers);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcının engeli kaldırıldı.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Unblock error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return const Scaffold(body: Center(child: Text('Giriş yapmalısınız.')));

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        centerTitle: true,
        title: TacticalStyles.appBarPill('ENGELLENENLER', icon: Icons.block_rounded, color: TacticalStyles.kError),
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kOrange));
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Colors.white54)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final blockedUsersIds = List<String>.from(data['blocked_users'] ?? []);

          if (blockedUsersIds.isEmpty) {
            return const Center(
              child: Text(
                'Engellediğiniz bir kullanıcı bulunmuyor.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: blockedUsersIds)
                .get(),
            builder: (context, usersSnapshot) {
              if (usersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kOrange));
              }

              if (usersSnapshot.hasError || !usersSnapshot.hasData) {
                return const Center(child: Text('Kullanıcılar yüklenemedi.', style: TextStyle(color: Colors.white54)));
              }

              final blockedUsers = usersSnapshot.data!.docs;

              return ListView.builder(
                itemCount: blockedUsers.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final userDoc = blockedUsers[index];
                  final userData = userDoc.data() as Map<String, dynamic>;
                  final name = userData['full_name'] ?? 'İsimsiz Kullanıcı';
                  final avatarUrl = userData['avatar_url'] ?? '';

                  return Card(
                    color: kCardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: TacticalStyles.kOutlineVariant),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: TacticalStyles.kSurfaceHigh,
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(Icons.person, color: Colors.white54)
                            : null,
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen.withOpacity(0.2),
                          foregroundColor: kGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => _unblockUser(userDoc.id),
                        child: const Text('Engeli Kaldır', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
