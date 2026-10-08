// Mode pratinjau desain (web) — HANYA aktif bila dibangun dengan
// --dart-define=DEMO_PREVIEW=true. Build rilis APK/AAB tidak menyetelnya,
// jadi selalu memakai Supabase & login sungguhan.

import "../../features/garage/data/vehicle_model.dart";
import "../../features/owner/data/owner_schedule.dart";
import "../../features/workshops/data/workshop_model.dart";

const bool kDemoPreview = bool.fromEnvironment("DEMO_PREVIEW");

class DemoData {
  DemoData._();

  static Workshop _w(
    String id,
    String n,
    String a,
    double r,
    int rc,
    double d,
    bool open,
  ) =>
      Workshop(
        id: id,
        ownerId: "demo",
        name: n,
        address: a,
        status: "verified",
        ratingAvg: r,
        ratingCount: rc,
        distanceMeters: d,
        isOpen: open,
        phone: "081234567890",
      );

  static final workshops = <Workshop>[
    _w("d1", "Maju Jaya Motor", "Jl. Melati Raya No. 12", 4.8, 214, 800, true),
    _w("d2", "Sinar Abadi Speed Shop", "Jl. Kenanga No. 7", 4.6, 132, 1400,
        true),
    _w("d3", "Bengkel Pak Haji Umar", "Jl. Anggrek Raya No. 3", 4.7, 98, 2100,
        true),
    _w("d4", "Rizky Motor Service", "Jl. Mawar No. 21", 4.4, 61, 3200, false),
  ];

  static WorkshopServiceItem _s(String id, String n, int p, int m) =>
      WorkshopServiceItem(
        id: id,
        workshopId: "d1",
        name: n,
        priceIdr: p,
        durationMinutes: m,
      );

  static final services = <WorkshopServiceItem>[
    _s("s1", "Ganti oli matic", 55000, 30),
    _s("s2", "Servis ringan", 85000, 60),
    _s("s3", "Ganti kampas rem", 70000, 45),
    _s("s4", "Tune up injeksi", 120000, 90),
  ];

  static final hours = List.generate(
    7,
    (i) => WorkshopHour(
      weekday: i,
      open: "08:00:00",
      close: "17:00:00",
      isClosed: i == 0,
    ),
  );

  static const vehicles = <Vehicle>[
    Vehicle(
      id: "v1",
      userId: "demo",
      brand: "Honda",
      model: "Vario 125",
      plate: "B 4821 XYZ",
      odometer: 12180,
      oilIntervalKm: 2500,
    ),
    Vehicle(
      id: "v2",
      userId: "demo",
      brand: "Honda",
      model: "Supra X 125",
      plate: "B 3377 KLM",
      odometer: 31920,
      oilIntervalKm: 3000,
    ),
  ];

  static Map<String, dynamic> get dashboard => {
        "workshop": {
          "id": "d1",
          "name": "Maju Jaya Motor",
          "status": "verified",
          "rating_avg": 4.8,
          "rating_count": 214,
        },
        "today_revenue": 640000,
        "today_count": 6,
        "waiting_confirmation": 1,
        "queue": [
          {
            "id": "7f3a21c4-0000-0000-0000-000000000000",
            "status": "DIBAYAR_MENUNGGU_KONFIRMASI",
            "scheduled_at": DateTime.now()
                .add(const Duration(hours: 3))
                .toUtc()
                .toIso8601String(),
            "total_idr": 55000,
            "rider_name": "Rian",
            "vehicle": "Honda Vario 125",
            "services": "Ganti oli matic",
          },
        ],
      };

  static OwnerSchedule schedule = OwnerSchedule(
    isOpen: true,
    hasHours: true,
    hours: List.generate(
      7,
      (i) => DayHours(
        weekday: i,
        open: "08:00",
        close: i == 6 ? "14:00" : "17:00",
        isClosed: i == 0,
      ),
    ),
    slotMinutes: 60,
    capacity: 2,
    closures: [
      Closure(
        date: DateTime.now().add(const Duration(days: 9)),
        reason: "Cuti bersama",
      ),
    ],
  );

  static OwnerSchedule update({
    List<DayHours>? hours,
    int? slotMinutes,
    int? capacity,
    DateTime? tempClosedUntil,
    String? tempClosedReason,
    bool clearTemp = false,
  }) {
    final s = schedule;
    final until = clearTemp ? null : (tempClosedUntil ?? s.tempClosedUntil);
    return schedule = OwnerSchedule(
      isOpen: until == null,
      hasHours: true,
      hours: hours ?? s.hours,
      slotMinutes: slotMinutes ?? s.slotMinutes,
      capacity: capacity ?? s.capacity,
      closures: s.closures,
      tempClosedUntil: until,
      tempClosedReason:
          clearTemp ? null : (tempClosedReason ?? s.tempClosedReason),
    );
  }
}
