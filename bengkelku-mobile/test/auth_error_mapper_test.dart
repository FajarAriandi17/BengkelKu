import "package:bengkelku/features/auth/domain/auth_error_mapper.dart";
import "package:flutter_test/flutter_test.dart";
import "package:supabase_flutter/supabase_flutter.dart";

void main() {
  group("authErrorMessage", () {
    test("kredensial salah", () {
      expect(
        authErrorMessage(
          const AuthApiException(
            "Invalid login credentials",
            statusCode: "400",
            code: "invalid_credentials",
          ),
        ),
        "email atau kata sandi salah",
      );
    });

    test("email belum dikonfirmasi", () {
      expect(
        authErrorMessage(
          const AuthApiException(
            "Email not confirmed",
            statusCode: "400",
            code: "email_not_confirmed",
          ),
        ),
        startsWith("email belum dikonfirmasi"),
      );
    });

    test("email sudah terdaftar", () {
      expect(
        authErrorMessage(
          const AuthException(
            "User already registered",
            code: "user_already_exists",
          ),
        ),
        "email ini sudah terdaftar. silakan masuk",
      );
    });

    test("rate limit", () {
      expect(
        authErrorMessage(
          const AuthApiException(
            "Email rate limit exceeded",
            statusCode: "429",
            code: "over_email_send_rate_limit",
          ),
        ),
        startsWith("terlalu banyak percobaan"),
      );
    });

    test("jaringan putus", () {
      expect(
        authErrorMessage(Exception("SocketException: Failed host lookup")),
        startsWith("tidak dapat terhubung ke server"),
      );
    });

    test("error tak dikenal tidak membocorkan detail teknis", () {
      expect(
        authErrorMessage(StateError("boom")),
        "terjadi kesalahan. coba lagi",
      );
    });
  });

  group("validasi", () {
    test("email", () {
      expect(validateEmail(""), "email wajib diisi");
      expect(validateEmail("budi"), "format email tidak valid");
      expect(validateEmail("budi@mail"), "format email tidak valid");
      expect(validateEmail("budi@mail.com"), isNull);
    });

    test("kata sandi", () {
      expect(validatePassword(""), "kata sandi wajib diisi");
      expect(validatePassword("12345"), "kata sandi minimal 6 karakter");
      expect(validatePassword("123456"), isNull);
    });
  });
}
