import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final email = 'sercanoral65@gmail.com';
  final snap = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
  
  if (snap.docs.isNotEmpty) {
    await FirebaseFirestore.instance.collection('users').doc(snap.docs.first.id).update({
      'is_admin': true,
      'role': 'Üst Yönetici',
    });
    print('✅ $email YÖNETİCİ OLARAK ATANDI.');
  } else {
    print('❌ KULLANICI BULUNAMADI: $email');
  }
}
