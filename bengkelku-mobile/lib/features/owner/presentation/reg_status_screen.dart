// regStatus — status verifikasi bengkel, dibaca langsung dari DB (0021).
// Diperbarui otomatis via Realtime saat admin web menyetujui / menolak.

import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/state_views.dart";
import "../data/owner_repository.dart";

class RegStatusScreen extends StatefulWidget {
  const RegStatusScreen({super.key});

  @override
  State<RegStatusScreen> createState() => _RegStatusScreenState();
}

class _RegStatusScreenState extends State<RegStatusScreen> {
  final _repo = OwnerRepository();
  Map<String, dynamic>? _s;
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    if (_channel != null) {
      unawaited(SupabaseService.client.removeChannel(_channel!));
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.getMyVerificationStatus();
      if (!mounted) return;
      setState(() {
        _s = s;
        _loading = false;
        _error = null;
      });
      final id = s?["id"] as String?;
      if (id != null && _channel == null) {
        _channel = SupabaseService.client
            .channel("ws_status:$id")
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: "public",
              table: "workshops",
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: "id",
                value: id,
              ),
              callback: (_) => unawaited(_load()),
            )
            .subscribe();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is PostgrestException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget body;
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: c.blue));
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_s == null) {
      body = EmptyState(
        icon: Icons.storefront_outlined,
        title: "kamu belum mendaftarkan bengkel",
        message:
            "daftarkan bengkel untuk mulai menerima booking & panggilan darurat.",
        actionLabel: "Daftarkan bengkel",
        onAction: () => context.pushReplacement("/owner/register"),
      );
    } else {
      final s = _s!;
      final status = s["status"] as String? ?? "draft";
      final submitted = s["submitted_at"] != null
          ? Formatters.dateTimeLocal(
              DateTime.parse(s["submitted_at"] as String))
          : null;
      final (title, message, icon, color) = switch (status) {
        "verified" => (
            "Bengkel Disetujui!",
            "selamat! ${s["name"]} sudah tayang di BengkelKu. pelanggan kini bisa menemukan & memesan servis.",
            Icons.verified,
            c.ok,
          ),
        "rejected" => (
            "Verifikasi Ditolak",
            (s["rejected_reason"] as String?) ??
                "data belum sesuai. perbaiki lalu ajukan ulang.",
            Icons.error_outline,
            c.bad,
          ),
        "suspended" => (
            "Bengkel Ditangguhkan",
            (s["rejected_reason"] as String?) ??
                "hubungi pusat bantuan untuk informasi lebih lanjut.",
            Icons.block,
            c.bad,
          ),
        "pending" => (
            "Menunggu Verifikasi",
            "berkas ${s["name"]} sedang ditinjau tim admin (maksimal 2×24 jam kerja). kamu akan mendapat notifikasi.",
            Icons.hourglass_top,
            c.warn,
          ),
        _ => (
            "Pendaftaran Belum Dikirim",
            "lengkapi data & dokumen lalu kirim ke tim verifikasi.",
            Icons.edit_note,
            c.ink2,
          ),
      };

      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(icon, size: 72, color: color, semanticLabel: title),
            const SizedBox(height: 24),
            Text(title,
                style: AppTypography.display.copyWith(color: c.ink),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(message,
                style: AppTypography.body.copyWith(color: c.ink2),
                textAlign: TextAlign.center),
            if (submitted != null && status == "pending") ...[
              const SizedBox(height: 8),
              Text("diajukan $submitted",
                  style: AppTypography.caption.copyWith(color: c.ink2),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 32),
            if (status == "rejected" || status == "draft")
              AppButton(
                label: status == "rejected"
                    ? "Perbaiki & Ajukan Ulang"
                    : "Lanjutkan Pendaftaran",
                onPressed: () => context.pushReplacement("/owner/register"),
              )
            else if (status == "verified")
              AppButton(
                label: "Buka Dashboard Bengkel",
                onPressed: () => context.go("/owner"),
              )
            else if (status == "suspended")
              AppButton(
                label: "Hubungi Pusat Bantuan",
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push("/help/report"),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Status Verifikasi Bengkel"),
        elevation: 0,
      ),
      body: SafeArea(child: body),
    );
  }
}
