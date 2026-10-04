// Pusat Bantuan & laporan masalah (Fitur F, PRD v1.3 Bagian 7).
// Sesuai 0014_support.sql (+ 0019, 0020).

// Nama enum mengikuti enum Postgres (support_category / support_state).
// ignore_for_file: constant_identifier_names

import 'package:equatable/equatable.dart';

enum SupportCategory {
  BENGKEL_TIDAK_DATANG,
  HARGA_TIDAK_SESUAI,
  KERUSAKAN_SETELAH_SERVIS,
  REFUND_BELUM_MASUK,
  PERILAKU_TIDAK_PANTAS,
  LAINNYA,
}

extension SupportCategoryX on SupportCategory {
  String get label => switch (this) {
        SupportCategory.BENGKEL_TIDAK_DATANG => 'Bengkel tidak datang',
        SupportCategory.HARGA_TIDAK_SESUAI => 'Harga tidak sesuai',
        SupportCategory.KERUSAKAN_SETELAH_SERVIS => 'Kerusakan setelah servis',
        SupportCategory.REFUND_BELUM_MASUK => 'Refund belum masuk',
        SupportCategory.PERILAKU_TIDAK_PANTAS => 'Perilaku tidak pantas',
        SupportCategory.LAINNYA => 'Lainnya',
      };

  /// PRD 7: laporan harga/kerusakan menahan payout bagian terkait.
  bool get holdsPayout =>
      this == SupportCategory.HARGA_TIDAK_SESUAI ||
      this == SupportCategory.KERUSAKAN_SETELAH_SERVIS;

  static SupportCategory parse(String? v) => SupportCategory.values
      .firstWhere((e) => e.name == v, orElse: () => SupportCategory.LAINNYA);
}

enum SupportState { DITERIMA, DITINJAU, MENUNGGU_INFO, SELESAI }

extension SupportStateX on SupportState {
  String get label => switch (this) {
        SupportState.DITERIMA => 'Diterima',
        SupportState.DITINJAU => 'Ditinjau',
        SupportState.MENUNGGU_INFO => 'Menunggu info darimu',
        SupportState.SELESAI => 'Selesai',
      };

  bool get canReply => this != SupportState.SELESAI;

  static SupportState parse(String? v) => SupportState.values
      .firstWhere((e) => e.name == v, orElse: () => SupportState.DITERIMA);
}

class SupportTicket extends Equatable {
  const SupportTicket({
    required this.id,
    required this.code,
    required this.category,
    required this.description,
    this.photos = const [],
    required this.state,
    this.bookingId,
    this.sosRequestId,
    this.threadId,
    this.decision,
    this.decisionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final SupportCategory category;
  final String description;
  final List<String> photos;
  final SupportState state;
  final String? bookingId;
  final String? sosRequestId;
  final String? threadId;
  final String? decision;
  final String? decisionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        category: SupportCategoryX.parse(j['category'] as String?),
        description: j['description'] as String? ?? '',
        photos: (j['photos'] as List?)?.cast<String>() ?? const [],
        state: SupportStateX.parse(j['state'] as String?),
        bookingId: j['booking_id'] as String?,
        sosRequestId: j['sos_request_id'] as String?,
        threadId: j['thread_id'] as String?,
        decision: j['decision'] as String?,
        decisionReason: j['decision_reason'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt:
            DateTime.parse((j['updated_at'] ?? j['created_at']) as String),
      );

  String? get relatedLabel {
    if (sosRequestId != null) return 'Panggilan darurat';
    if (bookingId != null) return 'Booking';
    if (threadId != null) return 'Chat';
    return null;
  }

  @override
  List<Object?> get props => [id, state, updatedAt, decision];
}

class SupportMessage extends Equatable {
  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.fromAdmin,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String senderId;
  final bool fromAdmin;
  final String body;
  final DateTime createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['id'] as String,
        ticketId: j['ticket_id'] as String,
        senderId: j['sender_id'] as String,
        fromAdmin: j['from_admin'] as bool? ?? false,
        body: j['body'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  @override
  List<Object?> get props => [id];
}

class FaqItem extends Equatable {
  const FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  /// Dari `app_config.support_faq` — [{q, a}] (juga menerima {title, body}).
  static List<FaqItem> parse(Object? raw) {
    if (raw is! List) return const [];
    final out = <FaqItem>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final q = (e['q'] ?? e['title'])?.toString().trim() ?? '';
      final a = (e['a'] ?? e['body'])?.toString().trim() ?? '';
      if (q.isNotEmpty && a.isNotEmpty) {
        out.add(FaqItem(question: q, answer: a));
      }
    }
    return out;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return question.toLowerCase().contains(q) ||
        answer.toLowerCase().contains(q);
  }

  @override
  List<Object?> get props => [question, answer];
}

/// Batas formulir laporan (PRD 7). Server memvalidasi ulang (0020).
class SupportLimits {
  SupportLimits._();
  static const int minDescription = 10;
  static const int maxDescription = 1000;
  static const int maxPhotos = 3;
}

/// Validasi formulir laporan. null bila siap dikirim.
String? validateSupportReport({
  required SupportCategory? category,
  required String description,
  int photoCount = 0,
}) {
  if (category == null) return 'pilih kategori masalah';
  final d = description.trim();
  if (d.length < SupportLimits.minDescription) {
    return 'ceritakan masalahnya minimal ${SupportLimits.minDescription} karakter';
  }
  if (d.length > SupportLimits.maxDescription) {
    return 'deskripsi maksimal 1.000 karakter';
  }
  if (photoCount > SupportLimits.maxPhotos) {
    return 'maksimal ${SupportLimits.maxPhotos} foto';
  }
  return null;
}
