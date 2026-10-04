// Provider state alur Bantuan Darurat (PRD v1.3 Bagian 3).
//
// State machine: status permintaan + fee + penawaran aktif.
// Semua aksi lewat SosRepository → RPC Supabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client.dart';
import '../data/sos_models.dart';
import '../data/sos_repository.dart';

final sosRepositoryProvider = Provider<SosRepository>((ref) {
  return SosRepository();
});

/// Permintaan darurat aktif pengendara saat ini (atau null bila tak ada).
final activeSosProvider =
    StateNotifierProvider<ActiveSosNotifier, AsyncValue<SosRequest?>>((ref) {
  return ActiveSosNotifier(ref.watch(sosRepositoryProvider));
});

class ActiveSosNotifier extends StateNotifier<AsyncValue<SosRequest?>> {
  final SosRepository _repository;

  ActiveSosNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadActive();
  }

  /// Ambil panggilan aktif (paling baru yang belum selesai).
  Future<void> loadActive() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('sos_requests')
          .select()
          .eq('rider_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final request = SosRequest.fromJson(response);
      state = AsyncValue.data(request.isActive ? request : null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Buat permintaan baru setelah pembayaran fee.
  Future<SosRequest?> create({
    required SosProblem problem,
    String? note,
    List<String>? photos,
    required double lat,
    required double lng,
    required double accuracyM,
    String? landmark,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _repository.createRequest(
        problemCode: problem.name,
        problemNote: note,
        photos: photos,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        landmark: landmark,
      );

      state = AsyncValue.data(response);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Batalkan permintaan yang sedang aktif.
  Future<Map<String, dynamic>?> cancelActive(String reason) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    try {
      final result = await _repository.cancelRequest(
        requestId: current.id,
        reason: reason,
      );
      state = const AsyncValue.data(null);
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Reset state setelah alur selesai total.
  void clear() {
    state = const AsyncValue.data(null);
  }
}

/// Status siaga darurat bengkel saat ini (sisi owner).
final workshopStandbyProvider = StateNotifierProvider<WorkshopStandbyNotifier,
    AsyncValue<WorkshopStandby?>>((ref) {
  return WorkshopStandbyNotifier(ref.watch(sosRepositoryProvider));
});

class WorkshopStandbyNotifier
    extends StateNotifier<AsyncValue<WorkshopStandby?>> {
  final SosRepository _repository;

  WorkshopStandbyNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    final ownerId = SupabaseService.currentUser?.id;
    if (ownerId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final workshopId = await SupabaseService.client
          .from('workshops')
          .select('id')
          .eq('owner_id', ownerId)
          .maybeSingle();

      if (workshopId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final response = await SupabaseService.client
          .from('workshop_standby')
          .select()
          .eq('workshop_id', workshopId['id'] as String)
          .maybeSingle();

      state = AsyncValue.data(
        response == null ? null : WorkshopStandby.fromJson(response),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle({
    required bool ready,
    int radiusTierMax = 4,
  }) async {
    final ownerId = SupabaseService.currentUser?.id;
    if (ownerId == null) return;

    final workshopId = await SupabaseService.client
        .from('workshops')
        .select('id')
        .eq('owner_id', ownerId)
        .maybeSingle();
    if (workshopId == null) return;

    await _repository.toggleEmergencyReady(
      workshopId: workshopId['id'] as String,
      ready: ready,
      radiusTierMax: radiusTierMax,
    );
    await load();
  }
}
