import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'purchase_service.dart';

class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // iOS + Android = real AdMob units (Android app ~5144655668, created 2026-05-25).
  static const String _bannerIOS = 'ca-app-pub-5549243085914479/6342652888';
  static const String _interstitialIOS = 'ca-app-pub-5549243085914479/1815112290';
  static const String _rewardedIOS = 'ca-app-pub-5549243085914479/1090326200';
  static const String _bannerAndroid = 'ca-app-pub-5549243085914479/4484282906';
  static const String _interstitialAndroid = 'ca-app-pub-5549243085914479/8302136191';
  static const String _rewardedAndroid = 'ca-app-pub-5549243085914479/2010540107';

  // App Open (highest-value launch/return ad). Replace the two prod IDs with the
  // real AdMob App Open units (Android app ~5144655668 / iOS).
  static const String _appOpenProdAndroid = 'ca-app-pub-5549243085914479/7023290061';
  static const String _appOpenProdIOS = 'ca-app-pub-5549243085914479/4723741425';

  static const String _bannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _rewardedTest = 'ca-app-pub-3940256099942544/5224354917';
  static const String _appOpenTestAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String _appOpenTestIOS = 'ca-app-pub-3940256099942544/5575463023';

  static const Duration _minInterval = Duration(seconds: 45);
  static const Duration _appOpenMaxAge = Duration(hours: 4);

  bool _initialized = false;
  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;
  DateTime? _lastInterstitialShown;
  RewardedAd? _rewarded;
  bool _rewardedLoading = false;
  AppOpenAd? _appOpen;
  bool _appOpenLoading = false;
  DateTime? _appOpenLoadTime;
  bool _showingFullScreenAd = false;

  /// Bumped whenever a full-screen ad (App Open or interstitial) closes, so the
  /// UI can offer the "Remove ads" upsell right after.
  final ValueNotifier<int> adClosedTick = ValueNotifier(0);
  void _notifyAdClosed() => adClosedTick.value++;

  String get bannerUnitId {
    if (kDebugMode) return _bannerTest;
    return Platform.isIOS ? _bannerIOS : _bannerAndroid;
  }
  String get interstitialUnitId {
    if (kDebugMode) return _interstitialTest;
    return Platform.isIOS ? _interstitialIOS : _interstitialAndroid;
  }
  String get rewardedUnitId {
    if (kDebugMode) return _rewardedTest;
    return Platform.isIOS ? _rewardedIOS : _rewardedAndroid;
  }
  String get appOpenUnitId {
    if (kDebugMode) return Platform.isIOS ? _appOpenTestIOS : _appOpenTestAndroid;
    return Platform.isIOS ? _appOpenProdIOS : _appOpenProdAndroid;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
    _loadRewarded();
    loadAppOpen();
  }

  void loadAppOpen() {
    if (_appOpenLoading || _appOpen != null) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          _appOpenLoadTime = DateTime.now();
          _appOpenLoading = false;
        },
        onAdFailedToLoad: (err) {
          _appOpen = null;
          _appOpenLoading = false;
        },
      ),
    );
  }

  bool get _appOpenValid =>
      _appOpen != null &&
      _appOpenLoadTime != null &&
      DateTime.now().difference(_appOpenLoadTime!) < _appOpenMaxAge;

  /// Shows the App Open ad on app foreground if one is ready. Skips when another
  /// full-screen ad is showing, or none is loaded (then preloads).
  Future<void> showAppOpenIfReady() async {
    if (!_initialized || PurchaseService.instance.noAds) return;
    if (_showingFullScreenAd) return;
    if (!_appOpenValid) {
      loadAppOpen();
      return;
    }
    final ad = _appOpen!;
    _appOpen = null;
    _showingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _showingFullScreenAd = false;
        loadAppOpen();
        _notifyAdClosed();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _showingFullScreenAd = false;
        loadAppOpen();
      },
    );
    await ad.show();
  }

  void _loadInterstitial() {
    if (_interstitialLoading || _interstitial != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) { _interstitial = ad; _interstitialLoading = false; },
        onAdFailedToLoad: (err) { _interstitial = null; _interstitialLoading = false; },
      ),
    );
  }

  Future<void> maybeShowInterstitial() async {
    if (!_initialized) return;
    if (PurchaseService.instance.noAds) return;
    final now = DateTime.now();
    if (_lastInterstitialShown != null &&
        now.difference(_lastInterstitialShown!) < _minInterval) return;
    final ad = _interstitial;
    if (ad == null) { _loadInterstitial(); return; }
    _showingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _interstitial = null; _showingFullScreenAd = false;
        _lastInterstitialShown = DateTime.now(); _loadInterstitial();
        _notifyAdClosed();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _interstitial = null; _showingFullScreenAd = false;
        _loadInterstitial();
      },
    );
    await ad.show();
  }

  void _loadRewarded() {
    if (_rewardedLoading || _rewarded != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _rewarded = ad; _rewardedLoading = false; },
        onAdFailedToLoad: (err) { _rewarded = null; _rewardedLoading = false; },
      ),
    );
  }

  Future<bool> showRewarded() async {
    if (!_initialized) return false;
    final ad = _rewarded;
    if (ad == null) { _loadRewarded(); return false; }
    final completer = Completer<bool>();
    _showingFullScreenAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _rewarded = null; _showingFullScreenAd = false;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _rewarded = null; _showingFullScreenAd = false;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) {
      if (!completer.isCompleted) completer.complete(true);
    });
    return completer.future;
  }

  BannerAd createBanner({required AdSize size, void Function(Ad)? onLoaded}) {
    return BannerAd(
      adUnitId: bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onLoaded?.call(ad),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
  }
}
