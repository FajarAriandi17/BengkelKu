import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/slot_picker.dart";

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot = "09:00";
  final String _selectedVehicleId = "v-1";

  final List<DateTime> _availableDates = List.generate(
    7,
    (index) => DateTime.now().add(Duration(days: index + 1)),
  );

  final List<String> _availableSlots = [
    "08:00",
    "09:00",
    "10:00",
    "11:00",
    "13:00",
    "14:00",
    "15:00",
    "16:00",
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Jadwal & Motor"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pilih Kendaraan",
                style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
            const SizedBox(height: 10),

            // Card kendaraan
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.blue),
              ),
              child: Row(
                children: [
                  Icon(Icons.two_wheeler, color: c.blue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Honda Vario 160",
                            style: AppTypography.bodyStrong
                                .copyWith(color: c.ink)),
                        Text("B 1234 XYZ • Odometer: 12.500 km",
                            style: AppTypography.caption
                                .copyWith(color: c.ink.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: c.blue, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SlotPicker(
              dates: _availableDates,
              selectedDate: _selectedDate,
              slots: _availableSlots,
              selectedSlot: _selectedSlot,
              onDateSelected: (date) => setState(() => _selectedDate = date),
              onSlotSelected: (slot) => setState(() => _selectedSlot = slot),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Ringkasan Pemesanan",
          onPressed: _selectedSlot == null
              ? null
              : () => context.push(
                    "/summary?workshopId=${widget.workshopId}"
                    "&vehicleId=$_selectedVehicleId"
                    "&slot=${_selectedDate.toIso8601String().substring(0, 10)}T$_selectedSlot",
                  ),
        ),
      ),
    );
  }
}
