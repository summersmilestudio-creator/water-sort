import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/ads_service.dart';
import '../widgets/game_juice.dart';
import '../services/audio_service.dart';
import '../services/meta_service.dart';
import '../game/level_data.dart';
import '../game/skins.dart';

const _bgMid = Color(0xFF1B1342);
const _hintCost = 30;
const _coinsPerBottle = 5;
const _coinsPerLevel = 30;

class _Layout {
  final double bottleW, bottleH, topLift, boardW, boardH;
  final List<Offset> tops; // top-left of each bottle
  _Layout(this.bottleW, this.bottleH, this.topLift, this.boardW, this.boardH,
      this.tops);

  double get shoulder => bottleH * 0.10;
  double get segH => (bottleH - shoulder) / kBottleCapacity;
  Offset center(int i) => tops[i] + Offset(bottleW / 2, 0);
}

/// Snapshot of an in-flight pour, used to drive the tilt + stream animation.
class _Pour {
  final int from, to, count;
  final Color color;
  final int baseSrcLen, baseDstLen;
  final List<Color> srcLiquid; // settled source contents (bottom→top)
  final List<Color> dstLiquid; // settled dest contents (bottom→top)
  _Pour(this.from, this.to, this.count, this.color, this.baseSrcLen,
      this.baseDstLen, this.srcLiquid, this.dstLiquid);
}

class GameScreen extends StatefulWidget {
  final int level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late WaterLevel _level;
  int? _selected;
  final List<WaterLevel> _undoStack = [];
  bool _won = false;

  _Layout? _layout;
  _Pour? _pour;
  Offset? _boardOrigin;
  late final AnimationController _pourCtrl;
  bool _muted = AudioService.instance.muted;

