// sosTracking — mekanik menuju lokasi (PRD v1.3 Bagian 3.3, 3.9 & 3.10).
//
// Menampilkan kartu mekanik, ETA (dari broadcast lokasi), kode kedatangan saat
// TIBA, tombol Chat, dan otomatis menuju layar penawaran saat bengkel mengaju-
// kan quote.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/sos_components.dart';
import '../../chat/data/chat_repository.dart';
import '../../quote/data/quote_models.dart';
import '../../quote/data/quote_repository.dart';
import '../data/sos_models.dart';
import 'sos_provider.dart';

class SosTrackingScreen extends ConsumerStatefulWidget {
  final String requestId;

  const SosTrackingScreen({super.key, required this.requestId});

  @override
  ConsumerState<SosTrackingScreen> createState() => _SosTrackingScreenState();
}

class _SosTrackingScreenState extends ConsumerState<SosTrackingScreen> {
  SosRequest? _request;
  bool _loading = true;
  String? _error;
  bool _reduceMotion = false;
  MechanicLocation? _mechanicLocation;

  RealtimeChannel? _requestChannel;
  RealtimeChannel? _locationChannel;
  RealtimeChannel? _quoteChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reduceMotion = MediaQuery.of(context).disableAnimations;
    });
    _load();
    _subscribeRequest();
    _subscribeLocation();
    _subscribeQuotes();
  }

  @override
  void dispose() {
    final repo = ref.read(sosRepositoryProvider);
    if (_requestChannel != null) repo.unsubscribe(_requestChannel!);
    if (_locationChannel != null) repo.unsubscribe(_locationChannel!);
    if (_quoteChannel != null) repo.unsubscribe(_quoteChannel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final req =
          await ref.read(sosRepositoryProvider).getRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = req;
        _loading = false;
      });
      // Bila sudah ada penawaran menunggu, langsung ke layar penawaran.
      try {
        final quotes =
            await QuoteRepository().getQuotesForSos(widget.requestId);
        final pending = quotes.where((q) => q.canRespond).toList();
        if (pending.isNotEmpty && mounted) {
          context.go('/sos/${widget.requestId}/quote?quoteId=${pending.first.id}');
          return;
        }
      } catch (_) {
        // Abaikan; penawaran opsional.
      }
      _routeFor(req);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat permintaan: $e';
        _loading = false;
      });
    }
  }

  void _subscribeRequest() {
    _requestChannel = ref.read(sosRepositoryProvider).subscribeToRequest(
          widget.requestId,
          (req) {
            if (!mounted) return;
            setState(() => _request = req);
            _routeFor(req);
          },
        );
  }

  void _subscribeLocation() {
    _locationChannel =
        ref.read(sosRepositoryProvider).subscribeToMechanicLocation(
              widget.requestId,
              (loc) {
                if (!mounted) return;
                setState(() => _mechanicLocation = loc);
              },
            );
  }

  void _subscribeQuotes() {
    _quoteChannel = QuoteRepository().subscribeToQuotes(
      sosRequestId: widget.requestId,
      onNewQuote: (Quote quote) {
        if (!mounted) return;
        if (quote.canRespond) {
          context.go('/sos/${widget.requestId}/quote?quoteId=${quote.id}');
        }
      },
    );
  }

  void _routeFor(SosRequest req) {
    if (req.status == SosStatus.SELESAI ||
        req.status == SosStatus.SELESAI_TANPA_PERBAIKAN) {
      context.go('/sos/${req.id}/done');
    }
  }

  Future<void> _openChat() async {
    try {
      final thread = await ChatRepository().getThreadForSos(widget.requestId);
      if (!mounted) return;
      if (thread == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat belum tersedia untuk saat ini.')),
        );
        return;
      }
      context.push('/chat/${thread.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka chat: $e')),
      );
    }
  }

  double _distanceKm(MechanicLocation loc, SosRequest req) {
    const r = 6371.0;
    final dLat = _deg2rad(req.lat - loc.lat);
    final dLng = _deg2rad(req.lng - loc.lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(loc.lat)) *
            math.cos(_deg2rad(req.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading || _request == null) {
      return Scaffold(
        backgroundColor: c.stage,
        appBar: AppBar(
          title: const Text('Mekanik menuju lokasi'),
          elevation: 0,
          backgroundColor: c.panel,
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : Center(child: CircularProgressIndicator(color: c.blue)),
      );
    }

    final req = _request!;
    final loc = _mechanicLocation;
    final distanceKm = loc != null ? _distanceKm(loc, req) : null;
    final etaMinutes = distanceKm != null
        ? (distanceKm / 25.0 * 60).ceil().clamp(1, 999).toInt()
        : null;

    final mechanicName = req.mechanicName ?? req.workshopName ?? 'Mekanik';
    final workshopName = req.workshopName ?? 'Bengkel';
    final plate = req.mechanicPlate ?? '-';
    final rating = req.workshopRating ?? 0;

    final statusText = switch (req.status) {
      SosStatus.DITERIMA => 'Bengkel menerima. Mekanik bersiap berangkat.',
      SosStatus.MENUJU_LOKASI => 'Mekanik sedang menuju lokasi kamu.',
      SosStatus.TIBA => 'Mekanik sudah tiba di lokasi.',
      SosStatus.MEMERIKSA => 'Mekanik sedang memeriksa motor kamu.',
      SosStatus.DIKERJAKAN => 'Perbaikan sedang dikerjakan.',
      _ => 'Menunggu pembaruan status…',
    };

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: const Text('Mekanik menuju lokasi'),
        elevation: 0,
        backgroundColor: c.panel,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (distanceKm != null && etaMinutes != null)
            Center(
              child: EtaPill(minutes: etaMinutes, distanceKm: distanceKm),
            )
          else
            Center(
              child: Text(
                'Menunggu lokasi mekanik…',
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.panel,
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(18),
            ),
            child: MechanicCard(
              name: mechanicName.trim().isEmpty ? 'Mekanik' : mechanicName,
              workshopName: workshopName,
              photo: req.mechanicPhoto,
              plate: plate,
              rating: rating,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: c.blueText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: AppTypography.body.copyWith(color: c.blueText),
                  ),
                ),
              ],
            ),
          ),
          if (req.status == SosStatus.TIBA &&
              (req.arrivalCode ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            ArrivalCodeCard(
              code: req.arrivalCode!,
              reduceMotion: _reduceMotion,
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Chat dengan bengkel',
            icon: Icons.chat_bubble_outline,
            variant: AppButtonVariant.secondary,
            onPressed: _openChat,
          ),
        ],
      ),
    );
  }
}
