import "package:supabase_flutter/supabase_flutter.dart";

/// Satu-satunya titik akses Supabase di aplikasi.
/// Inisialisasi dipanggil sekali di main.dart sebelum runApp.
///
/// URL & anon key diinjeksi via --dart-define-from-file=.env:
///   SUPABASE_URL, SUPABASE_ANON_KEY
///
/// Keamanan: andalkan Row Level Security di sisi DB, JANGAN filter klien.
class SupabaseService {
  SupabaseService._();

  static const String _url = String.fromEnvironment("SUPABASE_URL");
  static const String _anonKey = String.fromEnvironment("SUPABASE_ANON_KEY");

  /// Panggil sekali saat startup.
  static Future<void> init() async {
    assert(_url.isNotEmpty, "SUPABASE_URL kosong — jalankan dengan --dart-define-from-file=.env");
    assert(_anonKey.isNotEmpty, "SUPABASE_ANON_KEY kosong — cek .env");
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
}
