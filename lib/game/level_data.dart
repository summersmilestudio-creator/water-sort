import 'dart:math';
import 'package:flutter/material.dart';

const kBottleCapacity = 4;

const kColors = [
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFFFB8C00), // orange
  Color(0xFF43A047), // green
  Color(0xFF8E24AA), // purple
  Color(0xFFFFEB3B), // yellow
  Color(0xFF00ACC1), // cyan
  Color(0xFFFF4081), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF7CB342), // lime
];

class Bottle {
  final List<Color> liquid; // bottom -> top
  Bottle(this.liquid);
  Bottle clone() => Bottle(List.of(liquid));
  bool get isEmpty => liquid.isEmpty;
  bool get isFull => liquid.length >= kBottleCapacity;
  Color? get top => liquid.isEmpty ? null : liquid.last;
  bool get sorted =>
      liquid.length == kBottleCapacity &&
      liquid.every((c) => c == liquid.first);
}

class WaterLevel {
  final List<Bottle> bottles;
  WaterLevel(this.bottles);

  static WaterLevel generate(int level) {
    // Increase difficulty: 4 colors @ lvl 1 → 8 @ lvl 5+
    final numColors = (3 + (level / 2).floor()).clamp(3, kColors.length);
    final emptyBottles = level >= 3 ? 2 : 1;

    // Build solved state then shuffle
    final all = <Color>[];
    for (var i = 0; i < numColors; i++) {
      for (var j = 0; j < kBottleCapacity; j++) {
        all.add(kColors[i]);
      }
    }
    all.shuffle(Random(level * 1000));

    final bottles = <Bottle>[];
    for (var i = 0; i < numColors; i++) {
      final start = i * kBottleCapacity;
      bottles.add(Bottle(all.sublist(start, start + kBottleCapacity)));
    }
    for (var i = 0; i < emptyBottles; i++) {
      bottles.add(Bottle([]));
    }
    return WaterLevel(bottles);
  }

  WaterLevel clone() => WaterLevel(bottles.map((b) => b.clone()).toList());

  bool pour(int from, int to) {
    if (from == to) return false;
    final src = bottles[from];
    final dst = bottles[to];
    if (src.isEmpty) return false;
    if (dst.isFull) return false;
    if (dst.isNotEmpty && dst.top != src.top) return false;

    // Count consecutive same-color from top of src
    var count = 0;
    final color = src.top;
    for (var i = src.liquid.length - 1; i >= 0; i--) {
      if (src.liquid[i] == color) {
        count++;
      } else {
        break;
      }
    }
    final canMove = count.clamp(0, kBottleCapacity - dst.liquid.length);
    if (canMove == 0) return false;

    for (var i = 0; i < canMove; i++) {
      dst.liquid.add(src.liquid.removeLast());
    }
    return true;
  }

  bool get isSolved {
    return bottles.every((b) => b.isEmpty || b.sorted);
  }
}
