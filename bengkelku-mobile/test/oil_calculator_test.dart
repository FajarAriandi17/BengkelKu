import "package:bengkelku/features/oil/domain/oil_calculator.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("oilStage", () {
    test("ok saat jauh dari target (km & hari)", () {
      expect(
        oilStage(remainingKm: 1500, remainingDays: 60),
        OilStage.ok,
      );
    });

    test("soon saat sisa km <= 300", () {
      expect(oilStage(remainingKm: 300, remainingDays: 60), OilStage.soon);
      expect(oilStage(remainingKm: 150, remainingDays: 60), OilStage.soon);
    });

    test("soon saat sisa hari <= 7", () {
      expect(oilStage(remainingKm: 1500, remainingDays: 7), OilStage.soon);
      expect(oilStage(remainingKm: 1500, remainingDays: 1), OilStage.soon);
    });

    test("late saat sisa km <= 0", () {
      expect(oilStage(remainingKm: 0, remainingDays: 30), OilStage.late);
      expect(oilStage(remainingKm: -50, remainingDays: 30), OilStage.late);
    });

    test("late saat sisa hari <= 0", () {
      expect(oilStage(remainingKm: 500, remainingDays: 0), OilStage.late);
      expect(oilStage(remainingKm: 500, remainingDays: -3), OilStage.late);
    });

    test("late menang atas soon", () {
      expect(oilStage(remainingKm: -10, remainingDays: 3), OilStage.late);
    });

    test("ambang dapat dikonfigurasi", () {
      expect(
        oilStage(
          remainingKm: 400,
          remainingDays: 60,
          soonKm: 500,
        ),
        OilStage.soon,
      );
    });
  });

  group("target & sisa", () {
    test("nextOilTargetKm menambah interval", () {
      expect(
        nextOilTargetKm(odometerAtService: 12000, intervalKm: 4000),
        16000,
      );
    });

    test("nextOilTargetDate menambah hari", () {
      final base = DateTime.utc(2026);
      expect(
        nextOilTargetDate(serviceDate: base, intervalDays: 90),
        DateTime.utc(2026, 4),
      );
    });

    test("remainingKm & remainingDays", () {
      expect(remainingKm(targetKm: 16000, currentOdometer: 15800), 200);
      expect(
        remainingDays(
          targetDate: DateTime.utc(2026, 1, 10),
          now: DateTime.utc(2026),
        ),
        9,
      );
    });

    test("alur end-to-end: servis → mendekati → soon", () {
      const target = 16000;
      final targetDate = DateTime.utc(2026, 4);
      final rKm = remainingKm(targetKm: target, currentOdometer: 15750);
      final rDays = remainingDays(
        targetDate: targetDate,
        now: DateTime.utc(2026, 3, 20),
      );
      expect(oilStage(remainingKm: rKm, remainingDays: rDays), OilStage.soon);
    });
  });
}
