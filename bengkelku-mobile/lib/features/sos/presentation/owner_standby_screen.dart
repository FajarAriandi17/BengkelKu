// ownerStandby — pengaturan siaga darurat (PRD v1.3 Bagian 3.3 & 3.9).
// AppSwitch siaga, radius (tier), siaga di luar jam buka, tawaran aktif.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/state_views.dart';
import '../data/sos_models.dart';
import 'owner_sos_controller.dart';

class OwnerStandbyScreen extends ConsumerWidget {
  const OwnerStandbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(ownerSosControllerProvider);
    final ctrl = ref.read(ownerSosControllerProvider.notifier);

    ref.listen(ownerSosControllerProvider.select((v) => v.error), (prev, next) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), backgroundColor: c.bad),
        );
      }
    });

    Widget body;
    if (s.loading && s.workshop == null) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonList(itemCount: 3),
      );
    } else if (s.workshop == null) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: 'kamu belum punya bengkel',
        message: 'daftarkan bengkel dulu untuk menerima panggilan darurat.',
        actionLabel: 'Daftarkan bengkel',
        onAction: () => context.push('/owner/register'),
      );
    } else {
      final ws = s.workshop!;
      final canEnable = ws.isVerified && ws.hasLocation;
      body = RefreshIndicator(
        onRefresh: ctrl.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(state: s),
            const SizedBox(height: 16),
            if (!ws.isVerified)
              const _Notice(
                icon: Icons.verified_outlined,
                text:
                    'siaga darurat hanya untuk bengkel yang sudah disetujui. status bengkelmu masih dalam peninjauan.',
              )
            else if (!ws.hasLocation)
              const _Notice(
                icon: Icons.location_off_outlined,
                text:
                    'lengkapi lokasi bengkel dulu sebelum mengaktifkan siaga.',
              ),
            if (s.locationWarning != null && s.isReady)
              _Notice(icon: Icons.gps_off, text: s.locationWarning!),
            if (s.activeJob != null) ...[
              _ActiveJobCard(job: s.activeJob!),
              const SizedBox(height: 16),
            ],
            _Section(
              children: [
                SwitchListTile.adaptive(
                  value: s.isReady,
                  onChanged: s.saving || (!canEnable && !s.isReady)
                      ? null
                      : (v) => ctrl.updateSettings(ready: v),
                  title: Text(
                    'Siaga darurat',
                    style: AppTypography.bodyStrong.copyWith(color: c.ink),
                  ),
                  subtitle: Text(
                    'terima panggilan motor mogok di sekitar bengkel',
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                ),
                Divider(height: 1, color: c.line),
                SwitchListTile.adaptive(
                  value: s.afterHours,
                  onChanged: s.saving || !canEnable
                      ? null
                      : (v) => ctrl.updateSettings(afterHours: v),
                  title: Text(
                    'Siaga di luar jam buka',
                    style: AppTypography.bodyStrong.copyWith(color: c.ink),
                  ),
                  subtitle: Text(
                    'tanpa ini, panggilan hanya masuk saat bengkel buka',
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Radius panggilan',
              style: AppTypography.label.copyWith(color: c.ink2),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: s.radiusTierMax,
              onChanged: (v) {
                if (s.saving || !canEnable || v == null) return;
                ctrl.updateSettings(radiusTierMax: v);
              },
              child: _Section(
                children: [
                  for (final t in s.tiers)
                    RadioListTile<int>(
                      value: t.tier,
                      enabled: !s.saving && canEnable,
                      title: Text(
                        'sampai ${t.maxKm} km',
                        style: AppTypography.bodyStrong.copyWith(color: c.ink),
                      ),
                      subtitle: Text(
                        'biaya panggilan ${Formatters.rupiah(t.fee)}',
                        style: AppTypography.caption.copyWith(color: c.ink2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'pendapatan bersih = biaya panggilan (+ biaya malam) dikurangi komisi 8%. '
              'perbaikan di tempat ditawarkan lewat penawaran biaya.',
              style: AppTypography.caption.copyWith(color: c.ink2),
            ),
            const SizedBox(height: 8),
            Text(
              'siaga aktif selama aplikasi terbuka. biarkan aplikasi tetap terbuka saat siaga.',
              style: AppTypography.caption.copyWith(color: c.ink2),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Siaga darurat'),
        backgroundColor: c.panel,
        elevation: 0,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final OwnerSosState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = state.isReady;
    final rate = state.standby?.acceptRate ?? 1.0;
    final hb = state.lastHeartbeat;

    return Semantics(
      label: ready ? 'siaga aktif' : 'siaga nonaktif',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ready ? c.okSoft : c.panel,
          border: Border.all(color: ready ? c.ok : c.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ready ? c.ok : c.panel2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                ready ? Icons.sensors : Icons.sensors_off,
                color: ready ? Colors.white : c.ink2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'kamu sedang siaga' : 'siaga nonaktif',
                    style: AppTypography.h2
                        .copyWith(color: ready ? c.okText : c.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready
                        ? (hb != null
                            ? 'lokasi diperbarui ${Formatters.timeOnly(hb.toUtc())}'
                            : 'memperbarui lokasi…')
                        : 'aktifkan untuk menerima panggilan darurat',
                    style: AppTypography.caption.copyWith(color: c.ink2),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(rate * 100).round()}%',
                  style: AppTypography.h2
                      .copyWith(color: rate < 0.7 ? c.warnText : c.ink),
                ),
                Text(
                  'penerimaan',
                  style: AppTypography.caption.copyWith(color: c.ink2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job});
  final SosRequest job;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panggilan berjalan · ${job.code}',
            style: AppTypography.bodyStrong.copyWith(color: c.warnText),
          ),
          const SizedBox(height: 4),
          Text(
            'tawaran baru ditahan sampai panggilan ini selesai.',
            style: AppTypography.caption.copyWith(color: c.ink2),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Buka panggilan',
            icon: Icons.navigation_outlined,
            onPressed: () => context.push('/owner/sos/${job.id}/route'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

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
        child: Column(children: children),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.warnSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.warnText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(color: c.warnText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkas siaga darurat untuk dasbor bengkel (ownerDash).
class OwnerStandbyTile extends ConsumerWidget {
  const OwnerStandbyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(ownerSosControllerProvider);
    final ready = s.isReady;
    final job = s.activeJob;
    final offers = s.openOffers.length;

    final subtitle = job != null
        ? 'panggilan berjalan · ${job.code}'
        : ready
            ? (offers > 0
                ? '$offers tawaran menunggu jawaban'
                : 'menunggu panggilan di sekitar bengkel')
            : 'aktifkan untuk menerima panggilan motor mogok';

    return Semantics(
      button: true,
      label: 'siaga darurat, ${ready ? 'aktif' : 'nonaktif'}',
      child: Material(
        color: ready ? c.okSoft : c.panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (job != null) {
              context.push('/owner/sos/${job.id}/route');
            } else if (offers > 0) {
              context.push('/owner/sos/offer/${s.openOffers.first.id}');
            } else {
              context.push('/owner/standby');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  ready ? Icons.sensors : Icons.sensors_off,
                  color: ready ? c.ok : c.ink2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Siaga darurat',
                        style: AppTypography.bodyStrong.copyWith(color: c.ink),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(color: c.ink2),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
