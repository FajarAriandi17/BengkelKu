// Smoke test dasar: aplikasi BengkelKu dapat dibangun dan tema terang/gelap
// terdaftar sebagai ThemeExtension.

import 'package:bengkelku/core/theme/app_colors.dart';
import 'package:bengkelku/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tema terang AppColors berisi token v1.3', (tester) async {
    const colors = AppColors.light;

    expect(colors.ink2, isNotNull);
    expect(colors.line, isNotNull);
    expect(colors.blueText, isNotNull);
    expect(colors.warnC, isNotNull);
    expect(colors.okC, isNotNull);
    expect(colors.badC, isNotNull);
    expect(colors.stage, isNotNull);
  });

  testWidgets('AppTheme.light() memuat AppColors sebagai extension',
      (tester) async {
    final theme = AppTheme.light();

    expect(theme.extension<AppColors>(), isNotNull);
    expect(theme.extension<AppColors>()!.blue, AppColors.light.blue);
  });

  testWidgets('AppTheme.dark() memuat AppColors sebagai extension',
      (tester) async {
    final theme = AppTheme.dark();

    expect(theme.extension<AppColors>(), isNotNull);
    expect(theme.extension<AppColors>()!.blue, AppColors.dark.blue);
  });
}
