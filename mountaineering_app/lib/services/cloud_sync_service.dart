import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../storage_helper.dart';
import 'dart:developer';
import '../firebase_options.dart';

class CloudSyncService {
  static bool _isInitialized = false;
  static bool _hasError = false;

  static FirebaseAuth get auth => FirebaseAuth.instance;

  /// Firebase'i baslatir ve hazirlar.
  static Future<void> initCloudServices() async {
    try {
      if (!_isInitialized) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _isInitialized = true;
        _hasError = false;
        log("Firebase Cloud Service: INITIALIZED OKEY");
      }
    } catch (e) {
      log("Firebase Error: Lutfen 'flutterfire configure' komutunu calistirin. Hata: $e");
      _hasError = true;
    }
  }

  // ─── AUTHENTICATION ────────────────────────────────────────────

  static Future<UserCredential?> signUp(String email, String password, String ad) async {
    if (!_isInitialized || _hasError) {
      throw Exception("Bulut servisleri bagli degil.");
    }
    
    UserCredential? cred;
    try {
      // 1. Firebase Auth kayit
      cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      log("FirebaseAuth signUp Error: $e");
      rethrow;
    }

    if (cred != null && cred.user != null) {
      // 3. Yerel SQLite kayit (Yedek/Offline - ASIL GEREKLI ASAMA - Once bunu yapalim ki hata olsa bile kayit edilsin)
      try {
        await DatabaseHelper.instance.kullaniciKaydet(
          ad: ad,
          email: email,
          sifre: password,
        );
      } catch (e) {
        log("SQLite save error during signup: $e");
      }

      // 2. Firestore profil olustur (Kritik olmayan asama)
      try {
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': ad,
          'email': email,
          'role': 'Yeni Üye',
          'kayit_tarihi': FieldValue.serverTimestamp(),
          'is_premium': false,
          'is_admin': false,
          'email_visible': true,
          'kan_grubu': '',
          'tibbi_bilgi': '',
          'acil_kisi': '',
          'acil_tel': '',
        });
      } catch (e) {
        log("Firestore write error during signup: $e");
      }
    }
    
    return cred;
  }

  static Future<UserCredential?> signIn(String email, String password) async {
    if (!_isInitialized || _hasError) {
      throw Exception("Bulut servisleri bagli degil.");
    }
    UserCredential? cred;
    try {
      cred = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (cred != null && cred.user != null) {
        // 1. Silinme durumu kontrolü ve geri alma
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (data['is_pending_deletion'] == true) {
            // Hesabı geri aktif et
            await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).update({
              'is_pending_deletion': false,
              'deletion_date': null,
            });
            // İşlemin başarılı olduğunu işaretlemek için bir flag dönebiliriz 
            // (Burada basitlik adına UserCredential içinde özel bir bilgi taşıyamayız, 
            // ama StorageHelper üzerinden bir flag set edebiliriz)
            await SharedPreferences.getInstance().then((p) => p.setBool('account_reactivated', true));
          }
        }

        // 2. Giris basariliysa buluttaki verileri yerele senkronize et
        await syncUserProfileFromCloud(cred.user!.uid);
      }
    } catch (e) {
      log("SignIn Error: $e");
      // Eger bulut girisi basarisiz olursa, YEREL SQLITE girisini dene!
      final localUser = await DatabaseHelper.instance.kullaniciGirisDogrula(email, password);
      if (localUser != null) {
         log("Firebase failed, but local SQLite auth succeeded! Proceeding offline.");
         await StorageHelper.setUserLoggedIn(true, userName: localUser['ad'], userEmail: email);
         await StorageHelper.setUserId(localUser['id'] as int);
         await StorageHelper.setPremium((localUser['is_premium'] as int) == 1);
         // Return null implies offline sign-in was used.
         return null;
      }
      rethrow;
    }
    return cred;
  }

  /// Buluttaki kullanici profilini yerele cekip gunceller
  static Future<void> syncUserProfileFromCloud(String uid) async {
    // 1. Oncelikle Firebase Auth kullanicisini alalim
    User? cUser = auth.currentUser;
    if (cUser == null) return;

    Map<String, dynamic>? data;
    bool docExists = false;

    // 2. Firestore'dan profili okumayi dene (Permission denied yiyebilir)
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        docExists = true;
        data = doc.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      log("Firestore read failed (Bypassing): \$e");
    }
    
    try {
      // 3. Verileri belirle
      String email = (data?['email'] ?? cUser.email) ?? 'no-email@rota.plus';
      String name = (data?['name'] ?? data?['ad'] ?? cUser.displayName) ?? 'Anonim';
      bool isPremium = data?['is_premium'] == true;
      
      // 4. Yerelde kullaniciyi bul veya olustur (Bu asama hayati onem tasiyor)
      var yerelKullanici = await DatabaseHelper.instance.kullaniciBul(email);
      
      if (yerelKullanici != null) {
        await DatabaseHelper.instance.kullaniciGuncelle(yerelKullanici['id'], {
          'ad': name,
          'kan_grubu': data?['kan_grubu'] ?? '',
          'tibbi_bilgi': data?['tibbi_bilgi'] ?? '',
          'is_premium': isPremium ? 1 : 0,
        });
      } else {
        await DatabaseHelper.instance.kullaniciKaydet(
          ad: name,
          email: email,
          sifre: 'cloud-synced',
        );
      }
      
      // 5. Session verilerini guncelle
      await StorageHelper.setUserLoggedIn(true, userName: name, userEmail: email, userUid: uid);
      await StorageHelper.setPremium(isPremium);
      
      // 6. Eger Firestore belgesi hic okunabildiyse ve yoksa, olusturmayi dene
      if (!docExists) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'name': name,
            'email': email,
            'kayit_tarihi': FieldValue.serverTimestamp(),
            'is_premium': false,
            'is_admin': false,
            'kan_grubu': '',
            'tibbi_bilgi': '',
            'acil_kisi': '',
            'acil_tel': '',
          });
        } catch (e) {
             log("Firestore create failed: \$e");
        }
      }
    } catch (e) {
      log("SyncProfile Critical Error: \$e");
    }
  }

  /// Cikis yapar
  static Future<void> signOut() async {
    await auth.signOut();
    await StorageHelper.clearSession();
  }

  static User? get currentUser => auth.currentUser;

  // ─── DATA SYNC ─────────────────────────────────────────────────

  /// Yeni kaydedilen bir konumu buluta kopyalar
  static Future<void> syncLocation(double lat, double lng, double alt, String timestamp) async {
    if (!_isInitialized || _hasError || currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('location_history').add({
        'enlem': lat,
        'boylam': lng,
        'yukseklik': alt,
        'zaman': timestamp,
        'cihaz_senkronizasyon_saati': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Acil durum (SOS) mesajini buluta gonderir
  static Future<void> syncMessage(String text, String type, bool isSos) async {
    if (!_isInitialized || _hasError || currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('messages').add({
        'metin': text,
        'tip': type,
        'is_sos': isSos,
        'cihaz_senkronizasyon_saati': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Kullanicinin yeni kaydettigi rotayi buluta yedekler
  static Future<void> syncRoute(
    String name,
    List<Map<String, double>> points,
    String startName,
    String endName, {
    double distance = 0,
    int durationSeconds = 0,
    double elevationGain = 0,
    double maxAltitude = 0,
    int steps = 0,
    String source = '',
  }) async {
    if (!_isInitialized || _hasError || currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('routes').add({
        'name': name,
        'coordinates': points,
        'from': startName,
        'to': endName,
        'distance': distance,
        'duration_seconds': durationSeconds,
        'elevation_gain': elevationGain,
        'max_altitude': maxAltitude,
        'steps': steps,
        'source': source.isNotEmpty ? source : 'planned',
        'pointCount': points.length,
        'timestamp': FieldValue.serverTimestamp(),
        // Eski Türkçe anahtarlar (uyumluluk için)
        'isim': name,
        'noktalar': points,
        'baslangic_adi': startName,
        'bitis_adi': endName,
        'olusturma_tarihi': DateTime.now().toIso8601String(),
        'cihaz_senkronizasyon_saati': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
  // ─── ACCOUNT MANAGEMENT ─────────────────────────────────────────

  /// Hesabı 30 gün sonra silinmek üzere işaretler
  static Future<void> scheduleAccountDeletion(String password) async {
    final user = auth.currentUser;
    if (user == null || user.email == null) throw Exception("Kullanıcı bulunamadı.");

    // 1. Şifre doğrulaması için re-authenticate
    AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(credential);

    // 2. Firestore güncelleme
    final deletionDate = DateTime.now().add(const Duration(days: 30));
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'is_pending_deletion': true,
      'deletion_date': Timestamp.fromDate(deletionDate),
    });

    // 3. Çıkış yap
    await signOut();
  }
  
  /// Google ile Giriş yapar
  static Future<UserCredential?> signInWithGoogle() async {
    if (!_isInitialized || _hasError) {
      throw Exception("Bulut servisleri bağlı değil.");
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) return null; // Kullanıcı iptal etti

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCred = await auth.signInWithCredential(credential);
      
      if (userCred.user != null) {
        await syncUserProfileFromCloud(userCred.user!.uid);
      }
      
      return userCred;
    } catch (e) {
      log("Google SignIn Error: $e");
      rethrow;
    }
  }

  /// Hesabı hem Auth hem Firestore'dan anında siler
  static Future<void> deleteAccountImmediately() async {
    final user = auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    
    try {
      // 1. Önce takipçi ve takip edilen listelerindeki sayaçları güncelle (Veri bütünlüğü için)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final followers = data['followers'] as List? ?? [];
        final following = data['following'] as List? ?? [];

        final batch = FirebaseFirestore.instance.batch();

        // Takip ettiğim kişilerin takipçi sayısını düşür ve beni onların takipçi listesinden çıkar
        for (var fUid in following) {
          if (fUid is String && fUid.isNotEmpty) {
            batch.update(FirebaseFirestore.instance.collection('users').doc(fUid), {
              'followers': FieldValue.arrayRemove([uid]),
              'followers_count': FieldValue.increment(-1),
            });
          }
        }

        // Beni takip eden kişilerin takip ettikleri sayısını düşür ve beni onların takip listesinden çıkar
        for (var fUid in followers) {
          if (fUid is String && fUid.isNotEmpty) {
            batch.update(FirebaseFirestore.instance.collection('users').doc(fUid), {
              'following': FieldValue.arrayRemove([uid]),
              'following_count': FieldValue.increment(-1),
            });
          }
        }

        await batch.commit();
      }

      // 2. Firestore verilerini temizle
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      
      // 3. Auth kullanıcısını sil
      await user.delete();
      
      // 4. Yerel oturumu temizle
      await StorageHelper.clearSession();
    } catch (e) {
      log("Delete Account Error: $e");
      rethrow;
    }
  }
}
