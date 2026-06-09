import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ad_service.dart';

class CreatePostSheet extends StatefulWidget {
  final Map<String, dynamic>? routeData;
  const CreatePostSheet({Key? key, this.routeData}) : super(key: key);

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kCardBg = Color(0xFF141414);
  static const Color kBackground = Color(0xFF0A0A0A);

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _postDescController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<bool> _createPost() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen önce giriş yapın!')));
      return false;
    }

    final desc = _postDescController.text.trim();
    if (desc.isEmpty && _selectedImage == null && widget.routeData == null) {
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
        if (widget.routeData != null) 'routeData': widget.routeData,
        if (widget.routeData != null) 'postType': 'route',
      };

      await FirebaseFirestore.instance.collection('posts').add(postData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gönderi paylaşıldı! ✓'), backgroundColor: Colors.green),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  Text('Yeni Gönderi', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
              GestureDetector(
                onTap: _pickImage,
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
                                onTap: () => setState(() => _selectedImage = null),
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isUploading ? null : _createPost,
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
  }
}
