import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../database_helper.dart';
import '../storage_helper.dart';
import '../services/cloud_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'legal_screen.dart';
import 'onboarding_screen.dart';

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kGreen = Color(0xFF62FF4C);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _agreed = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String _errorMessage = '';
  String _affiliationType = 'Bireysel'; // Bireysel, Spor Kulübü, Dernek
  final TextEditingController _affiliationNameController = TextEditingController();

  void _register() async {
    setState(() => _errorMessage = '');

    if (!_agreed) {
      if (mounted) setState(() => _errorMessage = 'GÜVENLİK FERAGATNAMESİNİ ONAYLAYIN');
      return;
    }

    final ad = _nameController.text.trim();
    String usernameRaw = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final sifre = _passwordController.text;
    final sifreOnay = _confirmController.text;

    if (ad.isEmpty || usernameRaw.isEmpty || email.isEmpty || sifre.isEmpty) {
      if (mounted) setState(() => _errorMessage = 'TÜM ALANLARI DOLDURUNUZ');
      return;
    }

    if (usernameRaw.startsWith('@')) usernameRaw = usernameRaw.substring(1);
    final username = usernameRaw.toLowerCase().replaceAll(' ', '');

    if (username.length < 3) {
      if (mounted) setState(() => _errorMessage = 'KULLANICI ADI ÇOK KISA');
      return;
    }

    if (sifre != sifreOnay) {
      if (mounted) setState(() => _errorMessage = 'ŞİFRELER UYUŞMUYOR');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usernameCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = '@$username KULLANIMDA';
        });
        return;
      }

      final userCred = await CloudSyncService.signUp(email, sifre, ad);

      if (!mounted) return;

      if (userCred?.user != null) {
        await StorageHelper.setUserLoggedIn(true, userName: ad, userEmail: email.toLowerCase());
        final yerelKullanici = await DatabaseHelper.instance.kullaniciBul(email);
        if (yerelKullanici != null) {
          await StorageHelper.setUserId(yerelKullanici['id'] as int);
        }
        await StorageHelper.setPremium(false);

        await FirebaseFirestore.instance.collection('users').doc(userCred!.user!.uid).set({
          'username': username,
          'affiliationType': _affiliationType,
          'affiliationName': _affiliationType == 'Bireysel' ? '' : _affiliationNameController.text.trim(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        // Yeni kullanıcı — her zaman onboarding'e yönlendir
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(nextRoute: '/home'),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Kayıt başarısız.';
      if (e.code == 'email-already-in-use') msg = 'E-posta zaten kullanımda.';
      setState(() {
        _isLoading = false;
        _errorMessage = msg.toUpperCase();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'SİSTEMSEL HATA: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kOrange.withOpacity(0.03)),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 70),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_ios_new, color: Colors.white38, size: 16),
                      const SizedBox(width: 8),
                      Text('GERİ DÖN', style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kOrange.withOpacity(0.3), width: 1.5),
                      ),
                      child: ClipOval(child: Image.asset('assets/icon/tactical_logo.jpg', fit: BoxFit.cover)),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YENİ KAYIT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2)),
                        Text('FIELD OPS ENROLLMENT', style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 11, letterSpacing: 2)),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 35),
                
                if (_errorMessage.isNotEmpty)
                  FadeInDown(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.2))),
                      child: Row(children: [const Icon(Icons.warning_amber, color: Colors.redAccent, size: 18), const SizedBox(width: 10), Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)))]),
                    ),
                  ),

                // Info Box
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Değerli sporcularımız, Dağcılık Kulübüne veya Spor Kulübüne bağlı iseniz Kulüp sekmesinden bağlı olduğunuz kulüp isminizi, Arama Kurtarma Derneğine bağlı iseniz Dernek sekmesinden bağlı olduğunuz Dernek isminizi, Bağlı olduğunuz kurum kuruluş yok ise Bireysel seçerek kayıt olmayı unutmayınız.',
                          style: TextStyle(color: Colors.blueAccent.withOpacity(0.9), fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Değerli kullanıcılarımız rota tasarla kısmında sistemin sizden başlayarak mahsur kalan dağcıya çizdiği rota size minimum km olan ve ideal olan yolu gösteren rotadır. Rotayı doğrulamak için diğer rota yönlendirme servis uygulamalarından doğruluğunu kontrol edebilirsiniz.',
                          style: TextStyle(color: Colors.orangeAccent.withOpacity(0.9), fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildTacticalField('OPERATÖR ADI', _nameController, Icons.person_outline, false),
                const SizedBox(height: 16),
                _buildTacticalField('KOD ADI (USERNAME)', _usernameController, Icons.alternate_email, false),
                const SizedBox(height: 16),
                _buildTacticalField('İLETİŞİM KANALI (EMAIL)', _emailController, Icons.mail_outline, false),
                const SizedBox(height: 16),
                
                // Affiliation Selector
                Text('KURUM / KURULUŞ BAĞLANTISI', style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _affiliationType,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF141414),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white24),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: ['Bireysel', 'Spor Kulübü', 'Dernek'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _affiliationType = newValue;
                            if (newValue == 'Bireysel') {
                              _affiliationNameController.clear();
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (_affiliationType != 'Bireysel') ...[
                  const SizedBox(height: 16),
                  _buildTacticalField('KURUM / KULÜP ADI', _affiliationNameController, Icons.business, false),
                ],
                
                const SizedBox(height: 16),
                _buildTacticalField('ERİŞİM ŞİFRESİ', _passwordController, Icons.lock_outline, true, isPass: true, obscure: _obscurePass, toggle: () => setState(() => _obscurePass = !_obscurePass)),
                const SizedBox(height: 16),
                _buildTacticalField('ŞİFRE DOĞRULAMA', _confirmController, Icons.security, true, isPass: true, obscure: _obscureConfirm, toggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                
                const SizedBox(height: 24),
                
                // Waiver
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _agreed ? kOrange.withOpacity(0.3) : Colors.white10)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                              color: _agreed ? kOrange : Colors.transparent,
                              border: Border.all(color: _agreed ? kOrange : Colors.white24),
                              borderRadius: BorderRadius.circular(4)),
                          child: _agreed ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                                children: [
                                  TextSpan(
                                    text: 'Kullanım Koşulları',
                                    style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                    onEnter: (_) {}, // For mouse hover if needed
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.terms)));
                                      },
                                  ),
                                  const TextSpan(text: ' ve '),
                                  TextSpan(
                                    text: 'Gizlilik Politikası',
                                    style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.privacy)));
                                      },
                                  ),
                                  const TextSpan(text: '’nı okudum, uygunsuz içerik ve tacizkar davranışlara tolerans gösterilmediğini, taktiksel operasyon risklerini kabul ediyorum.'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                FadeInUp(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _register,
                    child: Container(
                      width: double.infinity, height: 56,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: _isLoading ? [Colors.grey.shade900, Colors.grey.shade800] : [const Color(0xFFFF9D42), kOrange]), borderRadius: BorderRadius.circular(8)),
                      child: _isLoading ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))) : Center(child: Text('KAYDI TAMAMLA', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1))),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                Center(child: TextButton(onPressed: () => Navigator.pop(context), child: RichText(text: const TextSpan(text: 'Zaten hesabınız var mı? ', style: TextStyle(color: Colors.white38, fontSize: 13), children: [TextSpan(text: 'GİRİŞ YAP', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold))])))),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalField(String label, TextEditingController controller, IconData icon, bool hasSuffix, {bool isPass = false, bool obscure = false, VoidCallback? toggle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
          child: TextField(
            controller: controller,
            obscureText: isPass ? obscure : false,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white24, size: 18),
              suffixIcon: isPass ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white24, size: 18), onPressed: toggle) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: '...', hintStyle: const TextStyle(color: Colors.white12),
            ),
          ),
        ),
      ],
    );
  }
}
