// ownerSosRoute — bengkel menuju lokasi (PRD v1.3 Bagian 3.3, 3.7, 3.8, 3.9).
//
// DITERIMA       → "Berangkat sekarang" (sos_start_route)
// MENUJU_LOKASI  → peta, navigasi Google Maps/Waze, berbagi lokasi tiap 5 dtk
//                  (broadcast) + simpan jejak tiap 30 dtk, "Saya sudah tiba"
// TIBA           → masukkan kode 4 digit dari pengendara (sos_verify_arrival_code)
// MEMERIKSA      → ajukan penawaran (ownerQuoteForm) atau selesai tanpa perbaikan
// DIKERJAKAN     → tandai selesai
// Berbagi lokasi berhenti saat tiba (PRD 3.8).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/state_views.dart';
import '../../chat/data/chat_repository.dart';
import '../../quote/data/quote_models.dart';
import '../../quote/data/quote_repository.dart';
import '../data/owner_sos_repository.dart';
import '../data/sos_models.dart';
import '../domain/owner_sos_logic.dart';
import 'owner_sos_controller.dart';

class OwnerSosRouteScreen extends ConsumerStatefulWidget {
  const OwnerSosRouteScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<OwnerSosRouteScreen> createState() =>
      _OwnerSosRouteScreenState();
}

class _OwnerSosRouteScreenState extends ConsumerState<OwnerSosRouteScreen> {
  static const _broadcastEvery = Duration(seconds: 5);
  static const _persistEvery = Duration(seconds: 30);

  SosRequest? _req;
  Quote? _latestQuote;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  Position? _me;
  DateTime? _lastPersist;
  Timer? _shareTimer;
  Timer? _pollTimer;
  RealtimeChannel? _requestChannel;
  RealtimeChannel? _locationChannel;
  late final OwnerSosRepository _repo;

