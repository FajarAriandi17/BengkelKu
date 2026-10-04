// Laporanku — daftar tiket bantuan (PRD v1.3 Bagian 7).
// Status: DITERIMA, DITINJAU, MENUNGGU_INFO, SELESAI (dengan keputusan & alasan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/state_views.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';
import 'help_center_screen.dart';

final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(supportRepositoryProvider).getMyTickets(),
);

class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tickets = ref.watch(myTicketsProvider);

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Laporanku'),
        backgroundColor: c.panel,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/help/report'),
        icon: const Icon(Icons.add),
        label: const Text('Laporan baru'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myTicketsProvider.future),
          child: tickets.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(),
            ),
            error: (e, _) => ListView(
              children: [
                const SizedBox(height: 80),
                ErrorState(
                  message: SupportRepository.friendlyError(e),
                  onRetry: () => ref.invalidate(myTicketsProvider),
                ),
              ],
            ),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.confirmation_number_outlined,
                      title: 'belum ada laporan',
                      message: 'laporan yang kamu kirim akan muncul di sini.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => SupportTicketTile(ticket: list[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SupportTicketTile extends StatelessWidget {
  const SupportTicketTile({super.key, required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = ticket;
    return Material(
      color: c.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/help/tickets/${t.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.category.label,
                      style: AppTypography.bodyStrong.copyWith(color: c.ink),
                    ),
                  ),
                  SupportStateBadge(state: t.state),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(color: c.ink2),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  t.code,
                  if (t.relatedLabel != null) t.relatedLabel!,
                  Formatters.dateTimeLocal(t.createdAt),
                ].join(' · '),
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
