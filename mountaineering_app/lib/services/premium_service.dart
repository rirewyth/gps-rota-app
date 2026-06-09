import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../screens/premium_screen.dart';

class PremiumService {
  static const String _premiumKey = 'is_premium';
  static const String _expiryKey = 'premium_expiry';

  // --- IAP REAL INTEGRATION ---
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static final StreamController<bool> _purchaseStatusController = StreamController<bool>.broadcast();
  static Stream<bool> get purchaseStatusStream => _purchaseStatusController.stream;

  static const String id6Months = 'rota_premium_6m';
  static const String id12Months = 'rota_premium_12m';
  static const Set<String> _productIds = {id6Months, id12Months};

  static void init() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((List<PurchaseDetails> purchases) {
      _handlePurchaseUpdates(purchases);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      // Handle error
    });
  }

  static void dispose() {
    _subscription?.cancel();
  }

  static Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchase.status == PurchaseStatus.error) {
          _purchaseStatusController.add(false);
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          // Deliver product
          bool deliverSuccess = await _deliverPremium(purchase.productID);
          if (deliverSuccess) {
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            _purchaseStatusController.add(true);
          } else {
            _purchaseStatusController.add(false);
          }
        }
      }
    }
  }

  static Future<bool> _deliverPremium(String productId) async {
    int months = (productId == id12Months) ? 12 : 6;
    try {
      await setPremium(true, months: months);
      
      // Update Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final expiry = DateTime.now().add(Duration(days: months * 30));
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'is_premium': true,
          'premium_expiry': Timestamp.fromDate(expiry),
          'last_purchase_id': productId,
        }, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static String lastError = '';

  static Future<List<ProductDetails>> fetchProducts() async {
    lastError = '';
    final bool available = await _iap.isAvailable();
    List<ProductDetails> products = [];

    if (available) {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
      if (response.error != null) {
        lastError = response.error!.message;
      }
      if (response.productDetails.isNotEmpty) {
        products = response.productDetails;
      } else if (response.error == null) {
        lastError = 'Ürün ID leri (rota_premium_6m, rota_premium_12m) Google Play de bulunamadı veya aktif değil.';
      }
    } else {
      lastError = 'Google Play Ödeme sistemi bu cihazda kullanılamıyor (Hesap açık değil veya desteklenmiyor).';
    }

    return products;
  }

  static Future<void> buyProduct(ProductDetails product) async {
    // Buy product logic

    late PurchaseParam purchaseParam;
    if (Platform.isAndroid) {
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
      );
    } else {
      purchaseParam = PurchaseParam(productDetails: product);
    }
    
    // Non-consumable for these types of products usually
    final bool success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!success) {
      throw Exception('Google Play ödeme ekranı açılamadı. Devam eden bir işleminiz veya mevcut aboneliğiniz olabilir.');
    }
  }
  // --- END IAP INTEGRATION ---

  static const List<String> _kAdminEmails = ['sercanoral65@gmail.com', 'admin@rota.plus'];

  static Future<bool> isPremium() async {
    // 1. Admin & Firestore check
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_kAdminEmails.contains(user.email)) return true; // Master Admins

      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Admins always get Premium
          if (data['is_admin'] == true) return true;
          
          // Eğer admin tarafından premium geri alınmışsa (is_premium == false ise),
          // geçmişten kalan premium_expiry değerini yok say ve false dön.
          if (data['is_premium'] == false) {
            await setPremium(false);
            return false;
          }
          
          // Fixed (Permanent) Premium
          if (data['is_premium_fixed'] == true) {
            await setPremium(true);
            return true;
          }
          
          // Timed Premium (Check both field names used in different parts of the app)
          final expiry = data['premium_expiry'] ?? data['premium_until'];
          
          if (expiry is Timestamp) {
            final expiryDate = expiry.toDate();
            if (expiryDate.isAfter(DateTime.now())) {
              await setPremium(true);
              // Cache expiry locally too
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_expiryKey, expiryDate.toIso8601String());
              return true;
            } else {
              // Expired
              await setPremium(false);
              if (data['is_premium'] == true) {
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'is_premium': false,
                });
              }
              return false;
            }
          }
          
          // Legacy/Simple boolean flag
          bool isPrem = data['is_premium'] == true;
          await setPremium(isPrem);
          return isPrem;
        }
      } catch (e) {
        debugPrint('Premium check error: $e');
      }
    }

    // 2. Local fallback check (for offline use)
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_expiryKey);
    if (expiryStr != null) {
      try {
        final expiry = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiry)) {
          await setPremium(false);
          return false;
        } else {
          return prefs.getBool(_premiumKey) ?? false;
        }
      } catch (_) {}
    }
    
    return prefs.getBool(_premiumKey) ?? false;
  }

  static Future<void> setPremium(bool value, {int months = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
    if (value && months > 0) {
      final expiry = DateTime.now().add(Duration(days: months * 30));
      await prefs.setString(_expiryKey, expiry.toIso8601String());
    } else if (!value) {
      await prefs.remove(_expiryKey);
    }
  }

  static Future<String?> getExpiryDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_expiryKey);
  }

  // Ortak Premium Zorunlu Popup/Modal (Taktiksel Tasarım)
  static void showPremiumRequired(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, color: Color(0xFFFF6B00), size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'PRO ERİŞİM GEREKLİ',
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$featureName ve diğer gelişmiş araçlar profesyonel sürümde mevcuttur.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildBenefitItem(Icons.radar, 'Radar Sistemi'),
            _buildBenefitItem(Icons.layers_outlined, 'Topografik Harita'),
            _buildBenefitItem(Icons.wb_cloudy_outlined, 'Gelişmiş Hava Durumu'),
            _buildBenefitItem(Icons.route_outlined, 'Sınırsız Rota Kaydetme'),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('KAPAT', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            child: const Text('PRO\'YA GEÇ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _buildBenefitItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B00), size: 16),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

}
