import 'package:bengkelku/features/quote/data/quote_models.dart';
import 'package:bengkelku/features/sos/data/owner_sos_models.dart';
import 'package:bengkelku/features/sos/domain/owner_sos_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfferCountdown (60 detik)', () {
    final sent = DateTime.utc(2025, 1, 1, 10);
    final cd = OfferCountdown(
      sentAt: sent,
      expiresAt: sent.add(const Duration(seconds: 60)),
    );

    test('penuh saat dikirim', () {
      expect(cd.fraction(sent), 1.0);
      expect(cd.secondsLeft(sent), 60);
      expect(cd.isUrgent(sent), isFalse);
    });

    test('menyusut linear', () {
      final t = sent.add(const Duration(seconds: 30));
      expect(cd.fraction(t), closeTo(0.5, 0.0001));
      expect(cd.secondsLeft(t), 30);
    });

    test('merah pada 10 detik terakhir', () {
      expect(cd.isUrgent(sent.add(const Duration(seconds: 49))), isFalse);
      expect(cd.isUrgent(sent.add(const Duration(seconds: 50))), isTrue);
      expect(cd.isUrgent(sent.add(const Duration(seconds: 59))), isTrue);
    });

    test('detik dibulatkan ke atas', () {
      expect(cd.secondsLeft(sent.add(const Duration(milliseconds: 800))), 60);
      expect(cd.secondsLeft(sent.add(const Duration(milliseconds: 59100))), 1);
    });

    test('habis tidak negatif', () {
      final late = sent.add(const Duration(seconds: 75));
      expect(cd.isExpired(late), isTrue);
      expect(cd.fraction(late), 0);
      expect(cd.secondsLeft(late), 0);
      expect(cd.isUrgent(late), isFalse);
    });
  });

  group('netEarnings', () {
    test('contoh PRD 3.5: (25.000 + 185.000) − 8% = 193.200', () {
      expect(
        netEarnings(
          callFee: 25000,
          nightFee: 0,
          commissionRate: 0.08,
          quoteTotal: 185000,
        ),
        193200,
      );
    });
    test('biaya panggilan + malam', () {
      expect(
        netEarnings(callFee: 25000, nightFee: 10000, commissionRate: 0.08),
        32200,
      );
    });
  });

  test('kode kedatangan 4 digit', () {
    expect(isValidArrivalCode('0427'), isTrue);
    expect(isValidArrivalCode('427'), isFalse);
    expect(isValidArrivalCode('42a7'), isFalse);
    expect(isValidArrivalCode('04271'), isFalse);
  });

  test('tautan navigasi Google Maps & Waze', () {
    final g = NavigationLinks.googleMaps(-6.2, 106.8);
    expect(g.host, 'www.google.com');
    expect(g.queryParameters['destination'], '-6.200000,106.800000');
    final w = NavigationLinks.waze(-6.2, 106.8);
    expect(w.queryParameters['ll'], '-6.200000,106.800000');
    expect(w.queryParameters['navigate'], 'yes');
  });

  group('validateQuoteDraft (PRD 4.1)', () {
    QuoteDraftItem it(
      String n,
      int p, [
      QuoteItemType t = QuoteItemType.jasa,
    ]) =>
        QuoteDraftItem(name: n, price: p, type: t);

    test('valid', () {
      expect(validateQuoteDraft([it('Tambal ban', 20000)]), isNull);
    });
    test('minimal 1 butir', () {
      expect(validateQuoteDraft([]), contains('minimal 1'));
    });
    test('maksimal 10 butir', () {
      final items = List.generate(11, (i) => it('b$i', 1000));
      expect(validateQuoteDraft(items), contains('Maksimal 10'));
    });
    test('nama & harga wajib', () {
      expect(validateQuoteDraft([it('', 1000)]), contains('Nama butir 1'));
      expect(validateQuoteDraft([it('Busi', 0)]), contains('Harga butir 1'));
    });
    test('total maks Rp 2.000.000', () {
      expect(
        validateQuoteDraft([
          it('Mesin', 1500000, QuoteItemType.sparepart),
          it('Jasa', 600000),
        ]),
        contains('Rp 2.000.000'),
      );
      expect(validateQuoteDraft([it('Mesin', 2000000)]), isNull);
    });
    test('maksimal 3 foto', () {
      expect(
        validateQuoteDraft([it('a', 1)], photoCount: 4),
        contains('3 foto'),
      );
    });
    test('total & parse rupiah', () {
      expect(quoteDraftTotal([it('a', 20000), it('b', 45000)]), 65000);
      expect(parseRupiahInput('Rp 185.000'), 185000);
      expect(parseRupiahInput(''), 0);
    });
  });

  test('SosTier.parse dari app_config', () {
    final tiers = SosTier.parse([
      {'tier': 2, 'max_km': 6, 'fee': 40000},
      {'tier': 1, 'max_km': 3, 'fee': 25000},
    ]);
    expect(tiers.map((t) => t.tier), [1, 2]);
    expect(SosTier.parse(null), SosTier.defaults);
  });

  test('SosOfferDetails.fromJson tanpa lokasi tepat', () {
    final d = SosOfferDetails.fromJson(const {
      'offer_id': 'o1',
      'request_id': 'r1',
      'request_code': 'ABC123',
      'request_status': 'MENCARI_BENGKEL',
      'state': 'sent',
      'wave': 1,
      'distance_m': 2400,
      'eta_min': 6,
      'sent_at': '2025-01-01T10:00:00Z',
      'expires_at': '2025-01-01T10:01:00Z',
      'problem_code': 'FLAT_TIRE',
      'photos': ['https://x/1.jpg'],
      'area_lat': -6.201,
      'area_lng': 106.8,
      'call_fee': 25000,
      'night_fee': 0,
      'commission_rate': 0.08,
      'net_earnings': 23000,
    });
    expect(d.problemLabel, 'Ban bocor');
    expect(d.isOpen, isTrue);
    expect(d.netEarnings, 23000);
    expect(d.photos, hasLength(1));
  });
}
