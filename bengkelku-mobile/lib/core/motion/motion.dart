import "package:flutter/widgets.dart";

/// Konstanta gerak BengkelKu (lihat docs/ANIMATIONS.md).
/// Jangan tulis durasi/kurva ajaib di widget — ambil dari sini.
/// Selalu hormati Reduce Motion lewat [Motion.respect].
class Motion {
  Motion._();

  // Kurva
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);

  // Durasi
  static const Duration micro = Duration(milliseconds: 180);
  static const Duration microSlow = Duration(milliseconds: 250);
  static const Duration dStd = Duration(milliseconds: 250);
  static const Duration screen = Duration(milliseconds: 420);
  static const Duration stagger = Duration(milliseconds: 60);
  static const Duration reduced = Duration(milliseconds: 100);

  /// Kembalikan durasi yang menghormati preferensi Reduce Motion OS.
  /// Jika Reduce Motion aktif, kembalikan [reduced] (atau nol untuk instan).
  static Duration respect(
    BuildContext context,
    Duration normal, {
    bool instant = false,
  }) {
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!disable) return normal;
    return instant ? Duration.zero : reduced;
  }

  /// Kurva yang aman saat Reduce Motion (linear/instan agar tak ada overshoot).
  static Curve respectCurve(BuildContext context, Curve normal) {
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return disable ? Curves.linear : normal;
  }
}
