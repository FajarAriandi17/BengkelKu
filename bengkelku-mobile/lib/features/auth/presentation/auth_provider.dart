import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../data/auth_repository.dart";

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return await repo.getProfile();
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repo) : super(const AsyncValue.data(null));

  final AuthRepository _repo;

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

  Future<bool> register(String email, String password, String fullName) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final success = await _repo.signInWithGoogle();
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> loginWithApple() async {
    state = const AsyncValue.loading();
    try {
      final success = await _repo.signInWithApple();
      state = const AsyncValue.data(null);
      return success;
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
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
