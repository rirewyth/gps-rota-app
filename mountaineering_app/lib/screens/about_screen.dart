import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'legal_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  static const Color kOrange = Color(0xFFFF6B00);
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kCardBg = Color(0xFF141414);

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'appacildurum@gmail.com',
      query: 'subject=Rota+ Destek Talebi',
    );
    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kOrange, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Hakkında', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          // Logo & Name
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kOrange.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(color: kOrange.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                    ],
                  ),
                  child: ClipOval(child: Image.asset('assets/icon/tactical_logo.png', fit: BoxFit.cover)),
                ),
                const SizedBox(height: 20),
                Text('ROTA+', style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
                Text('Acil Durum & SOS Rehberi', style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 50),
          
          // Info List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData 
                        ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}' 
                        : 'Yükleniyor...';
                    return _buildInfoTile('Versiyon', version, showArrow: false);
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                _buildInfoTile('Kullanım Koşulları', '', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.terms)));
                }),
                const Divider(color: Colors.white12, height: 1),
                _buildInfoTile('Gizlilik Politikası', '', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.privacy)));
                }),
                const Divider(color: Colors.white12, height: 1),
                _buildInfoTile('Bize Ulaşın', '', onTap: _launchEmail),
                const Divider(color: Colors.white12, height: 1),
              ],
            ),
          ),
          
          const Spacer(),
          // Footer
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Text('© 2026 Rota+. Tüm hakları saklıdır.', style: GoogleFonts.shareTechMono(color: Colors.white12, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String trailing, {VoidCallback? onTap, bool showArrow = true}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing.isNotEmpty)
            Text(trailing, style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 13)),
          if (showArrow)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ),
        ],
      ),
    );
  }
}
