import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../../../design/components/state_views.dart";
import "../../garage/data/garage_repository.dart";
import "../../garage/data/vehicle_model.dart";
import "../../workshops/data/workshop_model.dart";
import "../../workshops/data/workshop_repository.dart";
import "../data/booking_repository.dart";

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({
    super.key,
    required this.workshopId,
    this.serviceIds = const [],
    this.vehicleId,
    this.slot,
  });

  final String workshopId;
  final List<String> serviceIds;
  final String? vehicleId;
  final DateTime? slot;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  final _bookingRepo = BookingRepository();
  final _workshopRepo = WorkshopRepository();
  final _garageRepo = GarageRepository();
  final _noteCtrl = TextEditingController();

  Workshop? _workshop;
  List<WorkshopServiceItem> _services = [];
  Vehicle? _vehicle;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final w = await _workshopRepo.getWorkshopDetail(widget.workshopId);
      final all = await _workshopRepo.getWorkshopServices(widget.workshopId);
      Vehicle? v;
      if (widget.vehicleId != null) {
        final list = await _garageRepo.getUserVehicles();
        for (final x in list) {
          if (x.id == widget.vehicleId) v = x;
        }
      }
      if (!mounted) return;
      setState(() {
        _workshop = w;
        _services = all.where((s) => widget.serviceIds.contains(s.id)).toList();
        _vehicle = v;
        _loading = false;
        if (w == null) _error = "Bengkel tidak ditemukan.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = bookingErrorMessage(e);
        _loading = false;
      });
    }
  }

  int get _subtotal => _services.fold(0, (a, s) => a + s.priceIdr);

  Future<void> _submit() async {
    final slot = widget.slot;
    if (slot == null || _services.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final booking = await _bookingRepo.createBooking(
        workshopId: widget.workshopId,
        vehicleId: widget.vehicleId,
        serviceIds: _services.map((s) => s.id).toList(),
        scheduledAt: slot,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      context.pushReplacement("/payment?bookingId=${booking.id}");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookingErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _row(BuildContext context, String k, String v) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: AppTypography.body.copyWith(color: c.ink2)),
          ),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: AppTypography.bodyStrong.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slot = widget.slot;

    Widget body;
    if (_loading) {
      body = const SkeletonList(itemCount: 4);
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (slot == null || _services.isEmpty) {
      body = EmptyState(
        title: "Data pemesanan tidak lengkap",
        message: "Silakan pilih layanan dan jadwal kembali.",
        icon: Icons.event_busy,
        actionLabel: "Kembali",
        onAction: () => context.pop(),
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.panel, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_workshop!.name, style: AppTypography.h2.copyWith(color: c.ink)),
                  const SizedBox(height: 4),
                  Text(_workshop!.address,
                      style: AppTypography.caption.copyWith(color: c.ink2)),
                  const Divider(height: 24),
                  _row(context, "Jadwal", Formatters.dateTimeLocal(slot)),
                  _row(
                      context,
                      "Kendaraan",
                      _vehicle == null
                          ? "Tidak dipilih"
                          : "${_vehicle!.brand} ${_vehicle!.model} (${_vehicle!.plate ?? "-"})"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text("Layanan Dipesan",
                style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: c.panel, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (final s in _services)
                    _row(context, s.name, Formatters.rupiah(s.priceIdr)),
                  const Divider(height: 20),
                  _row(context, "Subtotal", Formatters.rupiah(_subtotal)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Total akhir (termasuk biaya layanan bila ada) dihitung oleh server "
              "dan ditampilkan di halaman pembayaran.",
              style: AppTypography.caption.copyWith(color: c.ink2),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _noteCtrl,
              label: "Catatan untuk bengkel (opsional)",
              hint: "Mis. rem bunyi, minta cek rantai",
              maxLines: 3,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Ringkasan Pemesanan"), elevation: 0),
      body: body,
      bottomNavigationBar: (!_loading && _error == null && slot != null && _services.isNotEmpty)
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: AppButton(
                label: "Buat Pesanan",
                onPressed: _submitting ? null : _submit,
                loading: _submitting,
              ),
            )
          : null,
    );
  }
}
