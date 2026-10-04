import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../data/owner_repository.dart";

/// Bottom sheet penolakan booking oleh bengkel (owner_booking_action 'reject').
/// Mengembalikan `true` lewat Navigator.pop bila berhasil.
class OwnerRejectSheet extends StatefulWidget {
  const OwnerRejectSheet({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<OwnerRejectSheet> createState() => _OwnerRejectSheetState();
}

class _OwnerRejectSheetState extends State<OwnerRejectSheet> {
  final _reasonController = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _quick = [
    "slot sudah penuh",
    "bengkel libur",
    "sparepart tidak tersedia"
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 5) {
      setState(() => _error = "tulis alasan minimal 5 karakter");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await OwnerRepository()
          .bookingAction(widget.bookingId, "reject", reason: reason);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        const SnackBar(
            content:
                Text("booking ditolak. refund 100% diproses ke pelanggan.")),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e is PostgrestException ? e.message : "$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Tolak Booking", style: AppTypography.h1.copyWith(color: c.bad)),
          const SizedBox(height: 8),
          Text(
            "pelanggan mendapat refund 100%. nomor telepon & tautan di alasan akan disembunyikan.",
            style: AppTypography.body.copyWith(color: c.ink2),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final q in _quick)
                ActionChip(
                  label: Text(q),
                  onPressed: () => setState(() => _reasonController.text = q),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _reasonController,
            label: "Alasan Penolakan",
            hint: "misal: slot penuh / bengkel libur",
            maxLines: 2,
            errorText: _error,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: "Tolak Booking",
            loading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ],
      ),
    );
  }
}
