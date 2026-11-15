import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'storage_helper.dart';
import 'services/cloud_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'utils/app_state.dart';
import 'firebase_options.dart';


import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/social_feed_screen.dart';
import 'screens/live_tracking_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/route_planning_screen.dart';
import 'screens/team_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/splash_screen.dart' as app_splash;
import 'screens/notification_screen.dart';
import 'services/premium_service.dart';
import 'services/night_ops_service.dart';
import 'package:mountaineering_app/services/earthquake_service.dart';
import 'package:geolocator/geolocator.dart';
import 'services/ad_service.dart';
import 'services/background_monitor_service.dart';
import 'services/tactical_styles.dart';
import 'screens/critical_alert_screen.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kOrange = Color(0xFFFF5708);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Data-only mesajlarda da uygulama kapalıyken bildirim düşsün
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString() ?? 'ROTA+ Bildirim';
    final body = message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';
    if (body.isNotEmpty) {
      final plugin = FlutterLocalNotificationsPlugin();
      const initAndroid = AndroidInitializationSettings('ic_notification');
      await plugin.initialize(const InitializationSettings(android: initAndroid));
      await plugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rota_plus_fcm_channel',
            'Rota+ Mesajlar ve Uyarılar',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }
  debugPrint("Handling a background message: ${message.messageId}");
}

void _handleFCMMessage(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];
  if (type == 'follow') {
    final fromUserId = data['fromUserId'];
    if (fromUserId != null) {
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: fromUserId)));
    }
  } else if (type == 'team_message') {
    navigatorKey.currentState?.pushReplacementNamed('/home');
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TeamScreen()));
  } else if (type == 'sos') {
    navigatorKey.currentState?.pushReplacementNamed('/home');
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const LiveTrackingScreen()));
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint("--- ROTA+ APP STARTUP SEQUENCE ---");
    
    // RAM tasarrufu ve kasmayı engellemek için ImageCache limitlerini ayarlıyoruz
    PaintingBinding.instance.imageCache.maximumSize = 150;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024; // 60 MB limit
    
    // Perform initializations in parallel with strict timeouts
    await Future.wait([
      CloudSyncService.initCloudServices().timeout(
        const Duration(seconds: 8), 
        onTimeout: () => debugPrint("TIMEOUT: Cloud Services (Bypassed)"),
      ),
      AppState.init().timeout(
        const Duration(seconds: 4), 
        onTimeout: () => debugPrint("TIMEOUT: App State (Bypassed)"),
      ),
    ]).catchError((e) {
      debugPrint("Startup Error (Non-Fatal): $e");
      return [];
    });
    
    // Setup FCM
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
          const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
            'rota_plus_fcm_channel',
            'Rota+ Mesajlar',
            importance: Importance.max,
            priority: Priority.high,
          );
          const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
          flutterLocalNotificationsPlugin.show(
            message.hashCode,
            message.notification?.title,
            message.notification?.body,
            platformChannelSpecifics,
          );
        }
      });
      // Handle background/terminated clicks
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleFCMMessage(message);
      });

      messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          Future.delayed(const Duration(seconds: 3), () {
            _handleFCMMessage(message);
          });
        }
      });

    } catch (e) {
      debugPrint("FCM Init Error: $e");
    }
    
    // Initialize Google Play Billing
    PremiumService.init();

    // Initialize Background Service (Moved after core init, with separate error handling)
    _startBackgroundServices();
    
    debugPrint("Startup Logic Finished.");
  } catch (e) {
    debugPrint("CRITICAL STARTUP ERROR: $e");
  }
  
  // Global Error Handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Flutter Error Caught: ${details.exception}");
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("Platform Error Caught: $error");
    return true; // prevent crash
  };

  runZonedGuarded(() {
    runApp(const MountaineeringApp());
  }, (error, stackTrace) {
    debugPrint("runZonedGuarded Caught Error: $error");
  });
}

Future<void> _startBackgroundServices() async {
  try {
    // iOS'ta flutter_background_service KULLANILMAZ (SIGSEGV çökme riski).
    // Her iki platformda da kendi Timer tabanlı güvenli servisimiz çalışır.
    await Future.delayed(const Duration(seconds: 3));
    await BackgroundMonitorService.initializeService();
  } catch (e) {
    debugPrint("Background Service Init Error (Bypassed): $e");
  }
}

