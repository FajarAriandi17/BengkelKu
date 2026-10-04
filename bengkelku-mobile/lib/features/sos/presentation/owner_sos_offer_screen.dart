// ownerSosOffer — tawaran darurat masuk (PRD v1.3 Bagian 3.3, 3.8, 3.9, 3.10).
//
// Layar penuh: jarak, ETA, masalah, foto, pendapatan bersih, hitung mundur 60
// detik (cincin menyusut linear, merah pada 10 detik terakhir), Terima / Lewati.
// Lokasi hanya area umum (dibulatkan ±300 m) sampai bengkel menang.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/state_views.dart';
import '../data/owner_sos_models.dart';
import '../data/owner_sos_repository.dart';
import '../domain/owner_sos_logic.dart';
import 'owner_sos_controller.dart';

class OwnerSosOfferScreen extends ConsumerStatefulWidget {
  const OwnerSosOfferScreen({super.key, required this.offerId});

  final String offerId;

  @override
  ConsumerState<OwnerSosOfferScreen> createState() =>
      _OwnerSosOfferScreenState();
}

class _OwnerSosOfferScreenState extends ConsumerState<OwnerSosOfferScreen> {
  SosOfferDetails? _d;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  String? _closedReason;
  Timer? _tick;
  DateTime _now = DateTime.now();
  bool _hapticUrgent = false;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      final d = _d;
      if (d == null || _closedReason != null) return;
      final cd = OfferCountdown(sentAt: d.sentAt, expiresAt: d.expiresAt);
      if (cd.isUrgent(_now) && !_hapticUrgent) {
        _hapticUrgent = true;
        HapticFeedback.mediumImpact();
      }
      if (cd.isExpired(_now)) {
        setState(() => _closedReason = 'waktu tawaran habis');
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await ref
          .read(ownerSosRepositoryProvider)
          .getOfferDetails(widget.offerId);
      if (!mounted) return;
      unawaited(HapticFeedback.heavyImpact());
      unawaited(SystemSound.play(SystemSoundType.alert));
      setState(() {
        _d = d;
        _loading = false;
        if (!d.isOpen) {
          _closedReason = d.state == 'skipped'
              ? 'kamu sudah melewatkan tawaran ini'
              : 'panggilan sudah diambil atau tidak aktif lagi';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = OwnerSosRepository.friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final requestId = await ref
          .read(ownerSosRepositoryProvider)
          .acceptOffer(widget.offerId);
      await ref.read(ownerSosControllerProvider.notifier).refreshOffersAndJob();
      if (!mounted) return;
      unawaited(HapticFeedback.lightImpact());
      context.pushReplacement('/owner/sos/$requestId/route');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _closedReason = OwnerSosRepository.friendlyError(e);
      });
    }
  }

