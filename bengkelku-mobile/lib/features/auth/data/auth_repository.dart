import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";

/// Hasil pendaftaran akun.
enum SignUpResult {
  /// Sesi langsung aktif (konfirmasi email dimatikan di Supabase).
  signedIn,

  /// Akun dibuat, pengguna harus membuka tautan konfirmasi di email.
  needsEmailConfirmation,
}

/// Repository untuk Supabase Auth & profil pengguna.
class AuthRepository {
  SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => SupabaseService.currentUser;
  bool get isLoggedIn => SupabaseService.isLoggedIn;

  /// Sign in dengan email & password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up akun baru pengendara
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: SupabaseService.authRedirectUrl,
      data: {
        "full_name": fullName,
      },
    );

    // Supabase mengembalikan user dengan identities kosong bila email
    // sudah terdaftar (perlindungan enumerasi email).
    final identities = res.user?.identities;
    if (res.user != null && identities != null && identities.isEmpty) {
      throw const AuthException(
        "User already registered",
        code: "user_already_exists",
      );
    }

    return res.session != null
        ? SignUpResult.signedIn
        : SignUpResult.needsEmailConfirmation;
  }

  /// Kirim ulang email konfirmasi pendaftaran.
  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: SupabaseService.authRedirectUrl,
    );
  }

  /// Sign in dengan Google via Supabase OAuth
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseService.authRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Sign in dengan Apple via Supabase OAuth (Diwajibkan untuk iOS)
  Future<bool> signInWithApple() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: SupabaseService.authRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  /// Kirim email reset password. Tautan di email membuka aplikasi lewat
  /// deep link → event passwordRecovery → layar atur kata sandi baru.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseService.authRedirectUrl,
    );
  }

  /// Simpan kata sandi baru (dipakai setelah tautan reset dibuka).
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Logout
  Future<void> signOut() async {
    try {
      // Sesi lokal dihapus lebih dulu oleh SDK, jadi pengguna tetap keluar
      // walau panggilan jaringan gagal (offline).
      await _client.auth.signOut();
    } catch (_) {}
  }

  /// Ambil profil dari tabel public.users
  Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    final response =
        await _client.from("users").select().eq("id", uid).maybeSingle();
    return response;
  }

  /// Update data profil pengguna
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? timezone,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;

    final updates = <String, dynamic>{
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    };
    if (fullName != null) updates["full_name"] = fullName;
    if (phone != null) updates["phone"] = phone;
    if (avatarUrl != null) updates["avatar_url"] = avatarUrl;
    if (timezone != null) updates["timezone"] = timezone;

    await _client.from("users").update(updates).eq("id", uid);
  }

  /// Hapus akun
  Future<void> deleteAccount() async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _client.from("users").delete().eq("id", uid);
    await signOut();
  }
}