  @override
  void initState() {
    super.initState();
    _level = WaterLevel.generate(widget.level);
    _pourCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _pour != null) _finishPour();
      });
  }

  @override
  void dispose() {
    _pourCtrl.dispose();
    super.dispose();
  }

  // ---- moves ----------------------------------------------------------------

  void _onTapBottle(int idx) {
    if (_won || _pour != null) return;
    HapticFeedback.lightImpact();
    AudioService.instance.tap();
    if (_selected == null) {
      if (_level.bottles[idx].isEmpty) return;
      setState(() => _selected = idx);
      return;
    }
    if (_selected == idx) {
      setState(() => _selected = null);
      return;
    }
    final from = _selected!;
    if (!_canPour(from, idx)) {
      AudioService.instance.error();
      setState(() => _selected = _level.bottles[idx].isEmpty ? null : idx);
      return;
    }
    _startPour(from, idx);
  }

  bool _canPour(int from, int to) {
    if (from == to) return false;
    final src = _level.bottles[from];
    final dst = _level.bottles[to];
    if (src.isEmpty || dst.isFull) return false;
    if (dst.isNotEmpty && dst.top != src.top) return false;
    return true;
  }

  void _startPour(int from, int to) {
    final src = _level.bottles[from];
    final dst = _level.bottles[to];
    final color = src.top!;
    var run = 0;
    for (var i = src.liquid.length - 1; i >= 0; i--) {
      if (src.liquid[i] == color) {
        run++;
      } else {
        break;
      }
    }
    final count = run.clamp(0, kBottleCapacity - dst.liquid.length);
    if (count == 0) return;

    _undoStack.add(_level.clone());
    if (_undoStack.length > 30) _undoStack.removeAt(0);

    AudioService.instance.pop();
    setState(() {
      _selected = null;
      _pour = _Pour(from, to, count, color, src.liquid.length,
          dst.liquid.length, List.of(src.liquid), List.of(dst.liquid));
    });
    _pourCtrl.forward(from: 0);
  }

  void _finishPour() {
    final p = _pour;
    if (p == null) return;
    _level.pour(p.from, p.to);
    AudioService.instance.place();
    HapticFeedback.selectionClick();
    final justCompleted = _level.bottles[p.to].sorted;
    setState(() => _pour = null);

    if (justCompleted) {
      AudioService.instance.match();
      AudioService.instance.coin();
      HapticFeedback.mediumImpact();
      MetaService.instance.addCoins(_coinsPerBottle);
      final L = _layout;
      final origin = _boardOrigin;
      if (L != null && origin != null) {
        BurstOverlay.show(
            context, origin + L.tops[p.to] + Offset(L.bottleW / 2, 4), p.color);
      }
    }

    if (_level.isSolved && !_won) {
      _won = true;
      MetaService.instance.addCoins(_coinsPerLevel);
      _saveProgress();
      Future.delayed(const Duration(milliseconds: 350), _celebrate);
    }
  }

  void _celebrate() {
    if (!mounted) return;
    AdsService.instance.maybeShowInterstitial();
    Celebrate.show(context);
    AudioService.instance.win();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('🎉 Nivel complet!'),
        content: Text(
            'Felicitări! Ai sortat lichidul nivelului ${widget.level}'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context);
              },
              child: const Text('Înapoi')),
          TextButton.icon(
            icon: const Icon(Icons.play_circle, color: Color(0xFFFFD740)),
            label: const Text('+2 niveluri 🎁',
                style: TextStyle(color: Color(0xFFFFD740))),
            onPressed: () async {
              Navigator.pop(c);
              final got = await AdsService.instance.showRewarded();
              if (!mounted || !got) return;
              final p = await SharedPreferences.getInstance();
              final cur = p.getInt('waterMax') ?? 1;
              final newMax = (widget.level + 3).clamp(cur, 1 << 30);
              await p.setInt('waterMax', newMax);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('🎁 +2 niveluri deblocate! Până la $newMax'),
                    duration: const Duration(seconds: 3)),
              );
            },
          ),
          TextButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(level: widget.level + 1)));
              },
              child: const Text('Următorul')),
        ],
      ),
    );
  }

  Future<void> _saveProgress() async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getInt('waterMax') ?? 1;
    if (widget.level + 1 > cur) await p.setInt('waterMax', widget.level + 1);
  }

  /// Finds a helpful pour: prefer onto a matching non-empty bottle, then a
  /// productive pour into an empty bottle. Returns null if nothing useful.
  List<int>? _findHint() {
    final b = _level.bottles;
    for (var from = 0; from < b.length; from++) {
      if (b[from].isEmpty || b[from].sorted) continue;
      for (var to = 0; to < b.length; to++) {
        if (to == from || b[to].isEmpty) continue;
        if (_canPour(from, to)) return [from, to];
      }
    }
    for (var from = 0; from < b.length; from++) {
      if (b[from].isEmpty) continue;
      final uniform = b[from].liquid.every((c) => c == b[from].liquid.first);
      if (uniform) continue;
      for (var to = 0; to < b.length; to++) {
        if (to == from) continue;
        if (b[to].isEmpty && _canPour(from, to)) return [from, to];
      }
    }
    return null;
  }

  Future<void> _useHint() async {
    if (_won || _pour != null) return;
    final hint = _findHint();
    if (hint == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nicio mutare utilă acum 🤔'),
          duration: Duration(seconds: 2)));
      return;
    }
    if (MetaService.instance.coins >= _hintCost) {
      await MetaService.instance.spend(_hintCost);
      _playHint(hint);
      return;
    }
    if (!mounted) return;
    final watch = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('💡 Indiciu'),
        content: const Text(
            'Nu ai destule monede. Urmărești o reclamă pentru un indiciu gratuit?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Renunț')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Urmărește 🎬')),
        ],
      ),
    );
    if (watch != true) return;
    final got = await AdsService.instance.showRewarded();
    if (!mounted || !got) return;
    final fresh = _findHint();
    if (fresh != null) _playHint(fresh);
  }

  void _playHint(List<int> hint) {
    HapticFeedback.lightImpact();
    setState(() => _selected = hint[0]);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || _pour != null || _won) return;
      if (_canPour(hint[0], hint[1])) _startPour(hint[0], hint[1]);
    });
  }

  void _undo() {
    if (_undoStack.isEmpty || _pour != null) return;
    HapticFeedback.lightImpact();
    AudioService.instance.swap();
    setState(() {
      _level = _undoStack.removeLast();
      _selected = null;
    });
  }

  void _restart() {
    setState(() {
      _level = WaterLevel.generate(widget.level);
      _selected = null;
      _pour = null;
      _undoStack.clear();
      _won = false;
    });
  }

  Future<void> _skipLevel() async {
    final nav = Navigator.of(context);
    final got = await AdsService.instance.showRewarded();
    if (!mounted || !got) return;
    _won = true;
    await _saveProgress();
    if (!mounted) return;
    nav.pushReplacement(MaterialPageRoute(
        builder: (_) => GameScreen(level: widget.level + 1)));
  }

  // ---- layout ---------------------------------------------------------------

  _Layout _computeLayout(double maxW, double maxH) {
    final n = _level.bottles.length;
    final rows = n <= 5 ? 1 : 2;
    final perRow = (n / rows).ceil();
    const gapX = 18.0;
    const gapY = 40.0;

    double bottleW = ((maxW - (perRow + 1) * gapX) / perRow).clamp(38.0, 60.0);
    double bottleH = bottleW * 3.2;
    final topLift = bottleH * 0.55;
    final rowBlock = topLift + bottleH + gapY;

    // shrink to fit height if needed
    final neededH = rows * rowBlock - gapY;
    if (neededH > maxH) {
      final scale = maxH / neededH;
      bottleW *= scale;
      bottleH *= scale;
    }
    final lift = bottleH * 0.55;
    final block = lift + bottleH + gapY;
    final boardW = maxW;
    final boardH = rows * block - gapY;

    final tops = <Offset>[];
    for (var i = 0; i < n; i++) {
      final r = i ~/ perRow;
      final c = i % perRow;
      final countInRow = (r == rows - 1) ? (n - perRow * (rows - 1)) : perRow;
      final rowWidth = countInRow * bottleW + (countInRow - 1) * gapX;
      final startX = (boardW - rowWidth) / 2;
      final x = startX + c * (bottleW + gapX);
      final y = r * block + lift;
      tops.add(Offset(x, y));
    }
    return _Layout(bottleW, bottleH, lift, boardW, boardH, tops);
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _bgMid,
      bottomNavigationBar: const BannerAdWidget(),
      appBar: AppBar(
        title: Text('Nivel ${widget.level}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          const _CoinChip(),
          IconButton(
            tooltip: 'Indiciu ($_hintCost monede)',
            icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFD740)),
            onPressed: _useHint,
          ),
          IconButton(icon: const Icon(Icons.undo_rounded), onPressed: _undo),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _restart),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'mute') {
                AudioService.instance.toggleMuted();
                setState(() => _muted = AudioService.instance.muted);
              } else if (v == 'skip') {
                _skipLevel();
              }
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                  value: 'mute',
                  child: Row(children: [
                    Icon(_muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded),
                    const SizedBox(width: 10),
                    Text(_muted ? 'Pornește sunetul' : 'Oprește sunetul'),
                  ])),
              const PopupMenuItem(
                  value: 'skip',
                  child: Row(children: [
                    Icon(Icons.skip_next_rounded, color: Color(0xFF69F0AE)),
                    SizedBox(width: 10),
                    Text('Sari peste nivel 🎬'),
                  ])),
            ],
          ),
        ],
      ),
      body: PremiumBackground(
        colors: activeSkin().bg,
        bokeh: activeSkin().bokeh,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: LayoutBuilder(builder: (ctx, c) {
                final L = _computeLayout(c.maxWidth, c.maxHeight);
                _layout = L;
                return SizedBox(
                  width: L.boardW,
                  height: L.boardH,
                  child: _buildBoard(L),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(_Layout L) {
    return AnimatedBuilder(
      animation: _pourCtrl,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final rb = context.findRenderObject() as RenderBox?;
          if (rb != null && rb.hasSize) {
            _boardOrigin = rb.localToGlobal(Offset.zero);
          }
        });

        final p = _pour;
        final v = _pourCtrl.value;
        // pose: 0 at slot → 1 hovering over dest → 0 back
        double pose = 0, pourProgress = 0;
        if (p != null) {
          if (v < 0.28) {
            pose = Curves.easeOut.transform((v / 0.28).clamp(0.0, 1.0));
          } else if (v < 0.82) {
            pose = 1;
            pourProgress = ((v - 0.28) / 0.54).clamp(0.0, 1.0);
          } else {
            pose = 1 - Curves.easeIn.transform(((v - 0.82) / 0.18).clamp(0.0, 1.0));
            pourProgress = 1;
          }
        }

        final children = <Widget>[];

        // bottles (all except the pouring source rendered in place)
        for (var i = 0; i < _level.bottles.length; i++) {
          if (p != null && i == p.from) continue;
          List<Color> liquid;
          double partialFrac = 0;
          Color? partialColor;
          if (p != null && i == p.to) {
            final added = p.count * pourProgress;
            final full = added.floor();
            partialFrac = added - full;
            partialColor = p.color;
            liquid = [...p.dstLiquid, ...List.filled(full, p.color)];
          } else {
            liquid = _level.bottles[i].liquid;
          }
          final lift = (_selected == i) ? L.bottleH * 0.06 : 0.0;
          children.add(Positioned(
            left: L.tops[i].dx,
            top: L.tops[i].dy - lift,
            child: GestureDetector(
              onTap: () => _onTapBottle(i),
              child: CustomPaint(
                size: Size(L.bottleW, L.bottleH),
                painter: _BottlePainter(
                  liquid: liquid,
                  capacity: kBottleCapacity,
                  selected: _selected == i,
                  partialFrac: partialFrac,
                  partialColor: partialColor,
                  completed: _level.bottles[i].sorted && p == null,
                ),
              ),
            ),
          ));
        }

        // pouring stream + tilted source on top
        if (p != null) {
          // source computed liquid (draining from top)
          final remaining = p.baseSrcLen - p.count * pourProgress;
          final srcFull = remaining.floor().clamp(0, p.srcLiquid.length);
          final srcPartial = (remaining - srcFull).clamp(0.0, 1.0);
          final srcLiquid = p.srcLiquid.sublist(0, srcFull);
          final srcPartialColor =
              srcFull < p.srcLiquid.length ? p.srcLiquid[srcFull] : null;

          final spoutLocal = Offset(L.bottleW / 2, 0);
          final slotSpout = L.tops[p.from] + spoutLocal;
          final sign = (L.tops[p.from].dx <= L.tops[p.to].dx) ? 1.0 : -1.0;
          final pourSpout = Offset(
            L.center(p.to).dx - sign * L.bottleW * 0.16,
            L.tops[p.to].dy - 6,
          );
          final curSpout = Offset.lerp(slotSpout, pourSpout, pose)!;
          final tilt = sign * 0.62 * pose;

          // stream (behind source, over dest)
          if (pose >= 0.999 && pourProgress > 0 && pourProgress < 1) {
            final destLevel = p.baseDstLen + p.count * pourProgress;
            final surfaceY = L.tops[p.to].dy +
                L.shoulder +
                (kBottleCapacity - destLevel) * L.segH;
            children.add(Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StreamPainter(
                    from: pourSpout,
                    toY: surfaceY,
                    color: p.color,
                  ),
                ),
              ),
            ));
          }

          children.add(Positioned(
            left: 0,
            top: 0,
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(curSpout.dx, curSpout.dy, 0, 1)
                ..rotateZ(tilt)
                ..translateByDouble(-spoutLocal.dx, -spoutLocal.dy, 0, 1),
              child: CustomPaint(
                size: Size(L.bottleW, L.bottleH),
                painter: _BottlePainter(
                  liquid: srcLiquid,
                  capacity: kBottleCapacity,
                  selected: false,
                  partialFrac: srcPartialColor != null ? srcPartial : 0,
                  partialColor: srcPartialColor,
                  completed: false,
                ),
              ),
            ),
          ));
        }

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

