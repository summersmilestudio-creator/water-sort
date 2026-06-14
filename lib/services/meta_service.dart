import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent meta-progression: coins, daily bonus + streak, unlocked/equipped
/// skins. Drives the long-term retention loop. Generic across games.
class MetaService extends ChangeNotifier {
  MetaService._();
  static final MetaService instance = MetaService._();

  SharedPreferences? _p;
  bool _ready = false;

  static const _kCoins = 'meta_coins';
  static const _kLastClaim = 'meta_last_claim';
  static const _kStreak = 'meta_streak';
  static const _kUnlocked = 'meta_unlocked';
  static const _kEquipped = 'meta_equipped';

  /// Escalating daily reward by streak day (capped at index 6 = day 7+).
  static const dailyRewards = [25, 40, 60, 80, 120, 160, 250];

  Future<void> init() async {
    if (_ready) return;
    _p = await SharedPreferences.getInstance();
    _ready = true;
  }

  // ---- coins ----------------------------------------------------------------

  int get coins => _p?.getInt(_kCoins) ?? 0;

  Future<void> addCoins(int n) async {
    await _p?.setInt(_kCoins, coins + n);
    notifyListeners();
  }

  /// Spend [n] coins; returns false (no change) if the player can't afford it.
  Future<bool> spend(int n) async {
    if (coins < n) return false;
    await _p?.setInt(_kCoins, coins - n);
    notifyListeners();
    return true;
  }

  // ---- daily bonus + streak -------------------------------------------------

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get streak => _p?.getInt(_kStreak) ?? 0;

  bool get canClaimDaily => (_p?.getString(_kLastClaim) ?? '') != _today();

  /// The reward the player would get if they claimed right now.
  int get pendingDailyReward {
    final last = _p?.getString(_kLastClaim) ?? '';
    final yesterday = _ymd(DateTime.now().subtract(const Duration(days: 1)));
    final newStreak = (last == yesterday) ? streak + 1 : 1;
    return dailyRewards[(newStreak - 1).clamp(0, dailyRewards.length - 1)];
  }

  /// Claims the daily bonus. Returns the awarded amount (0 if already claimed).
  Future<int> claimDaily() async {
    if (!canClaimDaily) return 0;
    final last = _p?.getString(_kLastClaim) ?? '';
    final yesterday = _ymd(DateTime.now().subtract(const Duration(days: 1)));
    final newStreak = (last == yesterday) ? streak + 1 : 1;
    final reward =
        dailyRewards[(newStreak - 1).clamp(0, dailyRewards.length - 1)];
    await _p?.setInt(_kStreak, newStreak);
    await _p?.setString(_kLastClaim, _today());
    await _p?.setInt(_kCoins, coins + reward);
    notifyListeners();
    return reward;
  }

  // ---- skins ----------------------------------------------------------------

  Set<String> get unlocked =>
      (_p?.getStringList(_kUnlocked) ?? const <String>[]).toSet()..add('default');

  bool isUnlocked(String id) => id == 'default' || unlocked.contains(id);

  Future<void> unlock(String id) async {
    final s = unlocked..add(id);
    await _p?.setStringList(_kUnlocked, s.toList());
    notifyListeners();
  }

  String get equipped => _p?.getString(_kEquipped) ?? 'default';

  Future<void> equip(String id) async {
    await _p?.setString(_kEquipped, id);
    notifyListeners();
  }
}
