import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const ChatScreen({Key? key, required this.targetUserId, required this.targetUserName}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _chatId;
  String _myUserName = 'Ben';
  String _myUserPic = '';
  bool _chatIdReady = false;
  bool _iBlockedThem = false;
  bool _theyBlockedMe = false;
  bool get _isBlocked => _iBlockedThem || _theyBlockedMe;

  StreamSubscription? _myDocSub;
  StreamSubscription? _theirDocSub;

  static const Color kOrange = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setChatId();
    _listenToBlockStatus();
  }

  void _listenToBlockStatus() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    _myDocSub = FirebaseFirestore.instance.collection('users').doc(myUid).snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final myBlocked = List<String>.from(data['blocked_users'] ?? []);
        if (mounted) setState(() => _iBlockedThem = myBlocked.contains(widget.targetUserId));
      }
    });

    _theirDocSub = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final theirBlocked = List<String>.from(data['blocked_users'] ?? []);
        if (mounted) setState(() => _theyBlockedMe = theirBlocked.contains(myUid));
      }
    });
  }

  @override
  void dispose() {
    _myDocSub?.cancel();
    _theirDocSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _setOnlineStatus(false);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    }
  }

  void _setOnlineStatus(bool online) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'is_online': online,
      'last_seen': FieldValue.serverTimestamp(),
    });
  }

  void _setChatId() async {
    final myUid = _auth.currentUser!.uid;
    final otherUid = widget.targetUserId;
    final List<String> ids = [myUid, otherUid];
    ids.sort();
    _chatId = ids.join('_');

    final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    if (myDoc.exists && mounted) {
      setState(() {
        _myUserName = myDoc.data()?['name'] ?? 'Ben';
        _myUserPic = myDoc.data()?['profile_pic_url'] ?? '';
        _chatIdReady = true;
      });
    } else if (mounted) {
      setState(() => _chatIdReady = true);
    }

    // Set online when opening chat
    _setOnlineStatus(true);
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _auth.currentUser == null) return;
    _msgController.clear();

    final myUid = _auth.currentUser!.uid;
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'participants': [myUid, widget.targetUserId],
      'last_message': text,
      'last_timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('chats').doc(_chatId)
        .collection('messages').add({
      'sender_id': myUid,
      'sender_name': _myUserName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'deleted': false,
    });

    await NotificationService.sendMessageNotification(
      toUserId: widget.targetUserId,
      fromUserId: myUid,
      fromUserName: _myUserName,
      messageText: text,
      fromUserPic: _myUserPic,
    );
  }

  void _showMessageOptions(BuildContext context, String msgId, String msgText, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Düzenle', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); _editMessage(msgId, msgText); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                title: const Text('Herkesten Sil', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc(msgId).update({'deleted': true, 'text': 'Bu mesaj silindi.'});
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orangeAccent),
              title: const Text('Benim için sil', style: TextStyle(color: Colors.orangeAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc(msgId).update({
                  'deleted_for': FieldValue.arrayUnion([_auth.currentUser!.uid]),
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editMessage(String msgId, String currentText) {
    final ctrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Mesajı Düzenle', style: TextStyle(color: kOrange)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            filled: true, fillColor: Colors.black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kOrange)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kOrange),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc(msgId).update({'text': ctrl.text.trim(), 'edited': true});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('GÜNCELLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Build online status indicator based on Firestore
  Widget _buildOnlineStatus(Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();
    final isOnline = data['is_online'] ?? false;
    final Timestamp? lastSeen = data['last_seen'];

    if (isOnline == true) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        const Text('çevrimiçi', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
      ]);
    } else if (lastSeen != null) {
      final diff = DateTime.now().difference(lastSeen.toDate());
      String timeAgo;
      if (diff.inMinutes < 5) timeAgo = 'az önce aktifti';
      else if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}d önce aktifti';
      else if (diff.inHours < 24) timeAgo = '${diff.inHours}s önce aktifti';
      else timeAgo = 'çevrimdışı';
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]);
    }
    return const Text('çevrimdışı', style: TextStyle(color: Colors.white38, fontSize: 11));
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
          builder: (ctx, snap) {
            String pic = '';
            Map<String, dynamic>? data;
            if (snap.hasData && snap.data!.exists) {
              data = snap.data!.data() as Map<String, dynamic>?;
              pic = data?['profile_pic_url'] ?? '';
            }
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: widget.targetUserId)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: kOrange.withOpacity(0.2),
                    backgroundImage: pic.startsWith('base64:')
                        ? MemoryImage(base64Decode(pic.substring(7)))
                        : (pic.isNotEmpty ? NetworkImage(pic) : null) as ImageProvider?,
                    child: pic.isEmpty ? Text(widget.targetUserName[0].toUpperCase(), style: const TextStyle(color: kOrange, fontSize: 14, fontWeight: FontWeight.bold)) : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.targetUserName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      _buildOnlineStatus(data),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: !_chatIdReady
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats').doc(_chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kOrange));
                      final msgs = snapshot.data!.docs;
                      if (msgs.isEmpty) {
                        return Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.waving_hand, size: 48, color: kOrange.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text('İlk mesajı sen gönder! 👋', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 15)),
                          ]),
                        );
                      }
                      return ListView.builder(
                        reverse: false,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: msgs.length,
                        itemBuilder: (context, index) {
                          final msg = msgs[index];
                          final msgData = msg.data() as Map<String, dynamic>;
                          final isMe = msgData['sender_id'] == myUid;
                          final isDeleted = msgData['deleted'] ?? false;
                          final deletedFor = msgData['deleted_for'] ?? [];
                          final isEdited = msgData['edited'] ?? false;
                          final text = msgData['text'] ?? '';
                          final Timestamp? ts = msgData['timestamp'];

                          if (deletedFor is List && deletedFor.contains(myUid)) return const SizedBox.shrink();

                          final timeStr = ts != null
                              ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                              : '';

                          return GestureDetector(
                            onLongPress: () => _showMessageOptions(context, msg.id, text, isMe),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('users').doc(msgData['sender_id']).get(),
                                      builder: (ctx, snap) {
                                        String pic = '';
                                        if (snap.hasData && snap.data!.exists) {
                                          pic = (snap.data!.data() as Map<String, dynamic>)['profile_pic_url'] ?? '';
                                        }
                                        return CircleAvatar(
                                          radius: 14,
                                          backgroundColor: kOrange.withOpacity(0.2),
                                          backgroundImage: pic.startsWith('base64:')
                                              ? MemoryImage(base64Decode(pic.substring(7)))
                                              : (pic.isNotEmpty ? NetworkImage(pic) : null) as ImageProvider?,
                                          child: pic.isEmpty ? const Icon(Icons.person, size: 14, color: kOrange) : null,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            gradient: isMe ? const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                                            color: isMe ? null : const Color(0xFF1E1E1E),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(18),
                                              topRight: const Radius.circular(18),
                                              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                                            ),
                                          ),
                                          child: Text(text, style: TextStyle(color: isDeleted ? Colors.white38 : Colors.white, fontSize: 14, fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal)),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                          if (isEdited) ...[const SizedBox(width: 4), const Text('(düzenlendi)', style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic))],
                                        ]),
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
                  ),
                ),
                _isBlocked
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.white10))),
                        child: Text(
                          _iBlockedThem 
                              ? 'Kullanıcının engellemesini kaldırmadan mesaj gönderemezsiniz.' 
                              : 'Bu kişiyle mesajlaşılamaz.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.white10))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
                                child: TextField(
                                  controller: _msgController,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 4, minLines: 1,
                                  decoration: const InputDecoration(hintText: 'Mesaj yaz...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.black, size: 20)),
                            ),
                          ],
                        ),
                      ),
              ],
            ),
    );
  }
}
