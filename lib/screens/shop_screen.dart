import 'package:flutter/material.dart';
import '../services/meta_service.dart';
import '../services/audio_service.dart';
import '../game/skins.dart';

const _accent = Color(0xFF00BCD4);

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Future<void> _onTapSkin(WaterSkin skin) async {
    final meta = MetaService.instance;
    if (meta.isUnlocked(skin.id)) {
      await meta.equip(skin.id);
      AudioService.instance.tap();
      setState(() {});
      return;
    }
    if (meta.coins < skin.cost) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Îți mai trebuie ${skin.cost - meta.coins} monede. Joacă niveluri ca să câștigi! 🪙'),
          duration: const Duration(seconds: 2)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Cumperi "${skin.name}"?'),
        content: Text('Cost: ${skin.cost} monede.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Nu')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cumpără')),
        ],
      ),
    );
    if (ok != true) return;
    if (await meta.spend(skin.cost)) {
      await meta.unlock(skin.id);
      await meta.equip(skin.id);
      AudioService.instance.coin();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = MetaService.instance;
    return Scaffold(
      backgroundColor: const Color(0xFF1B1342),
      appBar: AppBar(
        title: const Text('Magazin',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: ListenableBuilder(
              listenable: meta,
              builder: (context, _) => Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: Color(0xFFFFD740), size: 20),
                    const SizedBox(width: 6),
                    Text('${meta.coins}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: meta,
        builder: (context, _) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: waterSkins.length,
          itemBuilder: (ctx, i) {
            final skin = waterSkins[i];
            return _SkinCard(
              skin: skin,
              unlocked: meta.isUnlocked(skin.id),
              equipped: meta.equipped == skin.id,
              onTap: () => _onTapSkin(skin),
            );
          },
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final WaterSkin skin;
  final bool unlocked;
  final bool equipped;
  final VoidCallback onTap;
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.2,
            colors: skin.bg,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: equipped ? _accent : Colors.white.withValues(alpha: 0.12),
            width: equipped ? 3 : 1.5,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(skin.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in skin.liquids.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _miniBottle(c),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _actionChip(),
          ],
        ),
      ),
    );
  }

  Widget _miniBottle(Color color) {
    return CustomPaint(size: const Size(20, 52), painter: _MiniBottlePainter(color));
  }

  Widget _actionChip() {
    if (equipped) return _chip('Echipat ✓', _accent, Colors.white);
    if (unlocked) {
      return _chip('Echipează', Colors.white.withValues(alpha: 0.15), Colors.white);
    }
    return _chip('${skin.cost} 🪙', const Color(0xFFFFD740), Colors.black);
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

class _MiniBottlePainter extends CustomPainter {
  final Color color;
  _MiniBottlePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, h * 0.12, w, h * 0.88),
      topLeft: Radius.circular(w * 0.2),
      topRight: Radius.circular(w * 0.2),
      bottomLeft: Radius.circular(w * 0.35),
      bottomRight: Radius.circular(w * 0.35),
    );
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.45, w, h * 0.55), Paint()..color = color);
    canvas.restore();
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniBottlePainter old) => old.color != color;
}