/// Live coin counter for the app bar.
class _CoinChip extends StatelessWidget {
  const _CoinChip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListenableBuilder(
        listenable: MetaService.instance,
        builder: (context, _) => Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFFD740), size: 18),
              const SizedBox(width: 5),
              Text('${MetaService.instance.coins}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated liquid stream falling from a spout into a bottle.
class _StreamPainter extends CustomPainter {
  final Offset from;
  final double toY;
  final Color color;
  _StreamPainter({required this.from, required this.toY, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (toY <= from.dy) return;
    final rect = Rect.fromLTWH(from.dx - 3, from.dy, 6, toY - from.dy);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(color, Colors.white, 0.4)!,
        color,
      ],
    ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..shader = shader,
    );
    // little splash where it lands
    canvas.drawCircle(
      Offset(from.dx, toY),
      4,
      Paint()..color = Color.lerp(color, Colors.white, 0.3)!,
    );
  }

  @override
  bool shouldRepaint(covariant _StreamPainter old) =>
      old.from != from || old.toY != toY || old.color != color;
}

/// Glossy 3D glass bottle with a cap, segmented liquid, an animating partial
/// top segment, a glass shine and (optionally) a completed glow.
class _BottlePainter extends CustomPainter {
  final List<Color> liquid; // index 0 = bottom
  final int capacity;
  final bool selected;
  final double partialFrac;
  final Color? partialColor;
  final bool completed;
  _BottlePainter({
    required this.liquid,
    required this.capacity,
    required this.selected,
    this.partialFrac = 0,
    this.partialColor,
    this.completed = false,
  });

