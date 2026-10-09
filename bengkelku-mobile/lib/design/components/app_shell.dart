// Komponen kerangka sesuai prototype "BengkelKu — Desain aplikasi":
// navigasi bawah melayang (pill aktif), ilustrasi bengkel, kartu & tile ikon.

import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/motion/motion.dart";
import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";
import "../../features/chat/presentation/chat_provider.dart";

/// Tab utama pengendara: Beranda, Peta, Garasi, Chat, Booking, Profil.
enum AppTab { home, map, garage, chat, bookings, profile }

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    this.badges = const {},
  });

  final AppTab current;
  final Map<AppTab, int> badges;

  static const _items = [
    (AppTab.home, "Beranda", Icons.home_outlined, Icons.home_rounded, "/home"),
    (AppTab.map, "Peta", Icons.map_outlined, Icons.map_rounded, "/home/map"),
    (
      AppTab.garage,
      "Garasi",
      Icons.two_wheeler_outlined,
      Icons.two_wheeler,
      "/garage",
    ),
    (
      AppTab.chat,
      "Chat",
      Icons.chat_bubble_outline_rounded,
      Icons.chat_bubble_rounded,
      "/chat",
    ),
    (
      AppTab.bookings,
      "Booking",
      Icons.calendar_today_outlined,
      Icons.calendar_month_rounded,
      "/bookings",
    ),
    (
      AppTab.profile,
      "Profil",
      Icons.person_outline_rounded,
      Icons.person_rounded,
      "/profile",
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final idx = _items.indexWhere((e) => e.$1 == current);
    final unread = ref.watch(chatUnreadCountProvider);
    final allBadges = {...badges, AppTab.chat: unread};
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: c.line),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth / _items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: Motion.respect(
                    context,
                    const Duration(milliseconds: 450),
                  ),
                  curve: Motion.respectCurve(context, Motion.spring),
                  left: w * idx,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.blue,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final it in _items)
                      Expanded(
                        child: _NavButton(
                          label: it.$2,
                          icon: it.$1 == current ? it.$4 : it.$3,
                          selected: it.$1 == current,
                          badge: allBadges[it.$1] ?? 0,
                          onTap: () {
                            if (it.$1 != current) context.go(it.$5);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? Colors.white : c.ink2;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 9 ? "9+" : "$badge"),
              backgroundColor: c.heart,
              child: Icon(icon, size: 22, color: fg),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: fg,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu putih baku (radius 20, garis tipis).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: color ?? c.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: borderColor ?? c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Kotak ikon lembut (latar blueSoft) seperti di prototype.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 48,
    this.color,
    this.background,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? c.blueSoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.48, color: color ?? c.blueText),
    );
  }
}

/// Tombol ikon persegi putih (notifikasi, tambah, dll.).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: c.ink),
          ),
        ),
      ),
    );
  }
}

/// Kotak statistik kecil (nilai + label) — detail bengkel & dasbor.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.onTap,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.h2.copyWith(color: valueColor ?? c.ink),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: c.ink2),
          ),
        ],
      ),
    );
  }
}

/// Pil status kecil (latar lembut + teks berwarna).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustrasi ruko bengkel (pengganti foto bila bengkel belum unggah foto).
class WorkshopIllustration extends StatelessWidget {
  const WorkshopIllustration({super.key, this.seed = 0, this.photoUrl});

  final int seed;
  final String? photoUrl;

  static const _palettes = [
    (Color(0xFF2B5BF0), Color(0xFFFFC94D), Color(0xFFDDE7FF)),
    (Color(0xFFE85D3A), Color(0xFF243B6B), Color(0xFFFFE3D6)),
    (Color(0xFF14A37F), Color(0xFF1F4FD8), Color(0xFFD9F3EA)),
    (Color(0xFF6B4BD8), Color(0xFFFFB020), Color(0xFFE8E1FF)),
  ];

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _paint(),
      );
    }
    return _paint();
  }

  Widget _paint() {
    final p = _palettes[seed.abs() % _palettes.length];
    return CustomPaint(
      painter: _ShopPainter(p.$1, p.$2, p.$3),
      child: const SizedBox.expand(),
    );
  }
}

class _ShopPainter extends CustomPainter {
  _ShopPainter(this.wall, this.sign, this.sky);
  final Color wall;
  final Color sign;
  final Color sky;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRect(Offset.zero & s, Paint()..color = sky);
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(w * 0.82, h * 0.2), h * 0.12, cloud);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.14, w * 0.3, h * 0.07),
        const Radius.circular(20),
      ),
      cloud,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
      Paint()..color = const Color(0xFF334155),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.1, h * 0.36, w * 0.62, h * 0.5),
      Paint()..color = wall,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.17, h * 0.24, w * 0.48, h * 0.13),
        const Radius.circular(6),
      ),
      Paint()..color = sign,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.29, w * 0.32, h * 0.03),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    final sh = Rect.fromLTWH(w * 0.16, h * 0.46, w * 0.34, h * 0.4);
    canvas.drawRect(sh, Paint()..color = Colors.black.withValues(alpha: 0.28));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = math.max(1, h * 0.012);
    for (var y = sh.top + h * 0.04; y < sh.bottom; y += h * 0.045) {
      canvas.drawLine(Offset(sh.left, y), Offset(sh.right, y), line);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.54, h * 0.5, w * 0.14, h * 0.13),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    final bike = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, h * 0.03)
      ..strokeCap = StrokeCap.round;
    final r = h * 0.08;
    final cy = h * 0.8;
    canvas.drawCircle(Offset(w * 0.66, cy), r, bike);
    canvas.drawCircle(Offset(w * 0.88, cy), r, bike);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.66, cy)
        ..lineTo(w * 0.72, cy - h * 0.1)
        ..lineTo(w * 0.82, cy - h * 0.1)
        ..lineTo(w * 0.88, cy),
      bike,
    );
  }

  @override
  bool shouldRepaint(_ShopPainter old) => old.wall != wall;
}

/// Gauge oli kecil (busur 180°, ikon tetes di tengah) — garasi & beranda.
class MiniOilGauge extends StatelessWidget {
  const MiniOilGauge({
    super.key,
    required this.progress,
    required this.color,
    this.size = 72,
    this.trackColor,
    this.iconColor,
  });

  final double progress;
  final Color color;
  final double size;
  final Color? trackColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: Motion.respect(context, const Duration(milliseconds: 1100)),
      curve: Motion.easeOut,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size * 0.62,
        child: CustomPaint(
          painter: _ArcPainter(v, color, trackColor ?? c.line),
          child: Align(
            alignment: const Alignment(0, 0.7),
            child: Icon(
              Icons.water_drop_outlined,
              size: size * 0.3,
              color: iconColor ?? c.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.p, this.color, this.track);
  final double p;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size s) {
    final stroke = s.width * 0.1;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      s.width - stroke,
      s.width - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi, math.pi, false, paint);
    if (p > 0) {
      canvas.drawArc(rect, math.pi, math.pi * p, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.p != p || o.color != color;
}
