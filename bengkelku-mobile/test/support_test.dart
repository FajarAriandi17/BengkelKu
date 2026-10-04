import 'package:bengkelku/core/theme/app_theme.dart';
import 'package:bengkelku/features/support/data/support_models.dart';
import 'package:bengkelku/features/support/presentation/help_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaqItem.parse (app_config.support_faq)', () {
    test('format {q, a} dan {title, body}', () {
      final items = FaqItem.parse([
        {'q': 'Berapa lama refund?', 'a': '1×24 jam kerja'},
        {'title': 'Bayar tunai?', 'body': 'Tidak di MVP'},
        {'q': '', 'a': 'kosong diabaikan'},
        'bukan map',
      ]);
      expect(items, hasLength(2));
      expect(items.first.question, 'Berapa lama refund?');
      expect(items.last.answer, 'Tidak di MVP');
    });
    test('bukan list → kosong', () {
      expect(FaqItem.parse(null), isEmpty);
      expect(FaqItem.parse({'q': 'x'}), isEmpty);
    });
    test('pencarian tidak peka huruf besar', () {
      const f = FaqItem(question: 'Berapa lama REFUND?', answer: 'cepat');
      expect(f.matches('refund'), isTrue);
      expect(f.matches('CEPAT'), isTrue);
      expect(f.matches('derek'), isFalse);
      expect(f.matches('  '), isTrue);
    });
  });

  group('validateSupportReport (PRD 7)', () {
    test('kategori wajib', () {
      expect(
        validateSupportReport(category: null, description: 'cukup panjang'),
        contains('kategori'),
      );
    });
    test('deskripsi 10–1000 karakter', () {
      expect(
        validateSupportReport(
          category: SupportCategory.LAINNYA,
          description: 'pendek',
        ),
        contains('minimal 10'),
      );
      expect(
        validateSupportReport(
          category: SupportCategory.LAINNYA,
          description: 'a' * 1001,
        ),
        contains('1.000'),
      );
      expect(
        validateSupportReport(
          category: SupportCategory.LAINNYA,
          description: 'mekanik tidak datang sama sekali',
        ),
        isNull,
      );
    });
    test('maksimal 3 foto', () {
      expect(
        validateSupportReport(
          category: SupportCategory.LAINNYA,
          description: 'mekanik tidak datang',
          photoCount: 4,
        ),
        contains('3 foto'),
      );
    });
  });

  test('kategori: label & penahanan payout', () {
    expect(SupportCategory.values, hasLength(6));
    expect(SupportCategory.HARGA_TIDAK_SESUAI.holdsPayout, isTrue);
    expect(SupportCategory.KERUSAKAN_SETELAH_SERVIS.holdsPayout, isTrue);
    expect(SupportCategory.REFUND_BELUM_MASUK.holdsPayout, isFalse);
    expect(SupportCategoryX.parse('XYZ'), SupportCategory.LAINNYA);
  });

  test('SupportTicket.fromJson + status', () {
    final t = SupportTicket.fromJson(const {
      'id': 't1',
      'code': 'TK-AB12CD',
      'category': 'BENGKEL_TIDAK_DATANG',
      'description': 'mekanik tidak datang',
      'photos': ['u/1.jpg'],
      'state': 'MENUNGGU_INFO',
      'sos_request_id': 'r1',
      'created_at': '2025-01-01T10:00:00Z',
      'updated_at': '2025-01-01T11:00:00Z',
    });
    expect(t.category, SupportCategory.BENGKEL_TIDAK_DATANG);
    expect(t.state, SupportState.MENUNGGU_INFO);
    expect(t.state.canReply, isTrue);
    expect(SupportState.SELESAI.canReply, isFalse);
    expect(t.relatedLabel, 'Panggilan darurat');
  });

  testWidgets('FaqList membuka jawaban & badge status (terang/gelap)',
      (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: theme,
          home: const Scaffold(
            body: Column(
              children: [
                SupportStateBadge(state: SupportState.DITINJAU),
                FaqList(
                  items: [
                    FaqItem(question: 'Berapa lama refund?', answer: '1×24'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Ditinjau'), findsOneWidget);
      expect(find.text('1×24'), findsNothing);
      await tester.tap(find.text('Berapa lama refund?'));
      await tester.pumpAndSettle();
      expect(find.text('1×24'), findsOneWidget);
    }
  });
}
