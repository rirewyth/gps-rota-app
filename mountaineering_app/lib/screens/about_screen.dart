import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'legal_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/tactical_styles.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  static const Color kOrange = TacticalStyles.kPrimaryContainer;
  static const Color kBackground = TacticalStyles.kSurface;
  static const Color kCardBg = TacticalStyles.kSurfaceLow;

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
        backgroundColor: TacticalStyles.kSurfaceLowest,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kOrange, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: TacticalStyles.appBarPill('HAKKINDA', icon: Icons.info_outline_rounded),
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
                Text('ROTA+', style: TacticalStyles.displayHero(color: TacticalStyles.kOnSurface, size: 32).copyWith(letterSpacing: 4)),
                Text('Acil Durum & SOS Rehberi', style: TacticalStyles.body(color: TacticalStyles.kOnSurfaceVariant, size: 12)),
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
                const Divider(color: TacticalStyles.kOutlineVariant, height: 1),
                _buildInfoTile('Kullanım Koşulları', '', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.terms)));
                }),
                const Divider(color: TacticalStyles.kOutlineVariant, height: 1),
                _buildInfoTile('Gizlilik Politikası', '', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.privacy)));
                }),
                const Divider(color: TacticalStyles.kOutlineVariant, height: 1),
                _buildInfoTile('Bize Ulaşın', '', onTap: _launchEmail),
                const Divider(color: TacticalStyles.kOutlineVariant, height: 1),
              ],
            ),
          ),
          
          const Spacer(),
          // Footer
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Text('© 2026 Rota+. Tüm hakları saklıdır.', style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant.withOpacity(0.6), fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String trailing, {VoidCallback? onTap, bool showArrow = true}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      title: Text(title, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurface, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing.isNotEmpty)
            Text(trailing, style: TextStyle(fontFamily: 'Helvetica', fontFamilyFallback: ['Helvetica Neue', 'Arial', 'sans-serif'], fontFeatures: [FontFeature.tabularFigures()], color: TacticalStyles.kOnSurfaceVariant, fontSize: 13)),
          if (showArrow)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right, color: TacticalStyles.kOnSurfaceVariant, size: 20),
            ),
        ],
      ),
    );
  }
}
