/// Logika pengingat oli — fungsi MURNI (tanpa I/O). Selalu update
/// test/oil_calculator_test.dart saat mengubah file ini.
///
/// Status oli dihitung dari sisa kilometer DAN sisa hari sampai target:
///   - late : sudah lewat (sisa km <= 0 ATAU sisa hari <= 0)
///   - soon : mendekati (sisa km <= 300 ATAU sisa hari <= 7)
///   - ok   : masih aman
library;

enum OilStage { ok, soon, late }

/// Ambang default (lihat PRD FR-O2).
const int kOilSoonKm = 300;
const int kOilSoonDays = 7;

/// Hitung tahap oli dari sisa km & sisa hari.
///
/// [remainingKm]  = targetKm - odometerSekarang
/// [remainingDays] = targetDate - hariIni (dalam hari)
OilStage oilStage({
  required int remainingKm,
  required int remainingDays,
  int soonKm = kOilSoonKm,
  int soonDays = kOilSoonDays,
}) {
  if (remainingKm <= 0 || remainingDays <= 0) return OilStage.late;
  if (remainingKm <= soonKm || remainingDays <= soonDays) return OilStage.soon;
  return OilStage.ok;
}

/// Target odometer ganti oli berikutnya.
int nextOilTargetKm({
  required int odometerAtService,
  required int intervalKm,
}) =>
    odometerAtService + intervalKm;

/// Target tanggal ganti oli berikutnya.
DateTime nextOilTargetDate({
  required DateTime serviceDate,
  required int intervalDays,
}) =>
    serviceDate.add(Duration(days: intervalDays));

/// Sisa km (bisa negatif bila sudah telat).
int remainingKm({required int targetKm, required int currentOdometer}) =>
    targetKm - currentOdometer;

/// Sisa hari (bisa negatif bila sudah telat).
int remainingDays({required DateTime targetDate, required DateTime now}) =>
    targetDate.difference(now).inDays;
