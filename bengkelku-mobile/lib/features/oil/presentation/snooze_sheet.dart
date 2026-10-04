import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";

/// Bottom sheet tunda pengingat oli.
class SnoozeSheet extends StatefulWidget {
  const SnoozeSheet({super.key});

  @override
  State<SnoozeSheet> createState() => _SnoozeSheetState();
}

class _SnoozeSheetState extends State<SnoozeSheet> {
  int _selectedDays = 7;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Tunda Pengingat Oli",
              style: AppTypography.h1.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Text(
            "Pilih berapa lama kamu ingin menunda notifikasi pengingat oli motor ini.",
            style: AppTypography.body
                .copyWith(color: c.ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          RadioListTile<int>(
            value: 3,
            groupValue: _selectedDays,
            title: const Text("Tunda 3 Hari"),
            onChanged: (val) => setState(() => _selectedDays = val!),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          RadioListTile<int>(
            value: 7,
            groupValue: _selectedDays,
            title: const Text("Tunda 7 Hari"),
            onChanged: (val) => setState(() => _selectedDays = val!),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          RadioListTile<int>(
            value: 14,
            groupValue: _selectedDays,
            title: const Text("Tunda 14 Hari"),
            onChanged: (val) => setState(() => _selectedDays = val!),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: "Simpan Penundaan",
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Pengingat oli ditunda $_selectedDays hari")),
              );
            },
          ),
        ],
      ),
    );
  }
}