class MountaineeringApp extends StatelessWidget {
  const MountaineeringApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NightOpsService(),
      builder: (context, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppState.themeNotifier,
          builder: (context, currentThemeMode, child) {
            return ValueListenableBuilder<Locale>(
              valueListenable: AppState.localeNotifier,
              builder: (context, currentLocale, _) {
                return MaterialApp(
                  title: 'Rota+ / Deprem ve Trekking',
                  navigatorKey: navigatorKey,
                  debugShowCheckedModeBanner: false,
                  themeMode: ThemeMode.dark,
                  locale: currentLocale,
                  theme: ThemeData(
                    useMaterial3: true,
                    fontFamily: TacticalStyles.kHelveticaFont,
                    fontFamilyFallback: TacticalStyles.kHelveticaFallback,
                    scaffoldBackgroundColor: TacticalStyles.kSurface,
                    textTheme: ThemeData.dark().textTheme.apply(
                      fontFamily: TacticalStyles.kHelveticaFont,
                      fontFamilyFallback: TacticalStyles.kHelveticaFallback,
                    ),
                    appBarTheme: const AppBarTheme(
                      backgroundColor: TacticalStyles.kSurface,
                      foregroundColor: TacticalStyles.kOnSurface,
                      elevation: 0,
                    ),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: kOrange,
                      brightness: Brightness.dark,
                      primary: TacticalStyles.kPrimary,
                      secondary: TacticalStyles.kSecondaryContainer,
                      tertiary: TacticalStyles.kTertiary,
                      surface: TacticalStyles.kSurfaceContainer,
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    fontFamily: TacticalStyles.kHelveticaFont,
                    fontFamilyFallback: TacticalStyles.kHelveticaFallback,
                    scaffoldBackgroundColor: TacticalStyles.kSurface,
                    textTheme: ThemeData.dark().textTheme.apply(
                      fontFamily: TacticalStyles.kHelveticaFont,
                      fontFamilyFallback: TacticalStyles.kHelveticaFallback,
                    ),
                    appBarTheme: const AppBarTheme(
                      backgroundColor: TacticalStyles.kSurface,
                      foregroundColor: TacticalStyles.kOnSurface,
                      elevation: 0,
                    ),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: kOrange,
                      brightness: Brightness.dark,
                      primary: TacticalStyles.kPrimary,
                      secondary: TacticalStyles.kSecondaryContainer,
                      tertiary: TacticalStyles.kTertiary,
                      surface: TacticalStyles.kSurfaceContainer,
                    ),
                  ),
                  initialRoute: '/',
                  builder: (context, child) {
                    return NightOpsService().applyNightFilter(child!);
                  },
                  routes: {
                    '/': (context) => const app_splash.SplashScreen(),
                    '/login': (context) => const LoginScreen(),
                    '/home': (context) => const MainAppScreen(),
                    '/premium': (context) => const PremiumScreen(),
                    '/admin': (context) => const AdminPanelScreen(),
                    '/critical_alert': (context) {
                      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                      return CriticalAlertScreen(
                        magnitude: args['mag'],
                        secondsLeft: args['seconds'],
                        location: args['location'],
                        lat: args['lat'],
                        lng: args['lng'],
                      );
                    },
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}


class MainAppScreen extends StatefulWidget {
  final int initialIndex;
  final bool autoStartTracking;
  const MainAppScreen({
    Key? key,
    this.initialIndex = 0,
    this.autoStartTracking = false,
  }) : super(key: key);

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  late int _currentIndex;
  late List<Widget> _screens;

  int _unreadNotifCount = 0;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      const HomeDashboard(),
      const SocialFeedScreen(),
      LiveTrackingScreen(autoStart: widget.autoStartTracking),
      const RoutePlanningScreen(),
      const TeamScreen(),
      const ProfileScreen(),
    ];
     const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('ic_notification');
     const InitializationSettings initSettings = InitializationSettings(android: initAndroid);
     _flutterLocalNotificationsPlugin.initialize(
       initSettings,
       onDidReceiveNotificationResponse: (response) {
         final payload = response.payload;
         if (payload != null && payload.startsWith('critical_alert')) {
           final parts = payload.split('|');
           navigatorKey.currentState?.pushNamed('/critical_alert', arguments: {
             'mag': double.parse(parts[1]),
             'seconds': double.parse(parts[2]),
             'location': parts[3],
             'lat': double.parse(parts[4]),
             'lng': double.parse(parts[5]),
           });
         }
       },
     );
     _listenNotifications();
    _checkEarthquakeMonitoring();
  }

  Future<void> _checkEarthquakeMonitoring() async {
    final enabled = await StorageHelper.getEarlyWarningEnabled();
    if (enabled) {
      final pos = await Geolocator.getCurrentPosition();
      EarthquakeService().startMonitoring(
        currentPos: pos,
        onWarning: (mag, seconds, loc, lat, lng) {
          navigatorKey.currentState?.pushNamed('/critical_alert', arguments: {
            'mag': mag,
            'seconds': seconds,
            'location': loc,
            'lat': lat,
            'lng': lng,
          });
        },
      );
    }
  }

  void _listenNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        final count = snap.docs.length;
        if (count > _unreadNotifCount && snap.docs.isNotEmpty) {
          final lastDoc = snap.docs.first.data();
          final type = lastDoc['type'] ?? '';
          final fromUserName = lastDoc['fromUserName'] ?? 'Biri';
          final text = lastDoc['text'] ?? 'Yeni bir bildiriminiz var.';
          
          String title = 'Acil Durum Bildirimi';
          if (type == 'follow') title = 'Yeni Takip';
          else if (type == 'message') title = 'Yeni Mesaj';
          else if (type == 'like') title = 'Yeni Beğeni';
          else if (type == 'team_sos') title = '🚨 EKİP SOS!';

          _showLocalNotification(title, '$fromUserName $text');
        }
        setState(() => _unreadNotifCount = count);
      }
    });
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'acildurum_notifications',
      'Acil Durum Bildirimleri',
      channelDescription: 'Rota Plus Emniyetteyim – SOS ve Ekip Bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: 'ic_notification', // Use tactical monochromatic icon for notifications
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TacticalStyles.kSurface,
      extendBody: false,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final navItems = [
      {'icon': Icons.explore_outlined, 'activeIcon': Icons.explore_rounded, 'label': 'Keşfet', 'dot': false},
      {'icon': Icons.sensors_rounded, 'activeIcon': Icons.sensors_rounded, 'label': 'Akış', 'dot': false},
      {'icon': Icons.location_searching_rounded, 'activeIcon': Icons.my_location_rounded, 'label': 'Takip', 'dot': false},
      {'icon': Icons.alt_route_rounded, 'activeIcon': Icons.alt_route_rounded, 'label': 'Rota', 'dot': false},
      {'icon': Icons.shield_outlined, 'activeIcon': Icons.shield_rounded, 'label': 'Ekip', 'dot': true},
      {'icon': Icons.person_outline_rounded, 'activeIcon': Icons.person_rounded, 'label': 'Profil', 'dot': false},
    ];

