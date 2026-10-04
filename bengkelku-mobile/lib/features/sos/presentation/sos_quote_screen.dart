// sosQuote — penawaran biaya perbaikan (PRD v1.3 Bagian 3.9 & 4).
//
// Pengendara meninjau penawaran bengkel lalu Setujui dan bayar atau Tolak.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design/components/app_button.dart';
import '../../quote/data/quote_models.dart';
import '../../quote/data/quote_repository.dart';
import '../../quote/presentation/quote_components.dart';

class SosQuoteScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String quoteId;

  const SosQuoteScreen({
    super.key,
    required this.requestId,
    required this.quoteId,
  });

  @override
  ConsumerState<SosQuoteScreen> createState() => _SosQuoteScreenState();
}

class _SosQuoteScreenState extends ConsumerState<SosQuoteScreen> {
  final _repo = QuoteRepository();
  Quote? _quote;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final quote = await _repo.getQuote(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat penawaran: $e';
        _loading = false;
      });
    }
  }

  Future<void> _approve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.approveQuote(widget.quoteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Penawaran disetujui. Lanjutkan pembayaran.'),
        ),
      );
      context.go('/sos/${widget.requestId}/tracking');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyetujui: $e')),
      );
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    const reasons = [
      'Harga terlalu tinggi',
      'Ingin mempertimbangkan dulu',
      'Tidak setuju dengan pekerjaan',
      'Lainnya',
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
                'Tolak penawaran?',
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

    setState(() => _busy = true);
    try {
      await _repo.rejectQuote(widget.quoteId, reason);
      if (!mounted) return;
      context.go('/sos/${widget.requestId}/tracking');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menolak: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Penawaran biaya'),
        elevation: 0,
        backgroundColor: c.panel,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.blue))
          : _quote == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error ?? 'Penawaran tidak ditemukan.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Bengkel mengajukan biaya perbaikan. '
                      'Setujui untuk melanjutkan, atau tolak bila tidak sesuai.',
                      style: AppTypography.body.copyWith(color: c.ink2),
                    ),
                    const SizedBox(height: 16),
                    QuoteCard(
                      quote: _quote!,
                      action: _quote!.canRespond
                          ? Column(
                              children: [
                                AppButton(
                                  label: 'Setujui dan bayar',
                                  loading: _busy,
                                  onPressed: _busy ? null : _approve,
                                ),
                                const SizedBox(height: 8),
                                AppButton(
                                  label: 'Tolak',
                                  variant: AppButtonVariant.secondary,
                                  onPressed: _busy ? null : _reject,
                                ),
                              ],
                            )
                          : null,
                    ),
                  ],
                ),
    );
  }
}
