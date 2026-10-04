import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";

class OwnerScanScreen extends StatelessWidget {
  const OwnerScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Check-In"),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                "Arahkan kamera ke kode QR di tiket booking pelanggan untuk melakukan check-in.",
                style: AppTypography.body.copyWith(color: c.ink.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Box Kamera Simulator Mock
              Container(
                height: 260,
                width: 260,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.blue, width: 3),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 80, color: Colors.white70),
                    SizedBox(height: 8),
                    Text("Area Scan QR", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const Spacer(),

              AppButton(
                label: "Simulasi Check-In Berhasil",
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Check-In Budi Santoso Berhasil!")),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
