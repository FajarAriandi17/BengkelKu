// Logika murni sisi bengkel Bantuan Darurat (PRD v1.3 Bagian 3.3, 3.4, 3.9, 4.1).
// Tanpa dependensi Flutter/Supabase agar mudah diuji (test/owner_sos_logic_test.dart).

import '../../quote/data/quote_models.dart';

/// Hitung mundur tawaran (ownerSosOffer). Default 60 detik (`sos_offer_seconds`).
class OfferCountdown {
  const OfferCountdown({
    required this.sentAt,
    required this.expiresAt,
  });

  final DateTime sentAt;
  final DateTime expiresAt;

  /// Ambang "merah" pada 10 detik terakhir (PRD 3.10).
  static const urgentThreshold = Duration(seconds: 10);

  Duration get total {
    final d = expiresAt.difference(sentAt);
    return d.isNegative || d == Duration.zero ? const Duration(seconds: 60) : d;
  }

  Duration remaining(DateTime now) {
    final d = expiresAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// 1.0 = penuh, 0.0 = habis. Untuk cincin yang menyusut linear.
  double fraction(DateTime now) {
    final t = total.inMilliseconds;
    if (t <= 0) return 0;
    return (remaining(now).inMilliseconds / t).clamp(0.0, 1.0);
  }

  bool isUrgent(DateTime now) =>
      !isExpired(now) && remaining(now) <= urgentThreshold;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Detik tersisa, dibulatkan ke atas (59,2 dtk → "60").
  int secondsLeft(DateTime now) =>
      (remaining(now).inMilliseconds / 1000).ceil();
}

/// Pendapatan bersih bengkel = (biaya panggilan + biaya malam [+ penawaran]) − komisi.
/// Sama dengan `sos_offer_details.net_earnings` di server.
int netEarnings({
  required int callFee,
  required int nightFee,
  required double commissionRate,
  int quoteTotal = 0,
}) {
  final gross = callFee + nightFee + quoteTotal;
  return (gross * (1 - commissionRate)).round();
}

/// Kode kedatangan: tepat 4 digit angka.
bool isValidArrivalCode(String input) => RegExp(r'^\d{4}$').hasMatch(input);

/// Tautan navigasi eksternal (ownerSosRoute).
class NavigationLinks {
  NavigationLinks._();

  static Uri googleMaps(double lat, double lng) => Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}'
        '&travelmode=two-wheeler',
      );

  static Uri waze(double lat, double lng) => Uri.parse(
        'https://waze.com/ul?ll=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}'
        '&navigate=yes',
      );
}

/// Satu baris pada formulir penawaran (ownerQuoteForm).
class QuoteDraftItem {
  QuoteDraftItem({
    this.name = '',
    this.type = QuoteItemType.jasa,
    this.price = 0,
  });

  String name;
  QuoteItemType type;
  int price;

  bool get isComplete => name.trim().isNotEmpty && price > 0;

  QuoteItem toItem() => QuoteItem(name: name.trim(), type: type, price: price);
}

/// Batas penawaran dari `app_config` (nilai bawaan PRD 4.1).
class QuoteLimits {
  const QuoteLimits({
    this.minItems = 1,
    this.maxItems = 10,
    this.maxTotal = 2000000,
    this.maxPhotos = 3,
  });

  final int minItems;
  final int maxItems;
  final int maxTotal;
  final int maxPhotos;
}

/// Validasi formulir penawaran. Mengembalikan pesan galat pertama
/// (Bahasa Indonesia) atau null bila siap dikirim. Server tetap memvalidasi.
String? validateQuoteDraft(
  List<QuoteDraftItem> items, {
  QuoteLimits limits = const QuoteLimits(),
  int photoCount = 0,
}) {
  if (items.length < limits.minItems) {
    return 'Tambahkan minimal ${limits.minItems} butir penawaran';
  }
  if (items.length > limits.maxItems) {
    return 'Maksimal ${limits.maxItems} butir penawaran';
  }
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    if (it.name.trim().isEmpty) return 'Nama butir ${i + 1} belum diisi';
    if (it.price <= 0) return 'Harga butir ${i + 1} harus lebih dari 0';
  }
  final total = quoteDraftTotal(items);
  if (total > limits.maxTotal) {
    return 'Total melebihi batas ${_rp(limits.maxTotal)} — selesaikan sebagai booking biasa';
  }
  if (photoCount > limits.maxPhotos) {
    return 'Maksimal ${limits.maxPhotos} foto bukti';
  }
  return null;
}

int quoteDraftTotal(List<QuoteDraftItem> items) =>
    items.fold(0, (sum, it) => sum + (it.price > 0 ? it.price : 0));

/// Ubah teks "Rp 185.000" / "185000" / "185.000" menjadi 185000.
int parseRupiahInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

String _rp(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

/// Tier radius siaga dari `app_config.sos_tiers`.
class SosTier {
  const SosTier({required this.tier, required this.maxKm, required this.fee});

  final int tier;
  final int maxKm;
  final int fee;

  static List<SosTier> parse(Object? raw) {
    if (raw is! List) return defaults;
    final list = <SosTier>[];
    for (final e in raw) {
      if (e is Map) {
        final t = (e['tier'] as num?)?.toInt();
        final km = (e['max_km'] as num?)?.toInt();
        final fee = (e['fee'] as num?)?.toInt() ?? 0;
        if (t != null && km != null) {
          list.add(SosTier(tier: t, maxKm: km, fee: fee));
        }
      }
    }
    list.sort((a, b) => a.tier.compareTo(b.tier));
    return list.isEmpty ? defaults : list;
  }

  static const defaults = [
    SosTier(tier: 1, maxKm: 3, fee: 25000),
    SosTier(tier: 2, maxKm: 6, fee: 40000),
    SosTier(tier: 3, maxKm: 10, fee: 55000),
    SosTier(tier: 4, maxKm: 15, fee: 75000),
  ];
}
