import 'package:flutter/material.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/game_juice.dart';
import '../services/meta_service.dart';
import '../services/audio_service.dart';
import '../services/purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'events_screen.dart';
import 'shop_screen.dart';

const _bgTop = Color(0xFF2A1E63);
const _bgMid = Color(0xFF1B1342);
const _bgBottom = Color(0xFF0E0A26);
const _bokeh = Color(0xFF18C6E6);
const _accent = Color(0xFF00BCD4);

const _decoColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFFEB3B),
  Color(0xFF43A047),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _maxLevel = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _maxLevel = p.getInt('waterMax') ?? 1);
    if (MetaService.instance.canClaimDaily) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDaily());
    }
  }

  Future<void> _play(int lvl) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => GameScreen(level: lvl)));
    _load();
  }

  Future<void> _openShop() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ShopScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _showNoAds() async {
    final ps = PurchaseService.instance;
    final price = ps.productFor(PurchaseService.noAdsId)?.price ?? '15 lei';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Fără reclame',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text(
          'Elimină definitiv bannerele și reclamele care te întrerup. O singură achiziție, pentru totdeauna.',
          style: TextStyle(color: Colors.white70, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ps.restore();
            },
            child: const Text('Restaurează',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ps.buy(PurchaseService.noAdsId);
            },
            child: Text('Cumpără • $price',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDaily() async {
    final meta = MetaService.instance;
    if (!meta.canClaimDaily) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Bonusul de azi e luat. Revino mâine! 🔥 ${meta.streak} zile'),
          duration: const Duration(seconds: 2)));
      return;
    }
    final reward = meta.pendingDailyReward;
    final claimed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF241A45),
        title: const Text('🎁 Bonus zilnic',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Color(0xFF00BCD4), size: 48),
            const SizedBox(height: 8),
            Text('+$reward monede',
                style: const TextStyle(
                    color: Color(0xFFFFD740),
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Serie: ${meta.streak + 1} ${meta.streak == 0 ? "zi" : "zile"}',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Revendică 🪙',
                  style: TextStyle(
                      color: Color(0xFFFFD740),
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (claimed == true) {
      await meta.claimDaily();
      AudioService.instance.coin();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgMid,
      bottomNavigationBar: const BannerAdWidget(),
      body: PremiumBackground(
        colors: const [_bgTop, _bgMid, _bgBottom],
        bokeh: _bokeh,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ListenableBuilder(
                      listenable: MetaService.instance,
                      builder: (context, _) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
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
                            Text('${MetaService.instance.coins}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          PurchaseService.instance.noAdsNotifier,
                      builder: (context, noAds, _) => noAds
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _TopIconButton(
                                icon: Icons.block_rounded,
                                onTap: _showNoAds,
                              ),
                            ),
                    ),
                    _TopIconButton(
                      icon: Icons.card_giftcard_rounded,
                      badge: MetaService.instance.canClaimDaily,
                      onTap: _showDaily,
                    ),
                    const SizedBox(width: 8),
                    _TopIconButton(
                        icon: Icons.storefront_rounded, onTap: _openShop),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in _decoColors)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _MiniBottle(color: c),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0xFF4DD0E1), _accent, Color(0xFF8BC34A)],
                  ).createShader(r),
                  child: const Text(
                    'WATER SORT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Toarnă lichidul ca să sortezi culorile',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                _PlayButton(
                  label: _maxLevel > 1 ? 'CONTINUĂ · Nivel $_maxLevel' : 'JOACĂ',
                  onTap: () => _play(_maxLevel),
                ),
                const SizedBox(height: 12),
                PressableScale(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const EventsScreen())),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_rounded, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Evenimente',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Alege nivelul',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Record: $_maxLevel',
                          style: const TextStyle(
                              color: _accent, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 40,
                    itemBuilder: (ctx, i) {
                      final lvl = i + 1;
                      final unlocked = lvl <= _maxLevel;
                      return _LevelTile(
                        level: lvl,
                        unlocked: unlocked,
                        current: lvl == _maxLevel,
                        onTap: unlocked ? () => _play(lvl) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PlayButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26C6DA), _accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final bool unlocked;
  final bool current;
  final VoidCallback? onTap;
  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.current,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: unlocked
                ? const LinearGradient(
                    colors: [Color(0xFF26C6DA), _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: unlocked ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border:
                current ? Border.all(color: Colors.white, width: 2.5) : null,
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: unlocked
                ? Text('$level',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900))
                : const Icon(Icons.lock_rounded,
                    color: Colors.white24, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Round translucent app-bar style button with an optional notification dot.
class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;
  const _TopIconButton(
      {required this.icon, this.badge = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF1744),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small glossy decorative bottle for the header.
class _MiniBottle extends StatelessWidget {
  final Color color;
  const _MiniBottle({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 56),
      painter: _MiniBottlePainter(color),
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
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.45, w, h * 0.55),
      Paint()..color = color,
    );
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
