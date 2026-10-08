import "package:bengkelku/features/owner/data/owner_schedule.dart";
import "package:bengkelku/features/owner/presentation/owner_schedule_screen.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("DayHours", () {
    test("parse HH:MM:SS dari Postgres & validasi", () {
      final d = DayHours.fromJson({
        "weekday": 1,
        "open_time": "08:00:00",
        "close_time": "17:30:00",
        "is_closed": false,
      });
      expect(d.open, "08:00");
      expect(d.close, "17:30");
      expect(d.dayName, "Senin");
      expect(d.isValid, isTrue);
      expect(d.copyWith(close: "07:00").isValid, isFalse);
      expect(d.copyWith(close: "07:00", isClosed: true).isValid, isTrue);
    });

    test("slot per hari", () {
      const d =
          DayHours(weekday: 2, open: "09:00", close: "12:00", isClosed: false);
      expect(OwnerSchedule.slotsPerDay(d, 30), 6);
      expect(OwnerSchedule.slotsPerDay(d, 45), 4);
      expect(OwnerSchedule.slotsPerDay(d.copyWith(isClosed: true), 30), 0);
    });
  });

  test("OwnerSchedule melengkapi 7 hari & tutup sementara", () {
    final s = OwnerSchedule.fromJson({
      "is_open": false,
      "has_hours": true,
      "hours": [
        {
          "weekday": 3,
          "open_time": "10:00",
          "close_time": "15:00",
          "is_closed": false
        },
      ],
      "slot_minutes": 30,
      "capacity_per_slot": 2,
      "closures": [
        {"date": "2030-01-01", "reason": "Tahun baru", "active_bookings": 2},
      ],
      "temp_closed_until": DateTime.now()
          .add(const Duration(hours: 2))
          .toUtc()
          .toIso8601String(),
      "temp_closed_reason": "Hujan deras",
    });
    expect(s.hours.length, 7);
    expect(s.hours[3].open, "10:00");
    expect(s.isTempClosed, isTrue);
    expect(s.closures.single.activeBookings, 2);
    expect(s.capacity, 2);
  });

  test("nextOpening melewati hari tutup", () {
    final hours = List.generate(
      7,
      (i) =>
          DayHours(weekday: i, open: "08:00", close: "17:00", isClosed: i != 1),
    );
    // Rabu 1 Jan 2025 → buka berikutnya Senin 6 Jan 08:00
    final next = nextOpening(hours, DateTime(2025, 1, 1, 10));
    expect(next, DateTime(2025, 1, 6, 8));
  });
}
