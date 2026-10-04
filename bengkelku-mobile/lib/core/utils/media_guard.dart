import "dart:io";

/// Pesan baku saat media melebihi batas. HARUS persis seperti ini
/// (jangan diubah huruf/kapital) sesuai kebutuhan produk FR-U1.
const String kMediaTooLargeMessage =
    "ukuran media anda terlalu besar segera kompres file media untuk melanjutkan";

/// Batas unggah media: 2 MB. Berlaku untuk KTP, selfie, foto lokasi/bengkel,
/// dan foto ulasan. Divalidasi di klien DAN di kebijakan bucket Supabase.
const int kMaxMediaBytes = 2 * 1024 * 1024; // 2.097.152

/// Dilempar saat berkas melebihi [kMaxMediaBytes].
class MediaTooLargeException implements Exception {
  const MediaTooLargeException([this.message = kMediaTooLargeMessage]);
  final String message;

  @override
  String toString() => message;
}

/// Penjaga ukuran media. Panggil SEBELUM setiap unggah.
///
/// Contoh:
/// ```dart
/// MediaGuard.ensureUnderLimit(await file.length());
/// // atau
/// await MediaGuard.ensureFileUnderLimit(file);
/// ```
class MediaGuard {
  MediaGuard._();

  /// true bila ukuran dalam batas.
  static bool isUnderLimit(int bytes) => bytes <= kMaxMediaBytes;

  /// Lempar [MediaTooLargeException] (pesan baku) bila melebihi batas.
  static void ensureUnderLimit(int bytes) {
    if (!isUnderLimit(bytes)) {
      throw const MediaTooLargeException();
    }
  }

  /// Varian untuk [File].
  static Future<void> ensureFileUnderLimit(File file) async {
    ensureUnderLimit(await file.length());
  }

  /// Varian untuk bytes di memori (mis. hasil kamera/picker).
  static void ensureBytesUnderLimit(List<int> bytes) {
    ensureUnderLimit(bytes.length);
  }
}
