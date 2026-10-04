import "dart:math" as math;

import "package:flutter/material.dart";

import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";
import "../../features/oil/domain/oil_calculator.dart";

/// Gauge busur status oli. Warna mengikuti [OilStage]:
/// ok→hijau, soon→warn, late→bad. [progress] 0..1 (sisa umur oli).
class OilGauge extends StatelessWidget {
  const OilGauge({
    super.key,
    required this.progress,
    required this.stage,
    this.label,
    this.size = 160,
  });

  final double progress; // 0..1
  final OilStage stage;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (stage) {
      OilStage.ok => c.ok,
      OilStage.soon => c.warn,
      OilStage.late => c.bad,
    };
    final text = switch (stage) {
      OilStage.ok => "aman",
      OilStage.soon => "segera ganti",
      OilStage.late => "telat",
    };

    return Semantics(
      label: "status oli: $text",
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GaugePainter(
            progress: progress.clamp(0, 1),
            color: color,
            track: c.blueSoft,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label ?? text,
                    style: AppTypography.h2.copyWith(color: color)),
                Text("status oli", style: AppTypography.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  static const double _start = math.pi * 0.75; // 135°
  static const double _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, _start, _sweep, false, base);
    canvas.drawArc(rect, _start, _sweep * progress, false, fill);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}
