import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final email = 'sercanoral65@gmail.com';
  
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    print('✅ ŞİFRE SIFIRLAMA LİNKİ BAŞARIYLA GÖNDERİLDİ: $email');
    print('Lütfen e-postanızı (Gereksiz/Spam kutusu dahil) kontrol edin.');
  } catch (e) {
    print('❌ HATA OLUŞTU: $e');
  }
}
