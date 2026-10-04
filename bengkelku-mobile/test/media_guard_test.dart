import "package:bengkelku/core/utils/media_guard.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("MediaGuard", () {
    test("isUnderLimit true untuk file <= 2 MB", () {
      expect(MediaGuard.isUnderLimit(1000), true);
      expect(MediaGuard.isUnderLimit(2 * 1024 * 1024), true);
    });

    test("isUnderLimit false untuk file > 2 MB", () {
      expect(MediaGuard.isUnderLimit((2 * 1024 * 1024) + 1), false);
    });

    test(
        "ensureUnderLimit melempar MediaTooLargeException dengan pesan baku persis",
        () {
      expect(
        () => MediaGuard.ensureUnderLimit((2 * 1024 * 1024) + 100),
        throwsA(
          isA<MediaTooLargeException>().having(
            (e) => e.message,
            "message",
            "ukuran media anda terlalu besar segera kompres file media untuk melanjutkan",
          ),
        ),
      );
    });
  });
}
