import 'package:flutter/material.dart';
import '../services/meta_service.dart';

/// A cosmetic skin: the liquid palette + the background it pairs with.
/// Unlockable with coins — the core long-term retention lever.
class WaterSkin {
  final String id;
  final String name;
  final int cost; // 0 = free/default
  final List<Color> liquids; // 10 distinct colors
  final List<Color> bg; // 3 colors: center → mid → edge
  final Color bokeh;
  const WaterSkin({
    required this.id,
    required this.name,
    required this.cost,
    required this.liquids,
    required this.bg,
    required this.bokeh,
  });
}

const waterSkins = <WaterSkin>[
  WaterSkin(
    id: 'default',
    name: 'Clasic',
    cost: 0,
    liquids: [
      Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFB8C00),
      Color(0xFF43A047), Color(0xFF8E24AA), Color(0xFFFFEB3B),
      Color(0xFF00ACC1), Color(0xFFFF4081), Color(0xFF6D4C41),
      Color(0xFF7CB342),
    ],
    bg: [Color(0xFF2A1E63), Color(0xFF1B1342), Color(0xFF0E0A26)],
    bokeh: Color(0xFF18C6E6),
  ),
  WaterSkin(
    id: 'neon',
    name: 'Neon',
    cost: 300,
    liquids: [
      Color(0xFFFF1744), Color(0xFF00E5FF), Color(0xFFFFEA00),
      Color(0xFF00E676), Color(0xFFD500F9), Color(0xFFFF9100),
      Color(0xFF2979FF), Color(0xFFF50057), Color(0xFF76FF03),
      Color(0xFF1DE9B6),
    ],
    bg: [Color(0xFF1A0B2E), Color(0xFF0F0820), Color(0xFF050210)],
    bokeh: Color(0xFF00E5FF),
  ),
  WaterSkin(
    id: 'juice',
    name: 'Sucuri',
    cost: 400,
    liquids: [
      Color(0xFFFF6F00), Color(0xFFEF5350), Color(0xFFFFCA28),
      Color(0xFF66BB6A), Color(0xFFAB47BC), Color(0xFFFFEE58),
      Color(0xFF26C6DA), Color(0xFFEC407A), Color(0xFFFF7043),
      Color(0xFF9CCC65),
    ],
    bg: [Color(0xFF4A2C5A), Color(0xFF33203F), Color(0xFF1E1228)],
    bokeh: Color(0xFFFFCA28),
  ),
  WaterSkin(
    id: 'aqua',
    name: 'Aqua',
    cost: 500,
    liquids: [
      Color(0xFF00B0FF), Color(0xFF1DE9B6), Color(0xFF18FFFF),
      Color(0xFF536DFE), Color(0xFF64FFDA), Color(0xFF40C4FF),
      Color(0xFF0091EA), Color(0xFF00BFA5), Color(0xFF2962FF),
      Color(0xFF80D8FF),
    ],
    bg: [Color(0xFF0A3D5C), Color(0xFF062A40), Color(0xFF031824)],
    bokeh: Color(0xFF18FFFF),
  ),
  WaterSkin(
    id: 'lava',
    name: 'Lavă',
    cost: 700,
    liquids: [
      Color(0xFFFF3D00), Color(0xFFFF6F00), Color(0xFFFFC400),
      Color(0xFFD50000), Color(0xFFFF1744), Color(0xFFFFAB00),
      Color(0xFFDD2C00), Color(0xFFFF6E40), Color(0xFFFFD740),
      Color(0xFFBF360C),
    ],
    bg: [Color(0xFF4A1A0E), Color(0xFF2E1108), Color(0xFF1A0904)],
    bokeh: Color(0xFFFF6E40),
  ),
];

WaterSkin skinById(String id) =>
    waterSkins.firstWhere((s) => s.id == id, orElse: () => waterSkins.first);

/// The currently equipped skin (falls back to default).
WaterSkin activeSkin() => skinById(MetaService.instance.equipped);
