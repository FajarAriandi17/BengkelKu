// Chat Models - sesuai PRD v1.3 Section 2

import 'package:equatable/equatable.dart';

enum ChatThreadType { booking, sos }

enum ChatThreadState { open, readonly }

enum MessageKind { text, image, system, quote, location }

class ChatThread extends Equatable {
  final String id;
  final ChatThreadType type;
  final String? bookingId;
  final String? sosRequestId;
  final String riderId;
  final String workshopId;
  final ChatThreadState state;
  final DateTime lastMessageAt;
  final int riderUnread;
  final int workshopUnread;
  final String? lastMessageText;
  final String? workshopName;
  final String? workshopAvatar;
  final bool isDarurat;

  const ChatThread({
    required this.id,
    required this.type,
    this.bookingId,
    this.sosRequestId,
    required this.riderId,
    required this.workshopId,
    required this.state,
    required this.lastMessageAt,
    this.riderUnread = 0,
    this.workshopUnread = 0,
    this.lastMessageText,
    this.workshopName,
    this.workshopAvatar,
    this.isDarurat = false,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      type: ChatThreadType.values.byName(json['type'] as String),
      bookingId: json['booking_id'] as String?,
      sosRequestId: json['sos_request_id'] as String?,
      riderId: json['rider_id'] as String,
      workshopId: json['workshop_id'] as String,
      state: ChatThreadState.values.byName(json['state'] as String),
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      riderUnread: json['rider_unread'] as int? ?? 0,
      workshopUnread: json['workshop_unread'] as int? ?? 0,
      lastMessageText: json['last_message_text'] as String?,
      workshopName: json['workshop_name'] as String?,
      workshopAvatar: json['workshop_avatar'] as String?,
      isDarurat: json['type'] == 'sos',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'booking_id': bookingId,
      'sos_request_id': sosRequestId,
      'rider_id': riderId,
      'workshop_id': workshopId,
      'state': state.name,
      'last_message_at': lastMessageAt.toIso8601String(),
      'rider_unread': riderUnread,
      'workshop_unread': workshopUnread,
    };
  }

  bool get canSend => state == ChatThreadState.open;

  @override
  List<Object?> get props => [
        id,
        type,
        bookingId,
        sosRequestId,
        riderId,
        workshopId,
        state,
        lastMessageAt,
        riderUnread,
        workshopUnread,
      ];
}

class ChatMessage extends Equatable {
  final String id;
  final String threadId;
  final String senderId;
  final MessageKind kind;
  final String? body;
  final List<String> mediaPaths;
  final String? quoteId;
  final double? latitude;
  final double? longitude;
  final String clientId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMine;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.kind,
    this.body,
    this.mediaPaths = const [],
    this.quoteId,
    this.latitude,
    this.longitude,
    required this.clientId,
    required this.createdAt,
    this.readAt,
    this.isMine = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {required String currentUserId}) {
    return ChatMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderId: json['sender_id'] as String,
      kind: MessageKind.values.byName(json['kind'] as String),
      body: json['body'] as String?,
      mediaPaths: (json['media_paths'] as List<dynamic>?)?.cast<String>() ?? [],
      quoteId: json['quote_id'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      clientId: json['client_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      isMine: json['sender_id'] == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thread_id': threadId,
      'sender_id': senderId,
      'kind': kind.name,
      'body': body,
      'media_paths': mediaPaths,
      'quote_id': quoteId,
      'latitude': latitude,
      'longitude': longitude,
      'client_id': clientId,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  bool get isRead => readAt != null;

  @override
  List<Object?> get props => [
        id,
        threadId,
        senderId,
        kind,
        body,
        mediaPaths,
        quoteId,
        latitude,
        longitude,
        clientId,
        createdAt,
        readAt,
      ];
}

class QuickReply {
  final String text;
  final bool isForWorkshop;

  const QuickReply(this.text, {this.isForWorkshop = false});
}

// Quick replies sesuai PRD Section 2.1
class QuickReplies {
  static const workshopReplies = [
    QuickReply('Sudah saya terima', isForWorkshop: true),
    QuickReply('Saya berangkat ke lokasi', isForWorkshop: true),
    QuickReply('Bisa kirim foto kerusakannya?', isForWorkshop: true),
  ];

  static const riderReplies = [
    QuickReply('Saya sudah di lokasi'),
    QuickReply('Terima kasih'),
  ];

  static QuickReply estimatedArrival(int minutes) =>
      QuickReply('Estimasi tiba $minutes menit', isForWorkshop: true);

  static QuickReply exactLocation(String landmark) =>
      QuickReply('Posisi tepatnya di seberang $landmark');
}
