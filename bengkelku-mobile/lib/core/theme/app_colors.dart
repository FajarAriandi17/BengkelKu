import "package:flutter/material.dart";

/// Token warna BengkelKu sebagai ThemeExtension.
/// Jangan hardcode warna di widget — pakai `Theme.of(context).extension<AppColors>()!`
/// atau helper `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.panel,
    required this.panel2,
    required this.stage,
    required this.ink,
    required this.ink2,
    required this.line,
    required this.blue,
    required this.blueText,
    required this.blueSoft,
    required this.ok,
    required this.okText,
    required this.okSoft,
    required this.okC,
    required this.warn,
    required this.warnText,
    required this.warnSoft,
    required this.warnC,
    required this.bad,
    required this.badText,
    required this.badSoft,
    required this.badC,
    required this.mapBg,
    required this.star,
    required this.heart,
  });

  final Color panel;
  final Color panel2;
  final Color stage;
  final Color ink;
  final Color ink2;
  final Color line;
  final Color blue;
  final Color blueText;
  final Color blueSoft;
  final Color ok;
  final Color okText;
  final Color okSoft;
  final Color okC;
  final Color warn;
  final Color warnText;
  final Color warnSoft;
  final Color warnC;
  final Color bad;
  final Color badText;
  final Color badSoft;
  final Color badC;
  final Color mapBg;
  final Color star;
  final Color heart;

  static const light = AppColors(
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFF3F5FB),
    stage: Color(0xFFE9EDF7),
    ink: Color(0xFF0F172A),
    ink2: Color(0xFF566078),
    line: Color(0xFFE0E5F0),
    blue: Color(0xFF1F4FD8),
    blueText: Color(0xFF1F4FD8),
    blueSoft: Color(0xFFE4EBFF),
    ok: Color(0xFF15803D),
    okText: Color(0xFF15803D),
    okSoft: Color(0xFFDCFCE7),
    okC: Color(0xFF16A34A),
    warn: Color(0xFFB45309),
    warnText: Color(0xFFB45309),
    warnSoft: Color(0xFFFEF3C7),
    warnC: Color(0xFFF59E0B),
    bad: Color(0xFFB91C1C),
    badText: Color(0xFFB91C1C),
    badSoft: Color(0xFFFEE2E2),
    badC: Color(0xFFDC2626),
    mapBg: Color(0xFFE9EEF8),
    star: Color(0xFFF59E0B),
    heart: Color(0xFFE11D48),
  );

  static const dark = AppColors(
    panel: Color(0xFF121A30),
    panel2: Color(0xFF0D1427),
    stage: Color(0xFF070B16),
    ink: Color(0xFFE8ECF8),
    ink2: Color(0xFF9AA6BF),
    line: Color(0xFF25304D),
    blue: Color(0xFF3A66F2),
    blueText: Color(0xFF8FADFF),
    blueSoft: Color(0xFF18265A),
    ok: Color(0xFF4ADE80),
    okText: Color(0xFF4ADE80),
    okSoft: Color(0xFF14321F),
    okC: Color(0xFF16A34A),
    warn: Color(0xFFFBBF24),
    warnText: Color(0xFFFBBF24),
    warnSoft: Color(0xFF3A2A08),
    warnC: Color(0xFFF59E0B),
    bad: Color(0xFFF87171),
    badText: Color(0xFFF87171),
    badSoft: Color(0xFF3F1414),
    badC: Color(0xFFDC2626),
    mapBg: Color(0xFF16203A),
    star: Color(0xFFF59E0B),
    heart: Color(0xFFFB7185),
  );

  @override
  AppColors copyWith({
    Color? panel,
    Color? panel2,
    Color? stage,
    Color? ink,
    Color? ink2,
    Color? line,
    Color? blue,
    Color? blueText,
    Color? blueSoft,
    Color? ok,
    Color? okText,
    Color? okSoft,
    Color? okC,
    Color? warn,
    Color? warnText,
    Color? warnSoft,
    Color? warnC,
    Color? bad,
    Color? badText,
    Color? badSoft,
    Color? badC,
    Color? mapBg,
    Color? star,
    Color? heart,
  }) {
    return AppColors(
      panel: panel ?? this.panel,
      panel2: panel2 ?? this.panel2,
      stage: stage ?? this.stage,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      line: line ?? this.line,
      blue: blue ?? this.blue,
      blueText: blueText ?? this.blueText,
      blueSoft: blueSoft ?? this.blueSoft,
      ok: ok ?? this.ok,
      okText: okText ?? this.okText,
      okSoft: okSoft ?? this.okSoft,
      okC: okC ?? this.okC,
      warn: warn ?? this.warn,
      warnText: warnText ?? this.warnText,
      warnSoft: warnSoft ?? this.warnSoft,
      warnC: warnC ?? this.warnC,
      bad: bad ?? this.bad,
      badText: badText ?? this.badText,
      badSoft: badSoft ?? this.badSoft,
      badC: badC ?? this.badC,
      mapBg: mapBg ?? this.mapBg,
      star: star ?? this.star,
      heart: heart ?? this.heart,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      panel: Color.lerp(panel, other.panel, t)!,
      panel2: Color.lerp(panel2, other.panel2, t)!,
      stage: Color.lerp(stage, other.stage, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      line: Color.lerp(line, other.line, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      blueText: Color.lerp(blueText, other.blueText, t)!,
      blueSoft: Color.lerp(blueSoft, other.blueSoft, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      okText: Color.lerp(okText, other.okText, t)!,
      okSoft: Color.lerp(okSoft, other.okSoft, t)!,
      okC: Color.lerp(okC, other.okC, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnText: Color.lerp(warnText, other.warnText, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      warnC: Color.lerp(warnC, other.warnC, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      badText: Color.lerp(badText, other.badText, t)!,
      badSoft: Color.lerp(badSoft, other.badSoft, t)!,
      badC: Color.lerp(badC, other.badC, t)!,
      mapBg: Color.lerp(mapBg, other.mapBg, t)!,
      star: Color.lerp(star, other.star, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
