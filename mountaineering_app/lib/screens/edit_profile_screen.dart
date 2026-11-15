import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../storage_helper.dart';
import '../database_helper.dart';
import '../utils/app_state.dart';
import 'blocked_users_screen.dart';
import 'login_screen.dart';
import 'premium_screen.dart';
import '../services/premium_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/ad_service.dart';
import '../services/tactical_styles.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kBackground = TacticalStyles.kSurface;
  static const Color kCardBg = TacticalStyles.kSurfaceLow;
  static const Color kGreen = TacticalStyles.kTertiary;
  
  bool _isLoading = true;
  String _userId = '';

  String get _langStr => AppState.localeNotifier.value.languageCode == 'tr' ? AppState.tr('TÜRKÇE') : AppState.tr('ENGLISH');


  // User fields
  String _userName = '';
  String _usernameField = '';
  String _bio = '';
  bool _emailVisible = false;
  bool _isPremium = false;
  bool _ghostMode = false;
  String _affiliationName = '';
  String _affiliationType = 'Bireysel';

  String _kanGrubu = '';
  String _tibbiInfo = '';
  String _acilKisi = '';
  String _acilTel = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userId = user.uid.substring(0, 8).toUpperCase();
        
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            _userName = data['name'] ?? '';
            _usernameField = data['username'] ?? '';
            _bio = data['bio'] ?? '';
            _emailVisible = data['email_visible'] ?? false;
            _isPremium = data['is_premium'] ?? false;
            _ghostMode = data['ghost_mode'] ?? false;
            _affiliationName = data['affiliationName'] ?? '';
            _affiliationType = data['affiliationType'] ?? 'Bireysel';
        }

        final email = await StorageHelper.getUserEmail();
        final dbUser = await DatabaseHelper.instance.kullaniciBul(email ?? '');
        if (dbUser != null) {
           _kanGrubu = dbUser['kan_grubu'] ?? '';
           _tibbiInfo = dbUser['tibbi_bilgi'] ?? '';
           _acilKisi = dbUser['acil_kisi'] ?? '';
           _acilTel = dbUser['acil_tel'] ?? '';
        }

      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return (count / 1000).toStringAsFixed(1) + 'K';
    }
    return count.toString();
  }


  Future<void> _showEditProfileDialog() async {
    final nameCtrl = TextEditingController(text: _userName);
    final usernameCtrl = TextEditingController(text: _usernameField);
    final bioCtrl = TextEditingController(text: _bio);
    bool tempEmailVisible = _emailVisible;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: TacticalStyles.kOutlineVariant, width: 1)),
          title: Row(
            children: [
              const Icon(Icons.edit, color: kOrange, size: 20),
              const SizedBox(width: 8),
              Text('PROFİLİ DÜZENLE', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kOrange, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.red.withOpacity(0.2),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(errorMessage!, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.red, fontSize: 12))),
                      ],
                    ),
                  ),
                ],
                _buildDialogInput(nameCtrl, 'Ad Soyad', Icons.person_outline),
                const SizedBox(height: 12),
                _buildDialogInput(usernameCtrl, 'Kullanıcı Adı (@)', Icons.alternate_email),
                const SizedBox(height: 12),
                _buildDialogInput(bioCtrl, 'Hakkında (Bio)', Icons.info_outline, maxLines: 3),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: TacticalStyles.kSurfaceLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TacticalStyles.kOutlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.white38, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('E-posta Görülebilirliği', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('Diğerleri e-postanızı görebilir', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: tempEmailVisible,
                        activeColor: kOrange,
                        onChanged: (v) => setDialogState(() => tempEmailVisible = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İPTAL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                String newName = nameCtrl.text.trim();
                String newBio = bioCtrl.text.trim();
                String newUsername = usernameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
                if (newUsername.startsWith('@')) newUsername = newUsername.substring(1);

                if (newUsername.length < 3) {
                  setDialogState(() => errorMessage = 'Kullanıcı adı en az 3 karakter olmalı!');
                  return;
                }

                if (newUsername != _usernameField) {
                  final check = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: newUsername).get();
                  if (check.docs.isNotEmpty) {
                    setDialogState(() => errorMessage = 'Bu kullanıcı adı alınmış!');
                    return;
                  }
                }
                
                setDialogState(() => errorMessage = null);

                await StorageHelper.saveUserName(newName.isEmpty ? 'Kullanıcı' : newName);

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'name': newName,
                      'bio': newBio,
                      'username': newUsername,
                      'email_visible': tempEmailVisible,
                    }, SetOptions(merge: true));
                  } catch (_) {}
                }

                setState(() {
                  _userName = newName;
                  _bio = newBio;
                  _usernameField = newUsername;
                  _emailVisible = tempEmailVisible;
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('KAYDET', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white24, size: 18),
        filled: true,
        fillColor: TacticalStyles.kSurfaceLowest,
        border: const OutlineInputBorder(borderSide: BorderSide(color: TacticalStyles.kOutlineVariant)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: TacticalStyles.kOutlineVariant)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
      ),
    );
  }



  void _showPersonalInfoDialog() {
       final kgCtrl = TextEditingController(text: _kanGrubu);
       final tiCtrl = TextEditingController(text: _tibbiInfo);
       final akCtrl = TextEditingController(text: _acilKisi);
       final atCtrl = TextEditingController(text: _acilTel);

       showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(side: const BorderSide(color: kOrange), borderRadius: BorderRadius.zero),
        title: Text('KİŞİSEL BİLGİLER', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kOrange, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               _buildDialogInput(kgCtrl, 'Kan Grubu', Icons.bloodtype),
               const SizedBox(height: 10),
               _buildDialogInput(tiCtrl, 'Tıbbi Bilgi / Alerjiler', Icons.medical_information, maxLines: 2),
               const SizedBox(height: 10),
               _buildDialogInput(akCtrl, 'Acil Durum Kişisi', Icons.person),
               const SizedBox(height: 10),
               _buildDialogInput(atCtrl, 'Acil Durum Numarası', Icons.phone),
            ],
          )
        ),
        actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İPTAL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
              onPressed: () async {
                  await StorageHelper.setBloodType(kgCtrl.text);
                  await StorageHelper.setMedicalInfo(tiCtrl.text);
                  await StorageHelper.setObserverPhone(atCtrl.text);
                  
                  final email = await StorageHelper.getUserEmail();
                  if (email != null) {
                      final usrStr = await DatabaseHelper.instance.kullaniciBul(email);
                      if (usrStr != null) {
                          await DatabaseHelper.instance.kullaniciGuncelle(usrStr['id'], {
                              'kan_grubu': kgCtrl.text,
                              'tibbi_bilgi': tiCtrl.text,
                              'acil_kisi': akCtrl.text,
                              'acil_tel': atCtrl.text
                          });
                      }
                  }
                  
                  setState(() {
                      _kanGrubu = kgCtrl.text;
                      _tibbiInfo = tiCtrl.text;
                      _acilKisi = akCtrl.text;
                      _acilTel = atCtrl.text;
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('KAYDET', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.black, fontWeight: FontWeight.bold)),
            ),
        ],
      )
    );
  }

  void _showAffiliationDialog() {
    String selectedType = _affiliationType;
    final TextEditingController nameCtrl = TextEditingController(text: _affiliationName);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: kCardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: kOrange, width: 1)),
              title: const Text('Kurum / Kuruluş Bilgisi', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Değerli sporcularımız, Dağcılık Kulübüne veya Spor Kulübüne bağlı iseniz Kulüp sekmesinden bağlı olduğunuz kulüp isminizi, Arama Kurtarma Derneğine bağlı iseniz Dernek sekmesinden bağlı olduğunuz Dernek isminizi, Bağlı olduğunuz kurum kuruluş yok ise Bireysel seçerek kaydetmeyi unutmayınız.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: TacticalStyles.kSurfaceLowest, borderRadius: BorderRadius.circular(8), border: Border.all(color: TacticalStyles.kOutlineVariant)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (selectedType.isEmpty || !['Bireysel', 'Spor Kulübü', 'Dernek'].contains(selectedType)) ? 'Bireysel' : selectedType,
                        isExpanded: true,
                        dropdownColor: TacticalStyles.kSurfaceLowest,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: ['Bireysel', 'Spor Kulübü', 'Dernek'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedType = val);
                        },
                      ),
                    ),
                  ),
                  if (selectedType != 'Bireysel') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Kurum / Kulüp Adı',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: TacticalStyles.kOutlineVariant)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İPTAL', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kOrange),
                  onPressed: () async {
                    if (selectedType != 'Bireysel' && nameCtrl.text.trim().isEmpty) return;
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                        'affiliationType': selectedType,
                        'affiliationName': selectedType == 'Bireysel' ? '' : nameCtrl.text.trim(),
                      }, SetOptions(merge: true));
                      
                      setState(() {
                        _affiliationType = selectedType;
                        _affiliationName = selectedType == 'Bireysel' ? '' : nameCtrl.text.trim();
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('KAYDET', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _cikisYap() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: Text('OTURUMU SONLANDIR', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Mevcut oturumu sonlandırmak istediğinize emin misiniz? Ön bellek temizlenecektir.', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İPTAL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('SONLANDIR', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageHelper.clearSession();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _hesabiSil() async {
    final passwordCtrl = TextEditingController();
    bool isDeleting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: Text('HESABI SİL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hesabınız 30 gün içinde tamamen silinecektir. Bu süre zarfında giriş yaparsanız silme işlemi iptal edilir.',
                style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Text('ONAY İÇİN ŞİFRE GİRİN:', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: TacticalStyles.kSurfaceLowest,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: TacticalStyles.kOutlineVariant)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İPTAL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: isDeleting ? null : () async {
                final pass = passwordCtrl.text.trim();
                if (pass.isEmpty) return;

                setDialogState(() => isDeleting = true);
                try {
                  await CloudSyncService.scheduleAccountDeletion(pass);
                  if (ctx.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen(reactivationMessage: 'Hesabınız 30 gün içinde silinmek üzere işaretlendi.')),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  setDialogState(() => isDeleting = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Hata: Şifre yanlış veya bir sorun oluştu.'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: isDeleting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('HESABI SİL', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kOrange, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: TacticalStyles.appBarPill(AppState.tr('PROFİL YÖNETİMİ'), icon: Icons.manage_accounts_outlined),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppState.tr('PROFİL YÖNETİMİ'), style: TacticalStyles.displayHero(color: Colors.white, size: 26)),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: TacticalStyles.recessedDecoration(radius: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white54, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white),
                            decoration: InputDecoration(
                              hintText: AppState.tr('PARAMETRE ARA..'),
                              hintStyle: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white24, fontSize: 13),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 01 / ACCOUNT & PROFILE
                  _buildSectionHeader(AppState.tr('01 / HESAP VE PROFİL'), 'ID: RP-$_userId'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: kCardBg,
                    ),
                    child: Column(
                      children: [
                        _buildMenuTile(Icons.account_circle_outlined, AppState.tr('PROFİLİ DÜZENLE'), _showEditProfileDialog),
                        _buildDivider(),
                        _buildMenuTile(Icons.badge_outlined, AppState.tr('KİŞİSEL BİLGİLER'), _showPersonalInfoDialog),
                        _buildDivider(),
                        _buildMenuTile(Icons.flag_outlined, AppState.tr('KURUM / KURULUŞ BİLGİSİ'), _showAffiliationDialog),
                        _buildDivider(),
                        _buildMenuTile(Icons.block, AppState.tr('ENGELLENEN KULLANICILAR'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()));
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 02 / SYSTEM PARAMETERS
                  _buildSectionHeader(AppState.tr('02 / SİSTEM PARAMETRELERİ'), ''),
                  const SizedBox(height: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: kCardBg,
                    ),
                    child: Column(
                      children: [
                        ValueListenableBuilder(
                          valueListenable: AppState.localeNotifier,
                          builder: (context, _, __) => _buildMenuTileWithTrailing(Icons.language, AppState.tr('DİL SEÇİMİ'), _langStr, () {
                              AppState.toggleLanguage();
                              setState((){});
                          }),
                        ),
                        _buildDivider(),
                        _buildMenuTile(Icons.notifications_none, AppState.tr('SİSTEM BİLDİRİMLERİ'), () async {
                            final status = await Permission.notification.request();
                            if (!context.mounted) return;
                            if (status.isGranted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppState.tr('Bildirim izinleri aktif.')), backgroundColor: kGreen, behavior: SnackBarBehavior.floating));
                            } else if (status.isPermanentlyDenied) {
                                openAppSettings();
                            } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim izinleri reddedildi.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
                            }
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 03 / PREMIUM ÖZELLİKLER
                  _buildSectionHeader(AppState.tr('03 / PREMIUM ÖZELLİKLER'), _isPremium ? AppState.tr('AKTİF') : AppState.tr('PASİF'), statusColor: _isPremium ? Colors.amber : Colors.white38),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: kCardBg,
                      border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildRealSwitchTile(Icons.security, 'Hayalet Modu', 'Radarda ve haritada kendinizi gizleyin', _ghostMode, (v) async {
                          if (!_isPremium) {
                            PremiumService.showPremiumRequired(context, 'Hayalet Modu');
                            return;
                          }
                          setState(() => _ghostMode = v);
                          final u = FirebaseAuth.instance.currentUser;
                          if (u != null) {
                            await FirebaseFirestore.instance.collection('users').doc(u.uid).update({'ghost_mode': v});
                          }
                        }),
                        _buildDivider(),
                        _buildRealStaticTile(Icons.radar, 'Yüksek Çözünürlüklü Radar', 'Storm cells & Çığ yaklaşım uyarıları', onTap: () {
                          if (!_isPremium) PremiumService.showPremiumRequired(context, 'Yüksek Çözünürlüklü Radar');
                        }),
                        _buildDivider(),
                        _buildRealStaticTile(Icons.hdr_auto, 'Night Ops (Kırmızı Mod)', 'Düşük ışıkta gizlilik ve görüş koruması', onTap: () {
                          if (!_isPremium) PremiumService.showPremiumRequired(context, 'Night Ops (Kırmızı Mod)');
                        }),
                        _buildDivider(),
                        _buildRealStaticTile(Icons.menu_book, 'Survival Guide Pro', 'Kritik ilk yardım ve taktiksel rehberler', onTap: () {
                          if (!_isPremium) PremiumService.showPremiumRequired(context, 'Survival Guide Pro');
                        }),
                        _buildDivider(),
                        _buildRealStaticTile(Icons.battery_saver, 'Akıllı Güç Muhafızı', 'Ekstrem batarya optimizasyon yazılımı', onTap: () {
                          if (!_isPremium) PremiumService.showPremiumRequired(context, 'Akıllı Güç Muhafızı');
                        }),
                        _buildDivider(),
                        _buildRealStaticTile(Icons.notifications_active, 'Kritik Ekip Kanalları', 'Ekip öncelikli konum yayınları', onTap: () {
                          if (!_isPremium) PremiumService.showPremiumRequired(context, 'Kritik Ekip Kanalları');
                        }),
                      ],
                    ),
                  ),
                  if (!_isPremium) ...[
                    const SizedBox(height: 12),
                    _buildAdRewardedSection(),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())).then((_) => _loadData());
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kOrange.withOpacity(0.8), kOrange.withOpacity(0.3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: kOrange, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.stars, color: Colors.white, size: 36),
                            const SizedBox(height: 10),
                            Text('ROTA+ PREMIUM', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            const Text('Taktik Radar, Gece Modu ve Profesyonel Hayatta Kalma Rehberi için yükseltin.', 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: Colors.white24)),
                              child: const Text('ŞİMDİ YÜKSELT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                    
                  const SizedBox(height: 40),

                  // TERMINATE SESSION
                  GestureDetector(
                    onTap: _cikisYap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, color: Color(0xFFFFB3B3), size: 24),
                          const SizedBox(height: 12),
                          Text(AppState.tr('O T U R U M U   S O N L A N D I R'), style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: const Color(0xFFFFB3B3), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text(AppState.tr('UYARI: OTURUMU KAPATMAK ÖNBELLEĞİ TEMİZLEYECEKTİR'), style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white38, fontSize: 9, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DELETE ACCOUNT
                  GestureDetector(
                    onTap: _hesabiSil,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: kCardBg.withOpacity(0.6),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 24),
                          const SizedBox(height: 12),
                          Text(AppState.tr('H E S A B I   T A M A M E N   S İ L'), style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),

                  // FOOTER
                  Center(
                    child: Column(
                      children: [
                        Text('ROTA+ OPERATING SYSTEM', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 3)),
                        const SizedBox(height: 8),
                        Text('BUILD VERSION 4.0.21-ALPINE', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white12, fontSize: 10, letterSpacing: 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildAdRewardedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ücretsiz Premium Kazan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Bir reklam izle ve 24 saat boyunca Premium özelliklerin tadını çıkar.', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reklam yükleniyor...')));
              AdService().showRewardedAd(
                onUserEarnedReward: () async {
                  await AdService.addPremiumTime(24);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('🎉 Tebrikler! 24 saatlik Premium üyelik kazandınız!'),
                      backgroundColor: Colors.green,
                    ));
                    _loadData(); // Verileri yenile
                  }
                },
                onAdDismissed: () {},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('İZLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String status, {Color statusColor = Colors.white38}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: kOrange, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        if (status.isNotEmpty)
          Text(status, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: statusColor, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: kOrange, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTileWithTrailing(IconData icon, String title, String trailingText, VoidCallback onTap, {Color trailingColor = Colors.white54}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: kOrange, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            Text(trailingText, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: trailingColor, fontSize: 11, letterSpacing: 1)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Colors.white10);
  }

  Widget _buildRealSwitchTile(IconData icon, String title, String subtitle, bool val, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: val,
            activeColor: Colors.amber,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildRealStaticTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.check_circle_outline, color: Colors.amber, size: 18),
          ],
        ),
      ),
    );
  }
}