    return Container(
      color: TacticalStyles.kSurface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xCC22222A),
                    const Color(0xE60D0D12),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: TacticalStyles.kPrimary.withOpacity(0.08),
                    blurRadius: 18,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.65),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (idx) {
                  final item = navItems[idx];
                  final isSelected = _currentIndex == idx;
                  final showDot = item['dot'] == true;

                  return Expanded(
                    child: TacticalPressable(
                      pressedScale: 0.92,
                      onTap: () => setState(() => _currentIndex = idx),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? TacticalStyles.kPrimaryContainer.withOpacity(0.20)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSelected
                                      ? (item['activeIcon'] as IconData)
                                      : (item['icon'] as IconData),
                                  size: 20,
                                  color: isSelected
                                      ? TacticalStyles.kPrimary
                                      : TacticalStyles.kOnSurfaceVariant,
                                ),
                              ),
                              if (showDot)
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: TacticalStyles.kTertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['label'] as String,
                            style: TacticalStyles.labelMicro(
                              fontSize: 9.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? TacticalStyles.kPrimary
                                  : TacticalStyles.kOnSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: isSelected ? 4 : 0,
                            height: isSelected ? 4 : 0,
                            decoration: const BoxDecoration(
                              color: TacticalStyles.kPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _logout() async {
    await CloudSyncService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}
