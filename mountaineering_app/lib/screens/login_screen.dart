import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage_helper.dart';
import '../database_helper.dart';
import 'package:animate_do/animate_do.dart';
import 'register_screen.dart';
import '../services/cloud_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_screen.dart';

const Color kOrange = Color(0xFFFF6B00);
const Color kBackground = Color(0xFF0A0A0A);
const Color kCardBg = Color(0xFF141414);
const Color kGreen = Color(0xFF62FF4C);

class LoginScreen extends StatefulWidget {
  final String? reactivationMessage;
  const LoginScreen({Key? key, this.reactivationMessage}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.reactivationMessage != null) {
      _errorMessage = widget.reactivationMessage!;
    }
    _checkReactivation();
  }

  Future<void> _checkReactivation() async {
    final prefs = await SharedPreferences.getInstance();
    final reactivated = prefs.getBool('account_reactivated') ?? false;
    if (reactivated) {
      await prefs.setBool('account_reactivated', false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kCardBg,
            shape: RoundedRectangleBorder(side: const BorderSide(color: kGreen), borderRadius: BorderRadius.zero),
            title: Text('HESAP AKTİF EDİLDİ', style: GoogleFonts.shareTechMono(color: kGreen, fontWeight: FontWeight.bold)),
            content: Text('Tekrar hoş geldiniz! Silme işleminiz iptal edildi ve hesabınız başarıyla aktif edildi.', style: GoogleFonts.shareTechMono(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('TAMAM', style: GoogleFonts.shareTechMono(color: kGreen)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _login() async {
    final email = _emailController.text.trim();
    final sifre = _passwordController.text;

    if (email.isEmpty || sifre.isEmpty) {
      if (mounted) setState(() => _errorMessage = 'KİMLİK VERİLERİ EKSİK');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCred = await CloudSyncService.signIn(email, sifre);
      if (!mounted) return;

      final isLogged = await StorageHelper.isUserLoggedIn();
      if ((userCred != null && userCred.user != null) || isLogged) {
        final kullanici = await DatabaseHelper.instance.kullaniciBul(email);
        if (!mounted) return;

        if (kullanici == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'PROFİL SENKRONİZASYON HATASI';
          });
          return;
        }

        if ((kullanici['is_admin'] as int) == 1) {
          // Admin da ilk girişte onboarding görsün
          final prefs = await SharedPreferences.getInstance();
          final onboardingDone = prefs.getBool('onboarding_complete_v1') ?? false;
          if (!onboardingDone && mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => const OnboardingScreen(nextRoute: '/admin'),
            ));
          } else if (mounted) {
            Navigator.of(context).pushReplacementNamed('/admin');
          }
        } else {
          // İlk giriş kontrolü — onboarding göster
          final prefs = await SharedPreferences.getInstance();
          final onboardingDone = prefs.getBool('onboarding_complete_v1') ?? false;
          if (!onboardingDone && mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
          } else if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      } else {
         setState(() {
           _isLoading = false;
           _errorMessage = 'ERİŞİM REDDEDİLDİ';
         });
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'E-posta veya şifre hatalı.';
      if (e.code == 'invalid-email') msg = 'Geçersiz e-posta adresi.';
      
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

  void _googleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCred = await CloudSyncService.signInWithGoogle();
      if (!mounted) return;

      if (userCred != null && userCred.user != null) {
        // İlk giriş kontrolü — onboarding göster
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone = prefs.getBool('onboarding_complete_v1') ?? false;
        if (!onboardingDone && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        } else if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'GOOGLE GİRİŞ HATASI: $e';
      });
    }
  }

  void _appleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userCred = await CloudSyncService.signInWithApple();
      if (!mounted) return;

      if (userCred != null && userCred.user != null) {
        // İlk giriş kontrolü — onboarding göster
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone = prefs.getBool('onboarding_complete_v1') ?? false;
        if (!onboardingDone && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        } else if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'APPLE GİRİŞ HATASI: $e';
      });
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(side: const BorderSide(color: kOrange), borderRadius: BorderRadius.circular(8)),
        title: Text('ŞİFRE SIFIRLAMA', style: GoogleFonts.shareTechMono(color: kOrange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hesabınıza bağlı e-posta adresini girin. Size bir sıfırlama bağlantısı göndereceğiz.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.black,
                hintText: 'ornek@rota.plus',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kOrange)),
              ),
            ),
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
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              
              Navigator.pop(ctx);
              
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Sıfırlama bağlantısı gönderildi! Lütfen e-postanızı (Spam dahil) kontrol edin.'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Bir hata oluştu veya bu e-posta kayıtlı değil.'),
                    backgroundColor: Colors.redAccent,
                  ));
                }
              }
            },
            child: const Text('GÖNDER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kOrange.withOpacity(0.05),
              ),
            ),
          ),
          
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  
                  // Tactical Logo & Title
                  Center(
                    child: Column(
                      children: [
                        FadeIn(
                          duration: const Duration(milliseconds: 1000),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kOrange.withOpacity(0.5), width: 3),
                              boxShadow: [
                                BoxShadow(color: kOrange.withOpacity(0.3), blurRadius: 25, spreadRadius: 5)
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset('assets/icon/tactical_logo.jpg', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('ROTA+', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 36, letterSpacing: 2)),
                        Text('ACİL DURUM APP', style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 16, letterSpacing: 3, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 50),
                  
                  Text('OPERASYONEL GİRİŞ', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                  const SizedBox(height: 8),
                  Text('Güvenli ağ erişimi için kimlik bilgilerinizi doğrulayın.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  
                  const SizedBox(height: 40),
                  
                  // Hata Mesajı
                  if (_errorMessage.isNotEmpty)
                    FadeInDown(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gpp_bad, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    ),
                  
                  // Form Fields
                  FadeInLeft(
                    delay: const Duration(milliseconds: 200),
                    child: _buildTacticalField('KULLANICI E-POSTA', _emailController, Icons.email_outlined, false),
                  ),
                  const SizedBox(height: 20),
                  FadeInLeft(
                    delay: const Duration(milliseconds: 400),
                    child: _buildTacticalField('GÜVENLİK ANAHTARI', _passwordController, Icons.lock_outline, true),
                  ),
                  
                  // Forgot Password
                  FadeInLeft(
                    delay: const Duration(milliseconds: 500),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: Text('Şifremi Unuttum', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Login Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: GestureDetector(
                      onTap: _isLoading ? null : _login,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isLoading ? [Colors.grey.shade900, Colors.grey.shade800] : [const Color(0xFFFF9D42), kOrange],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isLoading ? [] : [
                            BoxShadow(color: kOrange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: _isLoading
                          ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('SİSTEME ERİŞ', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
                                const SizedBox(width: 12),
                                const Icon(Icons.security, color: Colors.black, size: 20),
                              ],
                            ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Google Login Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: GestureDetector(
                      onTap: _isLoading ? null : _googleLogin,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_\"G\"_logo.svg', width: 24, height: 24, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, color: Colors.black)),
                            const SizedBox(width: 12),
                            Text('GOOGLE İLE DEVAM ET', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apple Login Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 800),
                    child: GestureDetector(
                      onTap: _isLoading ? null : _appleLogin,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, color: Colors.black, size: 28),
                            const SizedBox(width: 8),
                            Text('APPLE İLE DEVAM ET', style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Footer Links
                  Center(
                    child: Column(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: RichText(
                            text: TextSpan(
                              text: 'Henüz kaydınız yok mu? ',
                              style: const TextStyle(color: Colors.white38, fontSize: 13),
                              children: [
                                TextSpan(text: 'YENİ HESAP AÇ', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Text('SİSTEM DURUMU: OPTİMAL', style: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 11, letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalField(String label, TextEditingController controller, IconData icon, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: kOrange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? _obscure : false,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white38, size: 20),
              suffixIcon: isPassword ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              hintText: isPassword ? '••••••••' : 'ornek@rota.plus',
              hintStyle: const TextStyle(color: Colors.white12),
            ),
          ),
        ),
      ],
    );
  }
}

