import 'package:flutter/material.dart';
import '../services/purchase_service.dart';

/// House promo shown right after an ad closes: offers to remove ads for a fixed
/// price. Rate-limited so it never feels spammy.
class RemoveAdsOffer {
  RemoveAdsOffer._();

  static DateTime? _lastShown;
  static bool _open = false;
  static const Duration _cooldown = Duration(minutes: 2);

  /// Fallback price label if the store price hasn't loaded yet.
  static const String _fallbackPrice = '15 lei';

  static bool get _due {
    if (PurchaseService.instance.noAds) return false;
    if (_open) return false;
    if (_lastShown != null && DateTime.now().difference(_lastShown!) < _cooldown) {
      return false;
    }
    return true;
  }

  static Future<void> maybeShow(BuildContext? context) async {
    if (context == null) return;
    if (!_due) return;
    _lastShown = DateTime.now();
    _open = true;
    final price = PurchaseService.instance.productFor(PurchaseService.noAdsId)?.price ??
        _fallbackPrice;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFF26C6DA), Color(0xFF00BCD4)]),
                ),
                child: const Icon(Icons.block, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 16),
              const Text('Scapă de reclame',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'Joacă fără bannere și fără reclame care te întrerup. O singură dată, pentru totdeauna.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.3),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    PurchaseService.instance.buy(PurchaseService.noAdsId);
                  },
                  child: Text('Elimină reclamele • $price',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Mai târziu',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
    _open = false;
  }
}
