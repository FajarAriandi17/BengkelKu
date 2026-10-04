import "package:bengkelku/features/booking/domain/cancellation_policy.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("cancellation_policy", () {
    final now = DateTime.utc(2026, 10, 2, 10, 0); // 10:00 UTC

    test(">= 2 jam sebelum slot -> refund 100%", () {
      final scheduledAt = DateTime.utc(2026, 10, 2, 12, 0); // Exactly 2 hours later
      final result = calculateRefund(
        scheduledAt: scheduledAt,
        now: now,
        totalPaidIdr: 100000,
      );

      expect(result.percentage, 1.0);
      expect(result.refundAmountIdr, 100000);
    });

    test(">= 3 jam sebelum slot -> refund 100%", () {
      final scheduledAt = DateTime.utc(2026, 10, 2, 13, 0);
      final result = calculateRefund(
        scheduledAt: scheduledAt,
        now: now,
        totalPaidIdr: 100000,
      );

      expect(result.percentage, 1.0);
      expect(result.refundAmountIdr, 100000);
    });

    test("< 2 jam sebelum slot (mis. 1 jam) -> refund 50%", () {
      final scheduledAt = DateTime.utc(2026, 10, 2, 11, 0); // 1 hour later
      final result = calculateRefund(
        scheduledAt: scheduledAt,
        now: now,
        totalPaidIdr: 100000,
      );

      expect(result.percentage, 0.5);
      expect(result.refundAmountIdr, 50000);
    });

    test("Lewat waktu slot atau no-show -> refund 0%", () {
      final scheduledAt = DateTime.utc(2026, 10, 2, 9, 30); // 30 mins ago
      final result = calculateRefund(
        scheduledAt: scheduledAt,
        now: now,
        totalPaidIdr: 100000,
      );

      expect(result.percentage, 0.0);
      expect(result.refundAmountIdr, 0);
    });
  });
}
