// sosSearching — mencari bengkel (PRD v1.3 Bagian 3.3 & 3.9).
//
// Radar 3 cincin + WaveProgress (gelombang 1–3) + tombol Batalkan.
// Status permintaan diperbarui via Realtime; gelombang dispatch dilanjutkan
// berkala (PRD 3.4: klien boleh memanggil sos_dispatch_wave tiap 10 dtk).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/sos_components.dart';
import '../data/sos_models.dart';
import 'sos_provider.dart';

class SosSearchingScreen extends ConsumerStatefulWidget {
  final String requestId;

  const SosSearchingScreen({super.key, required this.requestId});

  @override
  ConsumerState<SosSearchingScreen> createState() => _SosSearchingScreenState();
}

class _SosSearchingScreenState extends ConsumerState<SosSearchingScreen> {
  SosRequest? _request;
  bool _loading = true;
  String? _error;
  bool _reduceMotion = false;
  bool _advancing = false;
  RealtimeChannel? _channel;
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reduceMotion = MediaQuery.of(context).disableAnimations;
    });
    _load();
    _subscribe();
    _waveTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _advanceWave(),
    );
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    final ch = _channel;
    if (ch != null) {
      ref.read(sosRepositoryProvider).unsubscribe(ch);
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final req =
          await ref.read(sosRepositoryProvider).getRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = req;
        _loading = false;
      });
      _routeFor(req);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat permintaan: $e';
        _loading = false;
      });
    }
  }

  void _subscribe() {
    _channel = ref.read(sosRepositoryProvider).subscribeToRequest(
      widget.requestId,
      (req) {
        if (!mounted) return;
        setState(() => _request = req);
        _routeFor(req);
      },
    );
  }

  Future<void> _advanceWave() async {
    final req = _request;
    if (_advancing || req == null || !mounted) return;
    if (req.status != SosStatus.MENCARI_BENGKEL) return;
    _advancing = true;
    await ref.read(sosRepositoryProvider).dispatchWave();
    await _load();
    _advancing = false;
  }

  void _routeFor(SosRequest req) {
    switch (req.status) {
      case SosStatus.DITERIMA:
      case SosStatus.MENUJU_LOKASI:
      case SosStatus.TIBA:
      case SosStatus.MEMERIKSA:
      case SosStatus.DIKERJAKAN:
        context.go('/sos/${req.id}/tracking');
        break;
      case SosStatus.SELESAI:
      case SosStatus.SELESAI_TANPA_PERBAIKAN:
        context.go('/sos/${req.id}/done');
        break;
      default:
        break;
    }
  }

  Future<void> _cancel() async {
    const reasons = [
      'Sudah ditangani orang lain',
      'Berubah pikiran',
      'Menunggu terlalu lama',
      'Salah membuat permintaan',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Batalkan panggilan?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            ...reasons.map(
              (r) => ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(sheetContext, r),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    try {
      final result = await ref
          .read(sosRepositoryProvider)
          .cancelRequest(requestId: widget.requestId, reason: reason);
      ref.read(activeSosProvider.notifier).clear();
      if (!mounted) return;

      final refund = (result['refund_amount'] as num?) ?? 0;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Panggilan dibatalkan'),
          content: Text(
            '${result['message']}. Refund ${Formatters.rupiah(refund)}'
            ' akan diproses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading || _request == null) {
      return Scaffold(
        backgroundColor: c.stage,
        appBar: AppBar(
          title: const Text('Mencari bengkel'),
          elevation: 0,
          backgroundColor: c.panel,
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : Center(child: CircularProgressIndicator(color: c.blue)),
      );
    }

    final req = _request!;
    final noShop = req.status == SosStatus.TIDAK_ADA_BENGKEL;

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: Text(noShop ? 'Tidak ada bengkel' : 'Mencari bengkel terdekat'),
        elevation: 0,
        backgroundColor: c.panel,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            RadarPulse(reduceMotion: _reduceMotion),
            const SizedBox(height: 28),
            if (noShop) ...[
              Text(
                'Belum ada bengkel yang menerima',
                style: AppTypography.h2.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Kamu mendapat refund penuh. Coba lagi beberapa saat nanti.',
                style: AppTypography.body.copyWith(color: c.ink2),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                'Menghubungi bengkel terdekat…',
                style: AppTypography.h2.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Kode: ${req.code}',
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
              const SizedBox(height: 20),
              WaveProgress(currentWave: req.wave),
            ],
            const Spacer(),
            AppButton(
              label: noShop ? 'Batalkan dan refund' : 'Batalkan pencarian',
              variant: AppButtonVariant.secondary,
              onPressed: _cancel,
            ),
          ],
        ),
      ),
    );
  }
}
