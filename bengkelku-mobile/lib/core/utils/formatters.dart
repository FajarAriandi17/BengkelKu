import "package:intl/intl.dart";

/// Format umum BengkelKu: Rupiah, tanggal/jam (UTC disimpan, ditampilkan per zona).
class Formatters {
  Formatters._();

  static final NumberFormat _rupiah = NumberFormat.currency(
    locale: "id_ID",
    symbol: "Rp ",
    decimalDigits: 0,
  );

  /// Rp 55.000
  static String rupiah(num amount) => _rupiah.format(amount);

  /// Jarak: "850 m" atau "2,3 km".
  static String distance(double meters) {
    if (meters < 1000) return "${meters.round()} m";
    final km = meters / 1000;
    return "${NumberFormat("#,##0.0", "id_ID").format(km)} km";
  }

  /// Tampilkan waktu UTC di zona lokal bengkel.
  /// [utc] disimpan UTC; [location] mis. "Asia/Jakarta" (ditangani di layer tz bila perlu).
  static String dateTimeLocal(DateTime utc) {
    final local = utc.toLocal();
    return DateFormat("EEE, d MMM yyyy • HH:mm", "id_ID").format(local);
  }

  static String dateOnly(DateTime utc) =>
      DateFormat("d MMM yyyy", "id_ID").format(utc.toLocal());

  static String timeOnly(DateTime utc) =>
      DateFormat("HH:mm", "id_ID").format(utc.toLocal());

  /// Odometer: "12.500 km".
  static String odometer(int km) =>
      "${NumberFormat("#,##0", "id_ID").format(km)} km";
}
