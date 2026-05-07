import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/level_data.dart';

class GameScreen extends StatefulWidget {
  final int level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late WaterLevel _level;
  int? _selected;
  final List<WaterLevel> _undoStack = [];
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _level = WaterLevel.generate(widget.level);
  }

  void _onTapBottle(int idx) {
    if (_won) return;
    HapticFeedback.lightImpact();
    if (_selected == null) {
      if (_level.bottles[idx].isEmpty) return;
      setState(() => _selected = idx);
    } else if (_selected == idx) {
      setState(() => _selected = null);
    } else {
      _undoStack.add(_level.clone());
      if (_undoStack.length > 30) _undoStack.removeAt(0);
      final ok = _level.pour(_selected!, idx);
      if (!ok) {
        _undoStack.removeLast();
      } else {
        HapticFeedback.mediumImpact();
      }
      setState(() => _selected = null);
      if (_level.isSolved && !_won) {
        _won = true;
        _saveProgress();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('🎉 Nivel complet!'),
              content: Text('Felicitări! Ai sortat lichidul nivelului ${widget.level}'),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(c);
                      Navigator.pop(context);
                    },
                    child: const Text('Înapoi')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(c);
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  GameScreen(level: widget.level + 1)));
                    },
                    child: const Text('Următorul')),
              ],
            ),
          );
        });
      }
    }
  }

  Future<void> _saveProgress() async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getInt('waterMax') ?? 1;
    if (widget.level + 1 > cur) {
      await p.setInt('waterMax', widget.level + 1);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _level = _undoStack.removeLast();
      _selected = null;
    });
  }

  void _restart() {
    setState(() {
      _level = WaterLevel.generate(widget.level);
      _selected = null;
      _undoStack.clear();
      _won = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nivel ${widget.level}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _restart),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(builder: (ctx, c) {
            final n = _level.bottles.length;
            final cols = n <= 6 ? n : (n / 2).ceil();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 24,
                children: [
                  for (var i = 0; i < n; i++)
                    GestureDetector(
                      onTap: () => _onTapBottle(i),
                      child: _BottleWidget(
                        bottle: _level.bottles[i],
                        selected: _selected == i,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottleWidget extends StatelessWidget {
  final Bottle bottle;
  final bool selected;
  const _BottleWidget({required this.bottle, required this.selected});

  @override
  Widget build(BuildContext context) {
    const w = 56.0;
    const segH = 32.0;
    final h = kBottleCapacity * segH + 24;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: w + 8,
      height: h + (selected ? 16 : 0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Bottle shape
          Positioned(
            bottom: 0,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? const Color(0xFFFFEB3B) : Colors.white60,
                  width: selected ? 3 : 2,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = bottle.liquid.length - 1; i >= 0; i--)
                      Container(
                        width: w,
                        height: segH,
                        color: bottle.liquid[i],
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Neck top
          Positioned(
            top: 0,
            child: Container(
              width: w + 8,
              height: 4,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFEB3B)
                    : Colors.white60,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
