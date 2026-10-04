// Pengendali siaga darurat sisi bengkel (ownerStandby, PRD v1.3 Bagian 3.3).
//
// Saat siaga aktif:
//   * detak posisi tiap 20 dtk (server hanya menawari bengkel dengan
//     last_seen_at ≤ 60 dtk),
//   * dengarkan tawaran baru lewat Realtime + polling cadangan 10 dtk,
//   * tawaran baru diumumkan lewat [OwnerSosState.incomingOfferId] —
//     OwnerSosHost membuka layar penuh ownerSosOffer.
//
// Catatan: siaga di latar belakang (foreground service Android / background
// location iOS) butuh plugin native dan belum ada di MVP ini; siaga berjalan
// selama aplikasi terbuka.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/owner_sos_models.dart';
import '../data/owner_sos_repository.dart';
import '../data/sos_models.dart';
import '../domain/owner_sos_logic.dart';

final ownerSosRepositoryProvider =
    Provider<OwnerSosRepository>((ref) => OwnerSosRepository());

final ownerSosControllerProvider =
    StateNotifierProvider<OwnerSosController, OwnerSosState>((ref) {
  return OwnerSosController(ref.watch(ownerSosRepositoryProvider));
});

/// Ambil posisi saat ini (izin diminta bila perlu). null bila tidak tersedia.
Future<Position?> currentPositionOrNull() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  } catch (e) {
    debugPrint('Lokasi tidak tersedia: $e');
    return null;
  }
}

@immutable
class OwnerSosState {
  const OwnerSosState({
    this.loading = true,
    this.saving = false,
    this.workshop,
    this.standby,
    this.tiers = SosTier.defaults,
    this.openOffers = const [],
    this.activeJob,
    this.incomingOfferId,
    this.error,
    this.locationWarning,
    this.lastHeartbeat,
  });

  final bool loading;
  final bool saving;
  final OwnerWorkshop? workshop;
  final WorkshopStandby? standby;
  final List<SosTier> tiers;
  final List<SosOffer> openOffers;
  final SosRequest? activeJob;
  final String? incomingOfferId;
  final String? error;
  final String? locationWarning;
  final DateTime? lastHeartbeat;

  bool get isReady => standby?.emergencyReady ?? false;
  bool get afterHours => standby?.afterHours ?? false;
  int get radiusTierMax => standby?.radiusTierMax ?? tiers.last.tier;

  OwnerSosState copyWith({
    bool? loading,
    bool? saving,
    OwnerWorkshop? workshop,
    WorkshopStandby? standby,
    List<SosTier>? tiers,
    List<SosOffer>? openOffers,
    SosRequest? activeJob,
    bool clearActiveJob = false,
    String? incomingOfferId,
    bool clearIncoming = false,
    String? error,
    bool clearError = false,
    String? locationWarning,
    bool clearLocationWarning = false,
    DateTime? lastHeartbeat,
  }) {
    return OwnerSosState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      workshop: workshop ?? this.workshop,
      standby: standby ?? this.standby,
      tiers: tiers ?? this.tiers,
      openOffers: openOffers ?? this.openOffers,
      activeJob: clearActiveJob ? null : (activeJob ?? this.activeJob),
      incomingOfferId:
          clearIncoming ? null : (incomingOfferId ?? this.incomingOfferId),
      error: clearError ? null : (error ?? this.error),
      locationWarning: clearLocationWarning
          ? null
          : (locationWarning ?? this.locationWarning),
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    );
  }
}

class OwnerSosController extends StateNotifier<OwnerSosState> {
  OwnerSosController(this._repo) : super(const OwnerSosState()) {
    load();
  }

  final OwnerSosRepository _repo;

  static const heartbeatEvery = Duration(seconds: 20);
  static const pollEvery = Duration(seconds: 10);