  Color _lighten(Color c, double a) => Color.lerp(c, Colors.white, a)!;
  Color _darken(Color c, double a) => Color.lerp(c, Colors.black, a)!;

  void _segment(Canvas canvas, double w, Rect rect, Color c) {
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [_lighten(c, 0.30), c, _darken(c, 0.22)],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final neckW = w * 0.52;
    final shoulder = h * 0.10;

    final glass = selected
        ? const Color(0xFFFFD54F)
        : Colors.white.withValues(alpha: 0.5);

    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, shoulder, w, h - shoulder),
      topLeft: Radius.circular(w * 0.20),
      topRight: Radius.circular(w * 0.20),
      bottomLeft: Radius.circular(w * 0.34),
      bottomRight: Radius.circular(w * 0.34),
    );

    // completed glow
    if (completed && liquid.isNotEmpty) {
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = liquid.first.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }

    // faint glass fill
    canvas.drawRRect(body, Paint()..color = Colors.white.withValues(alpha: 0.05));

    // liquid segments (clipped to body)
    canvas.save();
    canvas.clipRRect(body);
    final segH = (h - shoulder) / capacity;
    for (var i = 0; i < liquid.length; i++) {
      final top = h - (i + 1) * segH;
      _segment(canvas, w, Rect.fromLTWH(0, top, w, segH + 0.6), liquid[i]);
      canvas.drawLine(Offset(0, top), Offset(w, top),
          Paint()..color = Colors.black.withValues(alpha: 0.14)..strokeWidth = 1);
    }
    // animating partial top segment
    if (partialFrac > 0 && partialColor != null) {
      final ph = segH * partialFrac;
      final top = h - liquid.length * segH - ph;
      _segment(canvas, w, Rect.fromLTWH(0, top, w, ph + 0.6), partialColor!);
    }
    // glossy vertical shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.12, shoulder + 6, w * 0.14, h - shoulder - 16),
          Radius.circular(w * 0.07)),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();

    // glass outline
    canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3.2 : 2.2
          ..color = glass);

    // neck
    final neck = RRect.fromRectAndCorners(
      Rect.fromLTWH((w - neckW) / 2, h * 0.02, neckW, shoulder + h * 0.02),
      topLeft: Radius.circular(w * 0.06),
      topRight: Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
        neck,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3.2 : 2.2
          ..color = glass);

    // cap
    final cap = RRect.fromRectAndRadius(
      Rect.fromLTWH((w - neckW) / 2 - 1, 0, neckW + 2, h * 0.055),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(cap, Paint()..color = const Color(0xFF455A64));
    canvas.drawRRect(
        cap,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _BottlePainter old) =>
      old.selected != selected ||
      old.liquid != liquid ||
      old.partialFrac != partialFrac ||
      old.partialColor != partialColor ||
      old.completed != completed;
}
