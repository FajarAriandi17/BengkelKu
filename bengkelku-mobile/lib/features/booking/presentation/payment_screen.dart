import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = "qris";

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pembayaran Online"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer batas waktu
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.warnSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: c.warn, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Selesaikan pembayaran dalam 59:50",
                      style: AppTypography.label.copyWith(color: c.warn),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text("Pilih Metode Pembayaran", style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
            const SizedBox(height: 12),

            // Method 1: QRIS
            RadioListTile<String>(
              value: "qris",
              groupValue: _selectedMethod,
              onChanged: (val) => setState(() => _selectedMethod = val!),
              title: const Text("QRIS (BCA, Mandiri, GoPay, OVO, ShopeePay)"),
              secondary: Icon(Icons.qr_code_2, color: c.blue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: c.panel,
            ),
            const SizedBox(height: 8),

            // Method 2: E-Wallet
            RadioListTile<String>(
              value: "ewallet",
              groupValue: _selectedMethod,
              onChanged: (val) => setState(() => _selectedMethod = val!),
              title: const Text("E-Wallet (GoPay / OVO / Dana)"),
              secondary: Icon(Icons.account_balance_wallet, color: c.blue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: c.panel,
            ),
            const SizedBox(height: 8),

            // Method 3: Virtual Account
            RadioListTile<String>(
              value: "va",
              groupValue: _selectedMethod,
              onChanged: (val) => setState(() => _selectedMethod = val!),
              title: const Text("Virtual Account (BCA / Mandiri / BRI / BNI)"),
              secondary: Icon(Icons.account_balance, color: c.blue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: c.panel,
            ),
            const SizedBox(height: 24),

            if (_selectedMethod == "qris") ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.blueSoft),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_2, size: 180, color: c.ink),
                      const SizedBox(height: 8),
                      Text("Pindai QRIS untuk membayar", style: AppTypography.caption.copyWith(color: Colors.black54)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Simulasi Bayar Sukses",
          onPressed: () => context.go("/payment-success?bookingId=${widget.bookingId}"),
        ),
      ),
    );
  }
}
