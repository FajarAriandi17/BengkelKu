import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final _bankController =
      TextEditingController(text: "BCA (Bank Central Asia)");
  final _accountNumberController = TextEditingController(text: "8821990411");
  final _accountNameController = TextEditingController(text: "BUDI SANTOSO");

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rekening Bank Tujuan Payout"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pengaturan Rekening Bank",
              style: AppTypography.h1.copyWith(color: c.ink),
            ),
            const SizedBox(height: 6),
            Text(
              "Dana hasil transaksi booking akan dicairkan otomatis H+1 ke rekening ini.",
              style: AppTypography.body
                  .copyWith(color: c.ink.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _bankController,
              label: "Nama Bank",
              hint: "misal: BCA / Mandiri / BRI",
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _accountNumberController,
              label: "Nomor Rekening",
              hint: "8821xxxxxx",
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _accountNameController,
              label: "Nama Pemilik Rekening",
              hint: "Sesuaikan dengan nama di buku tabungan",
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Simpan Rekening Bank",
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Rekening bank berhasil disimpan!")),
            );
          },
        ),
      ),
    );
  }
}
