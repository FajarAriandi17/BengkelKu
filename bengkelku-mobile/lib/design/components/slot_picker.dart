import "package:flutter/material.dart";

import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";
import "../../core/utils/formatters.dart";

/// Pemilih tanggal & slot waktu ketersediaan servis.
class SlotPicker extends StatelessWidget {
  const SlotPicker({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.slots,
    required this.selectedSlot,
    required this.onDateSelected,
    required this.onSlotSelected,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final List<String> slots; // mis. ["08:00", "09:00", "10:00"]
  final String? selectedSlot;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<String> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Pilih Tanggal",
            style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSame = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;

              return InkWell(
                onTap: () => onDateSelected(date),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSame ? c.blue : c.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSame ? c.blue : c.blueSoft),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Formatters.dateOnly(date).split(" ").take(2).join(" "),
                        style: AppTypography.caption.copyWith(
                          color: isSame ? Colors.white : c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${date.day}",
                        style: AppTypography.h2.copyWith(
                          color: isSame ? Colors.white : c.blue,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text("Pilih Slot Jam",
            style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final isSelected = slot == selectedSlot;
            return ChoiceChip(
              label: Text(slot),
              selected: isSelected,
              onSelected: (_) => onSlotSelected(slot),
              selectedColor: c.blue,
              backgroundColor: c.panel,
              labelStyle: AppTypography.label.copyWith(
                color: isSelected ? Colors.white : c.ink,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isSelected ? c.blue : c.blueSoft),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
