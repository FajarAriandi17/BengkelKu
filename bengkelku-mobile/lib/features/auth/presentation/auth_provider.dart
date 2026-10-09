import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "../data/auth_repository.dart";
import "../domain/auth_error_mapper.dart";

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream perubahan sesi. Aman bila Supabase gagal diinisialisasi.
final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!SupabaseService.isReady) return const Stream.empty();
  return SupabaseService.auth.onAuthStateChange;
});

/// ID pengguna yang sedang masuk. Provider lain yang menyimpan data per
/// akun (chat, SOS, profil) wajib `ref.watch` provider ini agar otomatis
/// di-reset saat logout / ganti akun — mencegah data akun lama tampil.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return SupabaseService.currentUser?.id;
});

/// Notifier untuk `GoRouter.refreshListenable`: router mengevaluasi ulang
/// redirect setiap kali sesi berubah (login, logout, token kedaluwarsa,
/// kembali dari OAuth Google, atau tautan reset kata sandi).
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier() {
    if (!SupabaseService.isReady) return;
    _sub = SupabaseService.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          passwordRecovery = true;
        } else if (data.event == AuthChangeEvent.signedOut) {
          passwordRecovery = false;
        }
        notifyListeners();
      },
      // Tautan deep link rusak/kedaluwarsa tidak boleh membuat app crash.
      onError: (Object _) => notifyListeners(),
    );
  }

  StreamSubscription<AuthState>? _sub;

  /// True setelah pengguna membuka tautan reset kata sandi dari email.
  bool passwordRecovery = false;

  void clearRecovery() {
    passwordRecovery = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authRefreshProvider = Provider<AuthRefreshNotifier>((ref) {
  final n = AuthRefreshNotifier();
  ref.onDispose(n.dispose);
  return n;
});

/// Profil pengguna; otomatis dimuat ulang saat akun berganti.
final currentUserProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(currentUserIdProvider);
  final repo = ref.watch(authRepositoryProvider);
  return await repo.getProfile();
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repo) : super(const AsyncValue.data(null));

  final AuthRepository _repo;

  /// Pesan error ramah dari state terakhir (null bila tidak ada).
  String? get errorMessage =>
      state.hasError ? authErrorMessage(state.error!) : null;

  void clearError() {
    if (state.hasError) state = const AsyncValue.data(null);
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signInWithEmail(email: email, password: password);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Mengembalikan null bila gagal (lihat [errorMessage]).
  Future<SignUpResult?> register(
    String email,
    String password,
    String fullName,
  ) async {
    state = const AsyncValue.loading();
    try {
      final r = await _repo.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      state = const AsyncValue.data(null);
      return r;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final launched = await _repo.signInWithGoogle();
      // Sesi aktif saat aplikasi dibuka lagi lewat deep link;
      // router berpindah otomatis lewat AuthRefreshNotifier.
      state = const AsyncValue.data(null);
      return launched;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    state = const AsyncValue.loading();
    try {
      final launched = await _repo.signInWithApple();
      state = const AsyncValue.data(null);
      return launched;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.signOut();
  }
}

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
