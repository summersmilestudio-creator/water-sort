import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'services/review_service.dart';
import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/audio_service.dart';
import 'services/meta_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'widgets/remove_ads_offer.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PurchaseService.instance.initialize();
  await AdsService.instance.initialize();
  await MetaService.instance.init();
  ReviewService.instance.registerLaunch();
  AudioService.instance.init();
  NotificationService.instance.scheduleDailyReminder(
    title: 'Water Sort Puzzle',
    body: 'Relaxează-te cu un puzzle de sortare! 🧪',
  );
  runApp(const WaterSortApp());
}

class WaterSortApp extends StatefulWidget {
  const WaterSortApp({super.key});

  @override
  State<WaterSortApp> createState() => _WaterSortAppState();
}

class _WaterSortAppState extends State<WaterSortApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Show the upsell right after a full-screen ad (App Open / interstitial) closes.
    AdsService.instance.adClosedTick.addListener(_onAdClosed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdsService.instance.adClosedTick.removeListener(_onAdClosed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdsService.instance.showAppOpenIfReady();
    }
  }

  void _onAdClosed() {
    RemoveAdsOffer.maybeShow(navigatorKey.currentContext);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Sort',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      ),
      home: UpgradeAlert(child: const HomeScreen()),
    );
  }
}
