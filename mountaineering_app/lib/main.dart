import 'dart:io';
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
import 'screens/critical_alert_screen.dart';

const Color kOrange = Color(0xFFFF6B00);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  
  runApp(const MountaineeringApp());
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
                  themeMode: currentThemeMode,
                  locale: currentLocale,
                  theme: ThemeData(
                    useMaterial3: true,
                    scaffoldBackgroundColor: Colors.white,
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: kOrange,
                      brightness: Brightness.light,
                      surface: Colors.grey.shade100,
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: kOrange,
                      brightness: Brightness.dark,
                      surface: const Color(0xFF141414),
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
  const MainAppScreen({Key? key}) : super(key: key);

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeDashboard(),
    SocialFeedScreen(),
    LiveTrackingScreen(),
    RoutePlanningScreen(),
    TeamScreen(),
    ProfileScreen(),
  ];

  int _unreadNotifCount = 0;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const selectedStyle = TextStyle(color: kOrange, fontSize: 9, fontWeight: FontWeight.bold);
    const unselectedStyle = TextStyle(color: Colors.white54, fontSize: 9);
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (idx) => setState(() => _currentIndex = idx),
      backgroundColor: Colors.black,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 9,
      unselectedFontSize: 9,
      selectedItemColor: kOrange,
      unselectedItemColor: Colors.white38,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.explore_outlined, size: 22),
          activeIcon: Icon(Icons.explore, size: 22, color: kOrange),
          label: 'Keşfet',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined, size: 22),
          activeIcon: Icon(Icons.home_filled, size: 22, color: kOrange),
          label: 'Akış',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined, size: 22),
          activeIcon: Icon(Icons.map, size: 22, color: kOrange),
          label: 'Takip',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.navigation_outlined, size: 22),
          activeIcon: Icon(Icons.navigation, size: 22, color: kOrange),
          label: 'Rota',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.groups_outlined, size: 22),
          activeIcon: Icon(Icons.groups, size: 22, color: kOrange),
          label: 'Ekip',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline, size: 22),
          activeIcon: Icon(Icons.person, size: 22, color: kOrange),
          label: 'Profil',
        ),
      ],
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
