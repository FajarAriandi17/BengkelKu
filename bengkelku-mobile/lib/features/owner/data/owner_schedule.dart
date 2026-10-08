// Model + repository jadwal buka/tutup yang diatur pemilik (migrasi 0026).

import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/demo/demo_data.dart";
import "../../../core/network/supabase_client.dart";

class DayHours {
  const DayHours({
    required this.weekday,
    required this.open,
    required this.close,
    required this.isClosed,
  });

  /// 0 = Minggu .. 6 = Sabtu (sama dengan Postgres `extract(dow)`).
  final int weekday;
  final String open; // "HH:MM"
  final String close; // "HH:MM"
  final bool isClosed;

  static const names = [
    "Minggu",
    "Senin",
    "Selasa",
    "Rabu",
    "Kamis",
    "Jumat",
    "Sabtu",
  ];

  String get dayName => names[weekday.clamp(0, 6)];

  /// Menit sejak 00:00.
  static int minutes(String hhmm) {
    final p = hhmm.split(":");
    return int.parse(p[0]) * 60 + int.parse(p.length > 1 ? p[1] : "0");
  }

  bool get isValid => isClosed || minutes(close) > minutes(open);

  DayHours copyWith({String? open, String? close, bool? isClosed}) => DayHours(
        weekday: weekday,
        open: open ?? this.open,
        close: close ?? this.close,
        isClosed: isClosed ?? this.isClosed,
      );

  static String _hhmm(Object? v, String fallback) {
    final s = v?.toString() ?? "";
    return s.length >= 5 ? s.substring(0, 5) : fallback;
  }

  factory DayHours.fromJson(Map<String, dynamic> j) => DayHours(
        weekday: ((j["weekday"] ?? 0) as num).toInt(),
        open: _hhmm(j["open_time"], "08:00"),
        close: _hhmm(j["close_time"], "17:00"),
        isClosed: j["is_closed"] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        "weekday": weekday,
        "open_time": open,
        "close_time": close,
        "is_closed": isClosed,
      };
}

class Closure {
  const Closure({required this.date, this.reason, this.activeBookings = 0});
  final DateTime date;
  final String? reason;
  final int activeBookings;

  factory Closure.fromJson(Map<String, dynamic> j) => Closure(
        date: DateTime.parse(j["date"] as String),
        reason: j["reason"] as String?,
        activeBookings: ((j["active_bookings"] ?? 0) as num).toInt(),
      );
}

class OwnerSchedule {
  const OwnerSchedule({
    required this.isOpen,
    required this.hasHours,
    required this.hours,
    required this.slotMinutes,
    required this.capacity,
    required this.closures,
    this.tempClosedUntil,
    this.tempClosedReason,
  });

  final bool isOpen;
  final bool hasHours;
  final List<DayHours> hours; // selalu 7 hari, urut Minggu..Sabtu
  final int slotMinutes;
  final int capacity;
  final List<Closure> closures;
  final DateTime? tempClosedUntil;
  final String? tempClosedReason;

  bool get isTempClosed =>
      tempClosedUntil != null && tempClosedUntil!.isAfter(DateTime.now());

  /// Jumlah slot booking per hari untuk pratinjau.
  static int slotsPerDay(DayHours d, int slotMinutes) {
    if (d.isClosed || !d.isValid || slotMinutes <= 0) return 0;
    return (DayHours.minutes(d.close) - DayHours.minutes(d.open)) ~/
        slotMinutes;
  }

  factory OwnerSchedule.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(Object? v) => ((v as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final hours = list(j["hours"]).map(DayHours.fromJson).toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));
    final until = j["temp_closed_until"] as String?;
    return OwnerSchedule(
      isOpen: j["is_open"] as bool? ?? true,
      hasHours: j["has_hours"] as bool? ?? false,
      hours: hours.length == 7
          ? hours
          : List.generate(
              7,
              (i) => hours.firstWhere(
                (h) => h.weekday == i,
                orElse: () => DayHours(
                  weekday: i,
                  open: "08:00",
                  close: "17:00",
                  isClosed: false,
                ),
              ),
            ),
      slotMinutes: ((j["slot_minutes"] ?? 60) as num).toInt(),
      capacity: ((j["capacity_per_slot"] ?? 1) as num).toInt(),
      closures: list(j["closures"]).map(Closure.fromJson).toList(),
      tempClosedUntil: until == null ? null : DateTime.parse(until).toLocal(),
      tempClosedReason: j["temp_closed_reason"] as String?,
    );
  }
}

String scheduleErrorMessage(Object e) {
  if (e is PostgrestException) return e.message;
  return "Gagal menyimpan jadwal. Periksa koneksi lalu coba lagi.";
}

class OwnerScheduleRepository {
  SupabaseClient get _client => SupabaseService.client;

  Map<String, dynamic> _map(Object? res) =>
      (res as Map).cast<String, dynamic>();

  Future<OwnerSchedule> get() async {
    if (kDemoPreview) return DemoData.schedule;
    return OwnerSchedule.fromJson(
      _map(await _client.rpc("owner_schedule_get")),
    );
  }

  Future<OwnerSchedule> saveHours(
    List<DayHours> hours, {
    required int slotMinutes,
    required int capacity,
  }) async =>
      kDemoPreview
          ? DemoData.update(
              hours: hours,
              slotMinutes: slotMinutes,
              capacity: capacity,
            )
          : OwnerSchedule.fromJson(
              _map(
                await _client.rpc(
                  "owner_schedule_set_hours",
                  params: {
                    "p_hours": hours.map((h) => h.toJson()).toList(),
                    "p_slot_minutes": slotMinutes,
                    "p_capacity": capacity,
                  },
                ),
              ),
            );

  /// Mengembalikan jumlah booking aktif di tanggal tsb. (perlu dihubungi).
  Future<int> addClosure(DateTime date, String? reason) async {
    if (kDemoPreview) return 0;
    final res = _map(
      await _client.rpc(
        "owner_closure_add",
        params: {"p_date": _date(date), "p_reason": reason},
      ),
    );
    return ((res["active_bookings"] ?? 0) as num).toInt();
  }

  Future<void> removeClosure(DateTime date) =>
      _client.rpc("owner_closure_remove", params: {"p_date": _date(date)});

  Future<OwnerSchedule> setTempClosed(DateTime? until,
          {String? reason}) async =>
      kDemoPreview
          ? DemoData.update(
              tempClosedUntil: until,
              tempClosedReason: reason,
              clearTemp: until == null,
            )
          : OwnerSchedule.fromJson(
              _map(
                await _client.rpc(
                  "owner_set_temp_closed",
                  params: {
                    "p_until": until?.toUtc().toIso8601String(),
                    "p_reason": reason,
                  },
                ),
              ),
            );

  static String _date(DateTime d) =>
      "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
}
