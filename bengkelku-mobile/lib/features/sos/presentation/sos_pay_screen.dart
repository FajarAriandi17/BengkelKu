// sosPay — Pembayaran biaya panggilan darurat (PRD v1.3 Bagian 3.5)
//
// Batas bayar 10 menit (sos_payment_minutes). Setelah bayar, status
// berpindah ke MENCARI_BENGKEL dan gelombang dispatch dimulai.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design/components/app_button.dart';
import '../data/sos_models.dart';
import 'sos_provider.dart';

class SosPayScreen extends ConsumerStatefulWidget {
  final String requestId;

  const SosPayScreen({super.key, required this.requestId});

  @override
  ConsumerState<SosPayScreen> createState() => _SosPayScreenState();
}

class _SosPayScreenState extends ConsumerState<SosPayScreen> {
  String _method = 'qris';
  Timer? _timer;
  int _secondsLeft = 600;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        _onExpired();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _onExpired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Waktu pembayaran habis. Permintaan dibatalkan.')),
    );
    ref.read(activeSosProvider.notifier).clear();
    context.go('/home');
  }

  String get _timeLeft {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _simulatePay() async {
    setState(() => _paying = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(sosRepositoryProvider);

    try {
      // Simulasi gateway: di produksi buat payment lalu tunggu webhook.
      // Di MVP klien, tandai lunas → status MENCARI_BENGKEL (sos_mark_paid).
      await Future.delayed(const Duration(seconds: 1));
      await repo.markPaid(widget.requestId);
      await ref.read(activeSosProvider.notifier).loadActive();
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal memproses pembayaran: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _paying = false);
    _timer?.cancel();

    // Lanjut ke layar pencarian bengkel (gelombang dispatch aktif).
    context.go('/sos/${widget.requestId}/searching');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final asyncReq = ref.watch(activeSosProvider);
    final request = asyncReq.valueOrNull;

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Bayar biaya panggilan'),
        elevation: 0,
        backgroundColor: c.panel,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.warnSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: c.warnText, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selesaikan pembayaran dalam $_timeLeft',
                      style: TextStyle(
                        color: c.warnText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (request != null) ...[
              _SummaryCard(request: request),
              const SizedBox(height: 20),
            ],
            Text(
              'Pilih metode pembayaran',
              style: TextStyle(
                color: c.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _MethodTile(
              value: 'qris',
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: 'QRIS (BCA, Mandiri, GoPay, OVO, ShopeePay)',
              icon: Icons.qr_code_2,
            ),
            const SizedBox(height: 8),
            _MethodTile(
              value: 'ewallet',
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: 'E-Wallet (GoPay / OVO / Dana)',
              icon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 8),
            _MethodTile(
              value: 'va',
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
              title: 'Virtual Account (BCA / Mandiri / BRI / BNI)',
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 24),
            if (_method == 'qris')
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.line),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2, size: 160, color: c.ink),
                      const SizedBox(height: 8),
                      Text(
                        'Pindai QRIS untuk membayar',
                        style: TextStyle(
                          color: c.ink2,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: 'Bayar ${request != null ? _formatRupiah(request.total) : ''}',
          onPressed: _paying ? null : _simulatePay,
          loading: _paying,
        ),
      ),
    );
  }

  String _formatRupiah(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )}';
  }
}

class _SummaryCard extends StatelessWidget {
  final SosRequest request;
  const _SummaryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <_RowData>[
      _RowData('Biaya panggilan (${request.tierLabel})', request.callFee),
      if (request.nightFee > 0) _RowData('Biaya malam', request.nightFee),
      if (request.serviceFee > 0) _RowData('Biaya layanan', request.serviceFee),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r.label,
                    style: TextStyle(color: c.ink2, fontSize: 13),
                  ),
                  Text(
                    'Rp ${_fmt(r.amount)}',
                    style: TextStyle(
                      color: c.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: c.line, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: c.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                'Rp ${_fmt(request.total)}',
                style: TextStyle(
                  color: c.blueText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int amount) => amount.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
}

class _RowData {
  final String label;
  final int amount;
  const _RowData(this.label, this.amount);
}

class _MethodTile extends StatelessWidget {
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  final String title;
  final IconData icon;

  const _MethodTile({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(title, style: TextStyle(color: c.ink, fontSize: 13.5)),
        secondary: Icon(icon, color: c.blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
