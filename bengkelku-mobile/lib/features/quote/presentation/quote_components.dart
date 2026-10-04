// Quote UI Components — sesuai PRD v1.3 Bagian 3.9 & 4 (QuoteCard, PriceRows).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../data/quote_models.dart';

/// PriceRows — daftar butir penawaran (jasa/sparepart + harga).
class PriceRows extends StatelessWidget {
  final List<QuoteItem> items;

  const PriceRows({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: items.map((item) {
        final isPart = item.type == QuoteItemType.sparepart;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(
                isPart ? Icons.settings_outlined : Icons.build_outlined,
                size: 16,
                color: c.ink2,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                    Text(
                      isPart ? 'Sparepart' : 'Jasa',
                      style: AppTypography.caption.copyWith(color: c.ink2),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.rupiah(item.price),
                style: AppTypography.label.copyWith(color: c.ink),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// QuoteCard — kartu penawaran biaya dari bengkel.
class QuoteCard extends StatelessWidget {
  final Quote quote;
  final Widget? action;

  const QuoteCard({super.key, required this.quote, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: c.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Penawaran ${quote.workshopName ?? 'Bengkel'}',
                  style: AppTypography.label.copyWith(color: c.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StateBadge(quote: quote),
            ],
          ),
          const SizedBox(height: 12),
          PriceRows(items: quote.items),
          if ((quote.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(quote.note!,
                style: AppTypography.body.copyWith(color: c.ink2)),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: c.line, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTypography.h2.copyWith(color: c.ink)),
              Text(
                Formatters.rupiah(quote.total),
                style: AppTypography.h2.copyWith(color: c.blueText),
              ),
            ],
          ),
          if (quote.canRespond) ...[
            const SizedBox(height: 6),
            Text(
              'Berlaku ${_remaining(quote.timeRemaining)} lagi',
              style: AppTypography.caption.copyWith(color: c.warnText),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }

  static String _remaining(Duration d) {
    if (d.inSeconds <= 0) return '00:00';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _StateBadge extends StatelessWidget {
  final Quote quote;

  const _StateBadge({required this.quote});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    late final String label;
    late final Color fg;
    late final Color bg;

    switch (quote.state) {
      case QuoteState.sent:
        label = 'Menunggu';
        fg = c.warnText;
        bg = c.warnSoft;
        break;
      case QuoteState.approved:
        label = 'Disetujui';
        fg = c.okText;
        bg = c.okSoft;
        break;
      case QuoteState.rejected:
        label = 'Ditolak';
        fg = c.badText;
        bg = c.badSoft;
        break;
      case QuoteState.expired:
        label = 'Kedaluwarsa';
        fg = c.ink2;
        bg = c.panel2;
        break;
      case QuoteState.superseded:
        label = 'Diganti';
        fg = c.ink2;
        bg = c.panel2;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.caption
            .copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
