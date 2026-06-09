import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';

const Color kOrangeU = Color(0xFFFF6B00);
const Color kBgU = Color(0xFF0A0A0A);
const Color kCardU = Color(0xFF141414);

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String? _teamId;
  bool _loading = true;

  // Global Arama State'leri
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  bool _searchLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTeamId();
  }

  Future<void> _loadTeamId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final tId = doc.data()?['team_id'];
      setState(() {
        _teamId = (tId != null && tId.toString().isNotEmpty) ? tId.toString() : null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length > 1) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _searchLoading = true;
      _isSearching = true;
    });

    try {
      final q = query.toLowerCase().replaceAll('@', '');
      // Firestore prefix matching: search >= q and search < q + 'z'
      final results = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: q)
          .where('username', isLessThanOrEqualTo: q + '\uf8ff')
          .limit(20)
          .get();

      setState(() {
        _searchResults = results.docs;
        _searchLoading = false;
      });
    } catch (_) {
      setState(() => _searchLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildRoleBadge(String role) {
    IconData icon;
    Color color;
    switch (role) {
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
        color = Colors.green;
        break;
      default:
        icon = Icons.fiber_new;
        color = Colors.white38;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(role, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNoTeamMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kOrangeU.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: kOrangeU.withOpacity(0.3)),
              ),
              child: const Icon(Icons.group_off, color: kOrangeU, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Ekip Listesi',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ekip listesini görmek için önce bir ekibe katılmanız gerekiyor.\n\n'
              'Ekip sekmesinden mevcut bir ekibe katılın veya yeni bir ekip kurun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kOrangeU,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.group_add, color: Colors.black),
              label: const Text('Ekip Sekmesine Git', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgU,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KULLANICI ARA & EKİP', style: GoogleFonts.outfit(color: kOrangeU, fontWeight: FontWeight.bold, fontSize: 18)),
            if (_teamId != null)
              Text(
                'Kod: $_teamId',
                style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Kullanıcı adı ara (örn: @bora)...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: kOrangeU, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: kCardU,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kOrangeU, width: 1),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kOrangeU))
          : _isSearching
              ? _buildSearchResults()
              : _teamId == null
                  ? _buildNoTeamMessage()
                  : _buildTeamMembers(),
    );
  }

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator(color: kOrangeU));
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text('Kullanıcı bulunamadı', style: GoogleFonts.outfit(color: Colors.white38)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, index) => _buildUserTile(_searchResults[index]),
    );
  }

  Widget _buildTeamMembers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('teams')
          .doc(_teamId)
          .collection('members')
          .snapshots(),
      builder: (context, memberSnap) {
        if (!memberSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kOrangeU));
        }

        final memberDocs = memberSnap.data!.docs;
        if (memberDocs.isEmpty) {
          return const Center(
            child: Text('Ekibinizde henüz başka üye yok.\nDavet kodunu paylaşın!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          );
        }

        final memberUids = memberDocs.map((d) => d.id).toList();

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            memberUids.map((uid) => FirebaseFirestore.instance.collection('users').doc(uid).get()),
          ),
          builder: (context, usersSnap) {
            if (!usersSnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: kOrangeU));
            }

            final userDocs = usersSnap.data!.where((d) => d.exists).toList();

            return ListView.builder(
              itemCount: userDocs.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (ctx, index) => _buildUserTile(userDocs[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile(DocumentSnapshot uDoc) {
    final uid = uDoc.id;
    final user = uDoc.data() as Map<String, dynamic>;
    final String name = user['name'] ?? 'Bilinmeyen';
    final String username = user['username'] ?? '';
    final String role = user['role'] ?? 'Yeni Üye';
    final String picUrl = user['profile_pic_url'] ?? '';
    final bool isBanned = user['is_banned'] ?? false;
    final bool isAdmin = user['email'] == 'sercanoral65@gmail.com';

    ImageProvider? avatarImage;
    if (picUrl.startsWith('base64:')) {
      try {
        avatarImage = MemoryImage(base64Decode(picUrl.substring(7)));
      } catch (_) {}
    } else if (picUrl.isNotEmpty) {
      avatarImage = NetworkImage(picUrl);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCardU,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAdmin ? const Color(0xFFFFD700).withOpacity(0.4) : Colors.white12,
        ),
        boxShadow: isAdmin ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.15), blurRadius: 8)] : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ProfileScreen(targetUserId: uid),
          ));
        },
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: kOrangeU.withOpacity(0.15),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: kOrangeU, fontWeight: FontWeight.bold, fontSize: 18),
                    )
                  : null,
            ),
            if (isAdmin)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                  child: const Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                ),
              ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAdmin)
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF6B00), Color(0xFFFFD700)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              )
            else
              Text(name,
                  style: TextStyle(
                      color: isBanned ? Colors.redAccent.withOpacity(0.6) : Colors.white,
                      fontWeight: FontWeight.bold)),
            if (username.isNotEmpty)
              Text('@$username', style: GoogleFonts.shareTechMono(color: kOrangeU, fontSize: 11)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _buildRoleBadge(role),
              if (isBanned) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('BANLANDI',
                      style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      ),
    );
  }
}
