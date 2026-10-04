// sosDone — panggilan darurat selesai (PRD v1.3 Bagian 3.9).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/app_button.dart';
import '../data/sos_models.dart';
import 'sos_provider.dart';

class SosDoneScreen extends ConsumerStatefulWidget {
  final String requestId;

  const SosDoneScreen({super.key, required this.requestId});

  @override
  ConsumerState<SosDoneScreen> createState() => _SosDoneScreenState();
}

class _SosDoneScreenState extends ConsumerState<SosDoneScreen> {
  SosRequest? _request;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final req =
          await ref.read(sosRepositoryProvider).getRequest(widget.requestId);
      if (!mounted) return;
      // Alur selesai → bersihkan status aktif.
      ref.read(activeSosProvider.notifier).clear();
      setState(() {
        _request = req;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat ringkasan: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading || _request == null) {
      return Scaffold(
        backgroundColor: c.stage,
        appBar: AppBar(
          title: const Text('Selesai'),
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
    final withoutRepair = req.status == SosStatus.SELESAI_TANPA_PERBAIKAN;

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Selesai'),
        elevation: 0,
        backgroundColor: c.panel,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              withoutRepair ? Icons.task_alt : Icons.check_circle,
              size: 72,
              color: c.okC,
            ),
            const SizedBox(height: 16),
            Text(
              withoutRepair
                  ? 'Penawaran ditolak'
                  : 'Panggilan darurat selesai',
              style: AppTypography.h1.copyWith(color: c.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              withoutRepair
                  ? 'Mekanik tidak melanjutkan perbaikan. Biaya panggilan tetap berlaku.'
                  : 'Terima kasih sudah menggunakan BengkelKu. Semoga motormu kembali prima.',
              style: AppTypography.body.copyWith(color: c.ink2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.panel,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _row(context, 'Kode', req.code),
                  if ((req.workshopName ?? '').isNotEmpty)
                    _row(context, 'Bengkel', req.workshopName!),
                  _row(context, 'Biaya panggilan', Formatters.rupiah(req.total)),
                ],
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'Kembali ke beranda',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body.copyWith(color: c.ink2)),
          Text(value, style: AppTypography.label.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}
