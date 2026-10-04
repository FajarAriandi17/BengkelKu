// Quote (Penawaran Biaya) Models - sesuai PRD v1.3 Section 4

import 'package:equatable/equatable.dart';

enum QuoteState {
  sent,
  approved,
  rejected,
  expired,
  superseded,
}

enum QuoteItemType {
  jasa,
  sparepart,
}

class QuoteItem extends Equatable {
  final String name;
  final QuoteItemType type;
  final int price;

  const QuoteItem({
    required this.name,
    required this.type,
    required this.price,
  });

  factory QuoteItem.fromJson(Map<String, dynamic> json) {
    return QuoteItem(
      name: json['name'] as String,
      type: QuoteItemType.values.byName(json['type'] as String),
      price: json['price'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'price': price,
    };
  }

  @override
  List<Object?> get props => [name, type, price];
}

class Quote extends Equatable {
  final String id;
  final String? bookingId;
  final String? sosRequestId;
  final String workshopId;
  final List<QuoteItem> items;
  final String? note;
  final List<String> photos;
  final int total;
  final QuoteState state;
  final DateTime expiresAt;
  final int revision;
  final DateTime? approvedAt;
  final DateTime createdAt;

  // Join data
  final String? workshopName;
  final String? workshopAvatar;

  const Quote({
    required this.id,
    this.bookingId,
    this.sosRequestId,
    required this.workshopId,
    required this.items,
    this.note,
    this.photos = const [],
    required this.total,
    required this.state,
    required this.expiresAt,
    this.revision = 0,
    this.approvedAt,
    required this.createdAt,
    this.workshopName,
    this.workshopAvatar,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>;
    final items = itemsList.map((item) => QuoteItem.fromJson(item)).toList();

    return Quote(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String?,
      sosRequestId: json['sos_request_id'] as String?,
      workshopId: json['workshop_id'] as String,
      items: items,
      note: json['note'] as String?,
      photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
      total: json['total'] as int,
      state: QuoteState.values.byName(json['state'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      revision: json['revision'] as int? ?? 0,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      workshopName: json['workshop_name'] as String?,
      workshopAvatar: json['workshop_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'sos_request_id': sosRequestId,
      'workshop_id': workshopId,
      'items': items.map((item) => item.toJson()).toList(),
      'note': note,
      'photos': photos,
      'total': total,
      'state': state.name,
      'expires_at': expiresAt.toIso8601String(),
      'revision': revision,
      'approved_at': approvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isPending => state == QuoteState.sent;
  bool get isApproved => state == QuoteState.approved;
  bool get isRejected => state == QuoteState.rejected;
  bool get isExpired => state == QuoteState.expired || DateTime.now().isAfter(expiresAt);
  bool get canRespond => isPending && !isExpired;

  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  int get serviceTotal {
    return items
        .where((item) => item.type == QuoteItemType.jasa)
        .fold(0, (sum, item) => sum + item.price);
  }

  int get partsTotal {
    return items
        .where((item) => item.type == QuoteItemType.sparepart)
        .fold(0, (sum, item) => sum + item.price);
  }

  @override
  List<Object?> get props => [
        id,
        bookingId,
        sosRequestId,
        items,
        total,
        state,
        revision,
      ];
}

// Helper untuk membuat penawaran baru
class QuoteCreateRequest {
  final String? bookingId;
  final String? sosRequestId;
  final List<QuoteItem> items;
  final String? note;
  final List<String> photos;

  const QuoteCreateRequest({
    this.bookingId,
    this.sosRequestId,
    required this.items,
    this.note,
    this.photos = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'sos_request_id': sosRequestId,
      'items': items.map((item) => item.toJson()).toList(),
      'note': note,
      'photos': photos,
    };
  }

  int get total {
    return items.fold(0, (sum, item) => sum + item.price);
  }
}