  Future<void> _skip() async {
    setState(() => _busy = true);
    try {
      await ref.read(ownerSosRepositoryProvider).skipOffer(widget.offerId);
    } catch (_) {
      // Tawaran mungkin sudah kedaluwarsa; tetap tutup layar.
    }
    await ref.read(ownerSosControllerProvider.notifier).refreshOffersAndJob();
    if (mounted) _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/owner/standby');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading) {
      return Scaffold(
        backgroundColor: c.stage,
        body: Center(child: CircularProgressIndicator(color: c.blue)),
      );
    }
    if (_d == null) {
      return Scaffold(
        backgroundColor: c.stage,
        appBar: AppBar(title: const Text('Tawaran darurat')),
        body: ErrorState(
          message: _error ?? 'tawaran tidak ditemukan',
          onRetry: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _load();
          },
        ),
      );
    }

    final d = _d!;
    final cd = OfferCountdown(sentAt: d.sentAt, expiresAt: d.expiresAt);
    final urgent = cd.isUrgent(_now);
    final closed = _closedReason != null;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: c.stage,
        body: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration:
                Motion.respect(context, const Duration(milliseconds: 350)),
            curve: Motion.respectCurve(context, Motion.easeOut),
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * 60),
                child: child,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Tutup',
                        icon: const Icon(Icons.close),
                        onPressed: _busy ? null : (closed ? _close : _skip),
                      ),
                      const Spacer(),
                      Text(
                        'Panggilan darurat · ${d.requestCode}',
                        style: AppTypography.label.copyWith(color: c.ink2),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      Center(
                        child: CountdownRing(
                          fraction: closed ? 0 : cd.fraction(_now),
                          seconds: closed ? 0 : cd.secondsLeft(_now),
                          urgent: urgent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          d.problemLabel,
                          style: AppTypography.display.copyWith(color: c.ink),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          '${Formatters.distance(d.distanceM.toDouble())} · tiba ±${d.etaMin} menit',
                          style:
                              AppTypography.bodyStrong.copyWith(color: c.ink2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(child: EarningsPill(amount: d.netEarnings)),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'biaya panggilan ${Formatters.rupiah(d.callFee)}'
                          '${d.nightFee > 0 ? ' + malam ${Formatters.rupiah(d.nightFee)}' : ''}'
                          ' − komisi ${(d.commissionRate * 100).round()}%',
                          style: AppTypography.caption.copyWith(color: c.ink2),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if ((d.problemNote ?? '').trim().isNotEmpty)
                        _InfoTile(
                          icon: Icons.notes_outlined,
                          title: 'Catatan pengendara',
                          body: d.problemNote!.trim(),
                        ),
                      _InfoTile(
                        icon: Icons.place_outlined,
                        title: 'Area umum',
                        body:
                            '${d.areaLat.toStringAsFixed(3)}, ${d.areaLng.toStringAsFixed(3)} (±300 m). '
                            'lokasi tepat terbuka setelah kamu menerima.',
                      ),
                      if (d.photos.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: d.photos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                d.photos[i],
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                semanticLabel: 'foto masalah ${i + 1}',
                                errorBuilder: (_, __, ___) => Container(
                                  width: 84,
                                  height: 84,
                                  color: c.panel2,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: c.ink2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (closed) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.badSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _closedReason!,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyStrong
                                .copyWith(color: c.badText),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: closed
                      ? AppButton(label: 'Tutup', onPressed: _close)
                      : Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Lewati',
                                variant: AppButtonVariant.secondary,
                                onPressed: _busy ? null : _skip,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _PulsingAccept(
                                child: AppButton(
                                  label: 'Terima',
                                  icon: Icons.check_circle_outline,
                                  loading: _busy,
                                  onPressed: _busy ? null : _accept,
                                  semanticLabel: 'Terima panggilan darurat',
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// OfferCountdown — cincin hitung mundur.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.fraction,
    required this.seconds,
    required this.urgent,
  });

  final double fraction;
  final int seconds;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = urgent ? c.badC : c.blue;
    return Semantics(
      label: 'sisa $seconds detik',
      child: SizedBox(
        width: 148,
        height: 148,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 10,
                backgroundColor: c.line,
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$seconds',
                  style: AppTypography.display.copyWith(
                    fontSize: 44,
                    color: urgent ? c.badText : c.ink,
                  ),
                ),
                Text(
                  'detik',
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

/// EarningsPill — pendapatan bersih.
class EarningsPill extends StatelessWidget {
  const EarningsPill({super.key, required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: c.okSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'Pendapatan bersih ${Formatters.rupiah(amount)}',
        style: AppTypography.h2.copyWith(color: c.okText, fontSize: 16),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.ink2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.label.copyWith(color: c.ink)),
                const SizedBox(height: 2),
                Text(body, style: AppTypography.body.copyWith(color: c.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol Terima berdenyut halus (dimatikan saat Reduce Motion).
class _PulsingAccept extends StatefulWidget {
  const _PulsingAccept({required this.child});
  final Widget child;

  @override
  State<_PulsingAccept> createState() => _PulsingAcceptState();
}

class _PulsingAcceptState extends State<_PulsingAccept>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.scale(
        scale: 1 + 0.03 * Curves.easeInOut.transform(_c.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}
