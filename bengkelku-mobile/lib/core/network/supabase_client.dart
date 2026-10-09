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

  /// Skema deep link untuk OAuth (Google/Apple), konfirmasi email & tautan
  /// reset kata sandi. Harus sama dengan AndroidManifest, Info.plist, dan
  /// "Redirect URLs" di Supabase Dashboard → Authentication → URL Configuration.
  static const String authRedirectUrl = "bengkelku://login-callback";

  static bool _ready = false;
  static Object? _initError;

  /// True bila SUPABASE_URL & SUPABASE_ANON_KEY terisi saat build.
  static bool get isConfigured =>
      _url.startsWith("http") && _anonKey.isNotEmpty;

  /// True bila Supabase berhasil diinisialisasi.
  static bool get isReady => _ready;

  /// Pesan kesalahan inisialisasi (null bila sukses).
  static Object? get initError => _initError;

  /// Panggil sekali saat startup. Tidak pernah melempar — kegagalan dicatat
  /// di [initError] agar aplikasi menampilkan pesan, bukan layar putih.
  static Future<void> init() async {
    if (!isConfigured) {
      _initError = "SUPABASE_URL / SUPABASE_ANON_KEY kosong. "
          "Build ulang dengan --dart-define-from-file=.env";
      return;
    }
    try {
      await Supabase.initialize(
        url: _url,
        // ignore: deprecated_member_use
        anonKey: _anonKey,
        // Default: alur PKCE + auto refresh token + deteksi sesi dari deep link.
      );
      _ready = true;
    } catch (e) {
      _initError = e;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static User? get currentUser => _ready ? auth.currentUser : null;
  static bool get isLoggedIn => _ready && auth.currentSession != null;
}
