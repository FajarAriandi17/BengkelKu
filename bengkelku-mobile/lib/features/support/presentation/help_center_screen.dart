// Pusat Bantuan — FAQ + titik masuk laporan & daftar tiket (PRD v1.3 Bagian 7).
// Titik masuk: Profil > Bantuan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/state_views.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';

final supportFaqProvider = FutureProvider.autoDispose<List<FaqItem>>(
  (ref) => ref.watch(supportRepositoryProvider).getFaq(),
);

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final faq = ref.watch(supportFaqProvider);

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Bantuan'),
        backgroundColor: c.panel,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/help/tickets'),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: const Text('Laporanku'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(supportFaqProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReportCard(onTap: () => context.push('/help/report')),
              const SizedBox(height: 20),
              Text(
                'Pertanyaan umum',
                style: AppTypography.h2.copyWith(color: c.ink),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'cari pertanyaan',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: c.panel,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.line),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              faq.when(
                loading: () => const SkeletonList(),
                error: (e, _) => ErrorState(
                  message: SupportRepository.friendlyError(e),
                  onRetry: () => ref.invalidate(supportFaqProvider),
                ),
                data: (items) {
                  final list = items.where((f) => f.matches(_query)).toList();
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.help_outline,
                      title: items.isEmpty
                          ? 'belum ada artikel bantuan'
                          : 'tidak ada yang cocok',
                      message: 'kamu tetap bisa mengirim laporan ke tim kami.',
                    );
                  }
                  return FaqList(items: list);
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.badSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_hospital_outlined, color: c.badText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'kecelakaan atau luka? BengkelKu bukan layanan medis. telepon 112.',
                        style: AppTypography.body.copyWith(color: c.badText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daftar FAQ yang bisa dibuka-tutup.
class FaqList extends StatelessWidget {
  const FaqList({super.key, required this.items});
  final List<FaqItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.line),
              ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  items[i].question,
                  style: AppTypography.bodyStrong.copyWith(color: c.ink),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items[i].answer,
                    style: AppTypography.body.copyWith(color: c.ink2),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.blueSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: c.blueText, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ada masalah?',
                  style: AppTypography.h2.copyWith(color: c.blueText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'laporkan ke tim kami. balasan pertama paling lambat 1×24 jam kerja.',
            style: AppTypography.body.copyWith(color: c.ink),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Laporkan masalah',
            icon: Icons.flag_outlined,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Lencana status tiket.
class SupportStateBadge extends StatelessWidget {
  const SupportStateBadge({super.key, required this.state});
  final SupportState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (state) {
      SupportState.DITERIMA => (c.blueSoft, c.blueText),
      SupportState.DITINJAU => (c.warnSoft, c.warnText),
      SupportState.MENUNGGU_INFO => (c.badSoft, c.badText),
      SupportState.SELESAI => (c.okSoft, c.okText),
    };
    return Semantics(
      label: 'status ${state.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(
          state.label,
          style: AppTypography.caption.copyWith(color: fg),
        ),
      ),
    );
  }
}
