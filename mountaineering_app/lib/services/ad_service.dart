import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'premium_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  // Real Ad Unit IDs
  static const String _rewardedAdUnitIdAndroid = 'ca-app-pub-3676572486266282/9344128856';
  static const String _rewardedAdUnitIdIos = 'ca-app-pub-3676572486266282/9076936867'; 

  // Native Ad ID (Real)
  static const String _nativeAdUnitIdAndroid = 'ca-app-pub-3676572486266282/6396840817';
  static const String _nativeAdUnitIdIos = 'ca-app-pub-3676572486266282/6396840817';

  // Banner Ad IDs
  static const String _bannerAdUnitIdAndroid = 'ca-app-pub-3676572486266282/1657210527';
  static const String _bannerAdUnitIdIos = 'ca-app-pub-3676572486266282/3496738903';

  String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/5224354917' 
        : 'ca-app-pub-3940256099942544/1712485313';
    }
    if (Platform.isAndroid) return _rewardedAdUnitIdAndroid;
    if (Platform.isIOS) return _rewardedAdUnitIdIos;
    return '';
  }

  String get nativeAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid 
        ? 'ca-app-pub-3940256099942544/2247696110' 
        : 'ca-app-pub-3940256099942544/3986624511';
    }
    if (Platform.isAndroid) return _nativeAdUnitIdAndroid;
    if (Platform.isIOS) return _nativeAdUnitIdIos;
    return '';
  }

  String get bannerAdUnitId {
    if (Platform.isAndroid) return _bannerAdUnitIdAndroid;
    if (Platform.isIOS) return _bannerAdUnitIdIos;
    return '';
  }

  Future<void> init() async {
    await MobileAds.instance.initialize();
    loadRewardedAd(); // Ön yükleme yap
  }

  // --- Banner Ad ---
  BannerAd getBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner Ad Failed: $error');
        },
      ),
    )..load();
  }

  // --- Native Ad ---
  Widget buildNativeAd({
    required Function() onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return AdWidget(
      ad: NativeAd(
        adUnitId: nativeAdUnitId,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: Colors.black,
          cornerRadius: 12,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: const Color(0xFFFF6B00), // kOrange
            style: NativeTemplateFontStyle.bold,
            size: 14.0,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white,
            backgroundColor: Colors.transparent,
            style: NativeTemplateFontStyle.bold,
            size: 16.0,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white70,
            backgroundColor: Colors.transparent,
            style: NativeTemplateFontStyle.normal,
            size: 14.0,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: Colors.white54,
            backgroundColor: Colors.transparent,
            style: NativeTemplateFontStyle.normal,
            size: 12.0,
          ),
        ),
        listener: NativeAdListener(
          onAdLoaded: (ad) => onAdLoaded(),
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            onAdFailedToLoad(ad, error);
          },
        ),
      )..load(),
    );
  }

  void loadRewardedAd({Function? onLoaded}) {
    if (_isAdLoading) return;
    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          onLoaded?.call();
          debugPrint('Rewarded Ad Loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isAdLoading = false;
          debugPrint('Rewarded Ad Failed to Load: $error');
        },
      ),
    );
  }

  Future<void> showRewardedAd({
    required Function onUserEarnedReward,
    required Function onAdDismissed,
  }) async {
    if (_rewardedAd == null) {
      loadRewardedAd();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed();
      },
    );

    await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onUserEarnedReward();
    });
  }

  // --- Premium Logic ---
  
  static Future<void> addPremiumTime(int hours) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    
    DateTime now = DateTime.now();
    DateTime currentExpiry = now;
    
    // Support both field names for compatibility
    if (userDoc.exists) {
      final data = userDoc.data()!;
      final expiryTimestamp = data['premium_until'] ?? data['premium_expiry'];
      if (expiryTimestamp is Timestamp) {
        currentExpiry = expiryTimestamp.toDate();
        if (currentExpiry.isBefore(now)) {
          currentExpiry = now;
        }
      }
    }
    
    final newExpiry = currentExpiry.add(Duration(hours: hours));
    
    await userRef.update({
      'is_premium': true,
      'premium_until': Timestamp.fromDate(newExpiry),
      'premium_expiry': Timestamp.fromDate(newExpiry), // Update both for consistency
    });
  }

  static Future<bool> checkPremiumStatus() async {
    return await PremiumService.isPremium();
  }
}
