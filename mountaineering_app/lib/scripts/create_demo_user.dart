import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final email = 'demo@rotaplus.com';
  final password = 'demo1234';
  
  try {
    print('⏳ Demo kullanıcısı oluşturuluyor...');
    UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
      'name': 'Demo Yetkili',
      'email': email,
      'role': 'Operasyon Şefi',
      'is_admin': true,
      'is_premium': true,
      'kayit_tarihi': FieldValue.serverTimestamp(),
    });
    
    print('✅ BAŞARILI: Demo kullanıcısı oluşturuldu.');
    print('Email: $email');
    print('Şifre: $password');
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      print('ℹ️ BİLGİ: Bu email zaten kullanımda. Giriş yapmayı deneyebilirsiniz.');
    } else {
      print('❌ HATA: ${e.message}');
    }
  } catch (e) {
    print('❌ BEKLENMEDİK HATA: $e');
  }
}
