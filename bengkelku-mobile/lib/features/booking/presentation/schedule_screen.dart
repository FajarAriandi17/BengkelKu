import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/slot_picker.dart";
import "../../../design/components/state_views.dart";
import "../../garage/data/garage_repository.dart";
import "../../garage/data/vehicle_model.dart";
import "../data/booking_repository.dart";

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen(
      {super.key, required this.workshopId, this.serviceIds = const []});

  final String workshopId;
  final List<String> serviceIds;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _bookingRepo = BookingRepository();
  final _garageRepo = GarageRepository();

  late final List<DateTime> _dates;
  late DateTime _selectedDate;
  List<BookingSlot> _slots = [];
  BookingSlot? _selectedSlot;
  bool _loadingSlots = true;
  String? _slotError;

  List<Vehicle> _vehicles = [];
  String? _vehicleId;
  bool _loadingVehicles = true;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dates = List.generate(
        14, (i) => DateTime(today.year, today.month, today.day + i));
    _selectedDate = _dates.first;
    _loadVehicles();
    _loadSlots();
  }

  Future<void> _loadVehicles() async {
    try {
      final v = await _garageRepo.getUserVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = v;
        _vehicleId = v.isNotEmpty ? v.first.id : null;
        _loadingVehicles = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingVehicles = false);
    }
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotError = null;
      _selectedSlot = null;
    });
    try {
      final s =
          await _bookingRepo.availableSlots(widget.workshopId, _selectedDate);
      if (!mounted) return;
      setState(() {
        _slots = s;
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slots = [];
        _slotError = bookingErrorMessage(e);
        _loadingSlots = false;
      });
    }
  }

  void _next() {
    final slot = _selectedSlot;
    if (slot == null) return;
    final uri = Uri(
      path: "/summary",
      queryParameters: {
        "workshopId": widget.workshopId,
        "services": widget.serviceIds.join(","),
        if (_vehicleId != null) "vehicleId": _vehicleId!,
        "slot": slot.at.toIso8601String(),
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (widget.serviceIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pilih Jadwal & Motor")),
        body: EmptyState(
          title: "Belum ada layanan dipilih",
          message: "Kembali ke halaman bengkel dan pilih minimal satu layanan.",
          icon: Icons.build_circle_outlined,
          actionLabel: "Kembali",
          onAction: () => context.pop(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Pilih Jadwal & Motor"), elevation: 0),
      body: RefreshIndicator(
        onRefresh: _loadSlots,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pilih Kendaraan",
                style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (_loadingVehicles)
                const LinearProgressIndicator()
              else if (_vehicles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.warnSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: c.warnText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Belum ada motor di garasi. Kamu tetap bisa booking, "
                          "atau tambahkan motor agar riwayat servis tercatat.",
                          style: AppTypography.caption.copyWith(color: c.ink),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await context.push("/garage");
                          await _loadVehicles();
                        },
                        child: const Text("Tambah"),
                      ),
                    ],
                  ),
                )
              else
                ..._vehicles.map((v) {
                  final selected = v.id == _vehicleId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _vehicleId = v.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? c.blue : c.line,
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.two_wheeler, color: c.blue, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${v.brand} ${v.model}",
                                    style: AppTypography.bodyStrong
                                        .copyWith(color: c.ink),
                                  ),
                                  Text(
                                    "${v.plate ?? "-"} • ${v.odometer} km",
                                    style: AppTypography.caption
                                        .copyWith(color: c.ink2),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected ? c.blue : c.line,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              SlotPicker(
                dates: _dates,
                selectedDate: _selectedDate,
                slots: _slots.map((s) => s.label).toList(),
                disabledSlots: _slots
                    .where((s) => !s.available)
                    .map((s) => s.label)
                    .toSet(),
                loadingSlots: _loadingSlots,
                selectedSlot: _selectedSlot?.label,
                onDateSelected: (d) {
                  setState(() => _selectedDate = d);
                  _loadSlots();
                },
                onSlotSelected: (label) => setState(
                  () => _selectedSlot =
                      _slots.firstWhere((s) => s.label == label),
                ),
              ),
              if (_slotError != null) ...[
                const SizedBox(height: 12),
                ErrorState(message: _slotError!, onRetry: _loadSlots),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Ringkasan Pemesanan",
          onPressed: _selectedSlot == null ? null : _next,
        ),
      ),
    );
  }
}
