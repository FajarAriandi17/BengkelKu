import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";

/// Repository untuk Supabase Auth & profil pengguna.
class AuthRepository {
  SupabaseClient get _client => SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

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
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        "full_name": fullName,
      },
    );
  }

  /// Sign in dengan Google via Supabase OAuth
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: "bengkelku://login-callback",
    );
  }

  /// Sign in dengan Apple via Supabase OAuth (Diwajibkan untuk iOS)
  Future<bool> signInWithApple() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: "bengkelku://login-callback",
    );
  }

  /// Kirim email reset password
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Logout
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Ambil profil dari tabel public.users
  Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    final response = await _client
        .from("users")
        .select()
        .eq("id", uid)
        .maybeSingle();
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