  final _codeCtrl = TextEditingController();
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(ownerSosRepositoryProvider);
    _load();
    _requestChannel = _repo.subscribeToRequest(widget.requestId, _onUpdate);
    // Cadangan bila Realtime tidak aktif.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _stopSharing();
    _pollTimer?.cancel();
    if (_requestChannel != null) _repo.unsubscribe(_requestChannel!);
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _repo.getAcceptedRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _req = r;
        _loading = false;
      });
      _syncSharing(r);
      unawaited(_loadQuote());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = OwnerSosRepository.friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final r = await _repo.getAcceptedRequest(widget.requestId);
      _onUpdate(r);
      unawaited(_loadQuote());
    } catch (_) {}
  }

  Future<void> _loadQuote() async {
    try {
      final qs = await QuoteRepository().getQuotesForSos(widget.requestId);
      if (!mounted) return;
      setState(() => _latestQuote = qs.isEmpty ? null : qs.first);
    } catch (_) {}
  }

  void _onUpdate(SosRequest r) {
    if (!mounted) return;
    final changed = _req?.status != r.status;
    setState(() => _req = r);
    _syncSharing(r);
    if (changed) {
      _loadQuote();
      if (!r.isActive) {
        ref.read(ownerSosControllerProvider.notifier).refreshOffersAndJob();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Berbagi lokasi
  // ---------------------------------------------------------------------------

  void _syncSharing(SosRequest r) {
    if (r.status == SosStatus.MENUJU_LOKASI) {
      _startSharing();
    } else {
      _stopSharing();
      if (_me == null && r.isActive) _updatePosition();
    }
  }

  void _startSharing() {
    if (_shareTimer != null) return;
    _locationChannel ??= _repo.openLocationChannel(widget.requestId);
    _share();
    _shareTimer = Timer.periodic(_broadcastEvery, (_) => _share());
  }

  void _stopSharing() {
    _shareTimer?.cancel();
    _shareTimer = null;
    if (_locationChannel != null) {
      _repo.unsubscribe(_locationChannel!);
      _locationChannel = null;
    }
  }

  Future<Position?> _updatePosition() async {
    final p = await currentPositionOrNull();
    if (p != null && mounted) setState(() => _me = p);
    return p ?? _me;
  }

  Future<void> _share() async {
    final p = await _updatePosition();
    final ch = _locationChannel;
    if (p == null || ch == null) return;
    try {
      await _repo.broadcastLocation(
        ch,
        lat: p.latitude,
        lng: p.longitude,
        speed: p.speed,
        heading: p.heading,
      );
      final now = DateTime.now();
      if (_lastPersist == null ||
          now.difference(_lastPersist!) >= _persistEvery) {
        _lastPersist = now;
        await _repo.recordTracking(
          requestId: widget.requestId,
          lat: p.latitude,
          lng: p.longitude,
          speed: p.speed,
          heading: p.heading,
        );
      }
    } catch (e) {
      debugPrint('Gagal berbagi lokasi: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------------

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(OwnerSosRepository.friendlyError(e)),
            backgroundColor: context.colors.bad,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (!isValidArrivalCode(code)) {
      setState(() => _codeError = 'masukkan 4 digit angka');
      return;
    }
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final ok = await _repo.verifyArrivalCode(widget.requestId, code);
      if (!mounted) return;
      if (ok) {
        unawaited(HapticFeedback.lightImpact());
        _codeCtrl.clear();
        await _refresh();
      } else {
        unawaited(HapticFeedback.heavyImpact());
        setState(
          () => _codeError =
              'kode tidak cocok. minta pengendara membacakan kode di aplikasinya',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _codeError = OwnerSosRepository.friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmComplete({required bool withRepair}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(withRepair ? 'Tandai selesai?' : 'Selesai tanpa perbaikan?'),
        content: Text(
          withRepair
              ? 'pastikan perbaikan sudah selesai dan motor bisa dipakai.'
              : 'biaya panggilan tetap berlaku. sarankan pengendara membawa motor ke bengkel bila perlu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, selesai'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _repo.complete(widget.requestId, withRepair: withRepair),
      success: 'panggilan selesai',
    );
  }

  Future<void> _openNav(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('aplikasi navigasi tidak bisa dibuka')),
      );
    }
  }

  Future<void> _openChat() async {
    try {
      final t = await ChatRepository().getThreadForSos(widget.requestId);
      if (!mounted) return;
      if (t == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('chat belum tersedia')));
        return;
      }
      unawaited(context.push('/chat/${t.id}'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(OwnerSosRepository.friendlyError(e))),
      );
    }
  }

  double? _distanceM() {
    final me = _me;
    final r = _req;
    if (me == null || r == null) return null;
    const earth = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(r.lat - me.latitude);
    final dLng = rad(r.lng - me.longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(me.latitude)) *
            math.cos(rad(r.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading) {
      return Scaffold(
        backgroundColor: c.stage,
        appBar: AppBar(title: const Text('Panggilan darurat')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(itemCount: 3),
        ),
      );
    }
    if (_req == null) {
      return Scaffold(
        backgroundColor: c.stage,
        appBar: AppBar(title: const Text('Panggilan darurat')),
        body: ErrorState(
          message: _error ?? 'panggilan tidak ditemukan',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      );
    }

    final r = _req!;
    final dist = _distanceM();

    return Scaffold(
      backgroundColor: c.stage,
      appBar: AppBar(
        title: Text('Panggilan ${r.code}'),
        backgroundColor: c.panel,
        elevation: 0,
        actions: [
          if (r.isActive)
            IconButton(
              tooltip: 'Chat pengendara',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: _openChat,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(status: r.status),
            const SizedBox(height: 12),
            if (r.status == SosStatus.DITERIMA ||
                r.status == SosStatus.MENUJU_LOKASI) ...[
              _RouteMap(request: r, me: _me),
              const SizedBox(height: 12),
            ],
            _RiderCard(request: r, distanceM: dist),
            const SizedBox(height: 16),
            ..._actionsFor(r),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionsFor(SosRequest r) {
    final c = context.colors;
    switch (r.status) {
      case SosStatus.DITERIMA:
        return [
          AppButton(
            label: 'Berangkat sekarang',
            icon: Icons.two_wheeler,
            loading: _busy,
            onPressed: _busy ? null : () => _run(() => _repo.startRoute(r.id)),
          ),
          const SizedBox(height: 8),
          Text(
            'lokasimu dibagikan ke pengendara tiap 5 detik selama perjalanan.',
            style: AppTypography.caption.copyWith(color: c.ink2),
            textAlign: TextAlign.center,
          ),
        ];
      case SosStatus.MENUJU_LOKASI:
        return [
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Google Maps',
                  icon: Icons.map_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      _openNav(NavigationLinks.googleMaps(r.lat, r.lng)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Waze',
                  icon: Icons.navigation_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openNav(NavigationLinks.waze(r.lat, r.lng)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Saya sudah tiba',
            icon: Icons.flag_outlined,
            loading: _busy,
            onPressed: _busy ? null : () => _run(() => _repo.markArrived(r.id)),
          ),
        ];
      case SosStatus.TIBA:
        return [_codeInput()];
      case SosStatus.MEMERIKSA:
        final q = _latestQuote;
        final pending = q != null && q.canRespond;
        return [
          if (q != null) ...[
            _QuoteStatusCard(quote: q),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: pending ? 'Revisi penawaran' : 'Ajukan penawaran biaya',
            icon: Icons.receipt_long_outlined,
            onPressed: _busy
                ? null
                : () async {
                    await context.push('/owner/sos/${r.id}/quote');
                    unawaited(_refresh());
                  },
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Selesai tanpa perbaikan',
            variant: AppButtonVariant.text,
            onPressed: _busy ? null : () => _confirmComplete(withRepair: false),
          ),
        ];
      case SosStatus.DIKERJAKAN:
        return [
          if (_latestQuote != null) ...[
            _QuoteStatusCard(quote: _latestQuote!),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: 'Tandai perbaikan selesai',
            icon: Icons.check_circle_outline,
            loading: _busy,
            onPressed: _busy ? null : () => _confirmComplete(withRepair: true),
          ),
        ];
      default:
        return [
          AppButton(
            label: 'Kembali ke siaga',
            onPressed: () => context.go('/owner/standby'),
          ),
        ];
    }
  }

  Widget _codeInput() {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kode kedatangan',
            style: AppTypography.h2.copyWith(color: c.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'minta pengendara menyebutkan 4 digit kode di aplikasinya sebagai bukti kamu sudah tiba.',
            style: AppTypography.body.copyWith(color: c.ink2),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style:
                AppTypography.display.copyWith(letterSpacing: 18, color: c.ink),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              errorText: _codeError,
              errorMaxLines: 3,
              filled: true,
              fillColor: c.panel2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Konfirmasi kode',
            loading: _busy,
            onPressed: _busy ? null : _verifyCode,
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final SosStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (text, bg, fg) = switch (status) {
      SosStatus.DITERIMA => (
          'kamu menerima panggilan. berangkat sekarang.',
          c.blueSoft,
          c.blueText
        ),
      SosStatus.MENUJU_LOKASI => (
          'menuju lokasi pengendara',
          c.blueSoft,
          c.blueText
        ),
      SosStatus.TIBA => (
          'kamu sudah tiba. minta kode kedatangan.',
          c.warnSoft,
          c.warnText
        ),
      SosStatus.MEMERIKSA => (
          'periksa motor lalu ajukan penawaran',
          c.warnSoft,
          c.warnText
        ),
      SosStatus.DIKERJAKAN => (
          'penawaran disetujui. kerjakan perbaikan.',
          c.okSoft,
          c.okText
        ),
      SosStatus.SELESAI => (
          'panggilan selesai. dana masuk payout H+1.',
          c.okSoft,
          c.okText
        ),
      SosStatus.SELESAI_TANPA_PERBAIKAN => (
          'selesai tanpa perbaikan. biaya panggilan tetap berlaku.',
          c.okSoft,
          c.okText
        ),
      SosStatus.DIBATALKAN => (
          'panggilan dibatalkan pengendara',
          c.badSoft,
          c.badText
        ),
      _ => ('panggilan tidak aktif', c.panel2, c.ink2),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: AppTypography.bodyStrong.copyWith(color: fg)),
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.request, required this.distanceM});
  final SosRequest request;
  final double? distanceM;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = request;
    final problem = SosProblem.values.where((p) => p.name == r.problemCode);
    final net = netEarnings(
      callFee: r.callFee,
      nightFee: r.nightFee,
      commissionRate: r.commissionRate,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.panel,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  problem.isEmpty ? 'Lainnya' : problem.first.label,
                  style: AppTypography.h2.copyWith(color: c.ink),
                ),
              ),
              if (distanceM != null)
                Text(
                  Formatters.distance(distanceM!),
                  style: AppTypography.label.copyWith(color: c.blueText),
                ),
            ],
          ),
          if ((r.problemNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              r.problemNote!,
              style: AppTypography.body.copyWith(color: c.ink2),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place, size: 18, color: c.badC),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    if ((r.landmark ?? '').isNotEmpty) 'patokan: ${r.landmark}',
                    '${r.lat.toStringAsFixed(5)}, ${r.lng.toStringAsFixed(5)} (±${r.accuracyM.round()} m)',
                  ].join('\n'),
                  style: AppTypography.body.copyWith(color: c.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'biaya panggilan ${Formatters.rupiah(r.callFee + r.nightFee)} · '
            'pendapatan bersih ${Formatters.rupiah(net)}',
            style: AppTypography.caption.copyWith(color: c.ink2),
          ),
        ],
      ),
    );
  }
}

/// Peta rute. Di pratinjau web (tanpa kunci Maps JS) → kartu sederhana.
class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.request, required this.me});
  final SosRequest request;
  final Position? me;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dest = LatLng(request.lat, request.lng);
    if (kIsWeb) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: c.mapBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 40, color: c.ink2),
              const SizedBox(height: 6),
              Text(
                'peta tampil di aplikasi Android',
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
            ],
          ),
        ),
      );
    }
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('rider'),
        position: dest,
        infoWindow: const InfoWindow(title: 'Pengendara'),
      ),
      if (me != null)
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(me!.latitude, me!.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Kamu'),
        ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: dest, zoom: 14),
          markers: markers,
          myLocationEnabled: true,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

class _QuoteStatusCard extends StatelessWidget {
  const _QuoteStatusCard({required this.quote});
  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, fg, bg) = switch (quote.state) {
      QuoteState.sent when quote.isExpired => (
          'kedaluwarsa — ajukan ulang',
          c.badText,
          c.badSoft
        ),
      QuoteState.sent => (
          'menunggu persetujuan pengendara',
          c.warnText,
          c.warnSoft
        ),
      QuoteState.approved => ('disetujui', c.okText, c.okSoft),
      QuoteState.rejected => ('ditolak pengendara', c.badText, c.badSoft),
      QuoteState.expired => (
          'kedaluwarsa — ajukan ulang',
          c.badText,
          c.badSoft
        ),
      QuoteState.superseded => ('diganti revisi', c.ink2, c.panel2),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Penawaran ${Formatters.rupiah(quote.total)}',
              style: AppTypography.bodyStrong.copyWith(color: c.ink),
            ),
          ),
          Text(label, style: AppTypography.caption.copyWith(color: fg)),
        ],
      ),
    );
  }
}