  Timer? _heartbeat;
  Timer? _poll;
  RealtimeChannel? _offerChannel;
  final Set<String> _announced = {};
  Position? _lastPosition;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final ws = await _repo.getMyWorkshop();
      if (!mounted) return;
      if (ws == null) {
        _stopLoops();
        state = const OwnerSosState(loading: false);
        return;
      }
      final results = await Future.wait([
        _repo.getStandby(ws.id),
        _repo.getTiers(),
        _repo.getActiveJob(ws.id),
      ]);
      if (!mounted) return;
      final standby = results[0] as WorkshopStandby?;
      state = OwnerSosState(
        loading: false,
        workshop: ws,
        standby: standby,
        tiers: results[1] as List<SosTier>,
        activeJob: results[2] as SosRequest?,
        lastHeartbeat: state.lastHeartbeat,
      );
      if (standby?.emergencyReady ?? false) {
        _startLoops();
      } else {
        _stopLoops();
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        error: OwnerSosRepository.friendlyError(e),
      );
    }
  }

  Future<bool> updateSettings({
    bool? ready,
    bool? afterHours,
    int? radiusTierMax,
  }) async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      final s = await _repo.updateStandbySettings(
        ready: ready ?? state.isReady,
        afterHours: afterHours ?? state.afterHours,
        radiusTierMax: radiusTierMax ?? state.radiusTierMax,
      );
      if (!mounted) return true;
      state = state.copyWith(saving: false, standby: s);
      if (s.emergencyReady) {
        _startLoops();
      } else {
        _stopLoops();
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        saving: false,
        error: OwnerSosRepository.friendlyError(e),
      );
      return false;
    }
  }

  /// Dipanggil host setelah membuka layar tawaran, agar tidak dibuka dua kali.
  void consumeIncoming() => state = state.copyWith(clearIncoming: true);

  /// Setelah menerima/lewati/selesai: segarkan daftar & pekerjaan aktif.
  Future<void> refreshOffersAndJob() async {
    final ws = state.workshop;
    if (ws == null) return;
    try {
      final offers = await _repo.getOpenOffers();
      final job = await _repo.getActiveJob(ws.id);
      if (!mounted) return;
      state = state.copyWith(
        openOffers: offers,
        activeJob: job,
        clearActiveJob: job == null,
      );
    } catch (e) {
      debugPrint('Gagal menyegarkan tawaran: $e');
    }
  }

  // ---------------------------------------------------------------------------

  void _startLoops() {
    final ws = state.workshop;
    if (ws == null) return;
    _heartbeat ??= Timer.periodic(heartbeatEvery, (_) => _beat());
    _poll ??= Timer.periodic(pollEvery, (_) => _pollOffers());
    _offerChannel ??= _repo.subscribeToOffers(ws.id, _onOffer);
    _beat();
    _pollOffers();
  }

  void _stopLoops() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _poll?.cancel();
    _poll = null;
    if (_offerChannel != null) {
      _repo.unsubscribe(_offerChannel!);
      _offerChannel = null;
    }
  }

  Future<void> _beat() async {
    final ws = state.workshop;
    if (ws == null) return;
    final pos = await currentPositionOrNull() ?? _lastPosition;
    if (!mounted) return;
    if (pos == null) {
      state = state.copyWith(
        locationWarning:
            'izin lokasi dibutuhkan agar bengkelmu bisa menerima panggilan darurat',
      );
      return;
    }
    _lastPosition = pos;
    try {
      await _repo.heartbeat(
        workshopId: ws.id,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      state = state.copyWith(
        lastHeartbeat: DateTime.now(),
        clearLocationWarning: true,
      );
    } catch (e) {
      debugPrint('Detak siaga gagal: $e');
    }
  }

  Future<void> _pollOffers() async {
    if (state.workshop == null) return;
    try {
      final offers = await _repo.getOpenOffers();
      if (!mounted) return;
      state = state.copyWith(openOffers: offers);
      for (final o in offers) {
        _announce(o);
      }
    } catch (e) {
      debugPrint('Polling tawaran gagal: $e');
    }
  }

  void _onOffer(SosOffer offer) {
    if (!mounted) return;
    if (!state.openOffers.any((o) => o.id == offer.id)) {
      state = state.copyWith(openOffers: [offer, ...state.openOffers]);
    }
    _announce(offer);
  }

  void _announce(SosOffer offer) {
    if (offer.state != 'sent') return;
    if (offer.expiresAt.isBefore(DateTime.now())) return;
    if (_announced.contains(offer.id)) return;
    // Satu panggilan aktif per bengkel: jangan ganggu saat menangani panggilan.
    if (state.activeJob != null) return;
    _announced.add(offer.id);
    state = state.copyWith(incomingOfferId: offer.id);
  }

  @override
  void dispose() {
    _stopLoops();
    super.dispose();
  }
}
