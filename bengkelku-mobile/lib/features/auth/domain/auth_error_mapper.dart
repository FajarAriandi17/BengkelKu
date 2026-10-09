import "dart:async";

import "package:supabase_flutter/supabase_flutter.dart";

/// Ubah error Supabase Auth / jaringan menjadi pesan Bahasa Indonesia yang
/// ramah, alih-alih menampilkan "Gagal: AuthApiException(...)" mentah.
String authErrorMessage(Object error) {
  if (error is AuthException) {
    final code = (error.code ?? "").toLowerCase();
    final msg = error.message.toLowerCase();

    if (code == "invalid_credentials" ||
        msg.contains("invalid login credentials")) {
      return "email atau kata sandi salah";
    }
    if (code == "email_not_confirmed" || msg.contains("email not confirmed")) {
      return "email belum dikonfirmasi. cek kotak masuk kamu lalu buka tautan konfirmasi";
    }
    if (code == "user_already_exists" ||
        code == "email_exists" ||
        msg.contains("already registered")) {
      return "email ini sudah terdaftar. silakan masuk";
    }
    if (code == "weak_password" || msg.contains("password should be")) {
      return "kata sandi terlalu lemah. minimal 6 karakter";
    }
    if (code == "same_password") {
      return "kata sandi baru harus berbeda dari yang lama";
    }
    if (code == "over_email_send_rate_limit" ||
        code == "over_request_rate_limit" ||
        error.statusCode == "429" ||
        msg.contains("rate limit")) {
      return "terlalu banyak percobaan. tunggu beberapa menit lalu coba lagi";
    }
    if (code == "validation_failed" ||
        msg.contains("unable to validate email")) {
      return "format email tidak valid";
    }
    if (code == "signup_disabled") {
      return "pendaftaran sedang ditutup";
    }
    if (code == "provider_disabled" ||
        msg.contains("provider is not enabled")) {
      return "metode masuk ini belum diaktifkan";
    }
    if (code == "otp_expired" || msg.contains("expired")) {
      return "tautan sudah kedaluwarsa. minta tautan baru";
    }
    if (error is AuthRetryableFetchException) {
      return "tidak dapat terhubung ke server. periksa koneksi internet kamu";
    }
    return error.message;
  }
  if (error is TimeoutException) {
    return "tidak dapat terhubung ke server. periksa koneksi internet kamu";
  }
  final text = error.toString();
  if (text.contains("SocketException") ||
      text.contains("Failed host lookup") ||
      text.contains("ClientException") ||
      text.contains("XMLHttpRequest")) {
    return "tidak dapat terhubung ke server. periksa koneksi internet kamu";
  }
  return "terjadi kesalahan. coba lagi";
}

final _emailRe = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$");

/// Validasi email sederhana; null bila valid.
String? validateEmail(String email) {
  if (email.isEmpty) return "email wajib diisi";
  if (!_emailRe.hasMatch(email)) return "format email tidak valid";
  return null;
}

/// Validasi kata sandi (aturan default Supabase: minimal 6 karakter).
String? validatePassword(String password) {
  if (password.isEmpty) return "kata sandi wajib diisi";
  if (password.length < 6) return "kata sandi minimal 6 karakter";
  return null;
}
