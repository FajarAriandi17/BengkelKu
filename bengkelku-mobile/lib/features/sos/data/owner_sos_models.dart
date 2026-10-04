// Model sisi bengkel Bantuan Darurat (hasil RPC 0018/0019).

import 'package:equatable/equatable.dart';

import 'sos_models.dart';

/// Detail tawaran untuk layar ownerSosOffer (`sos_offer_details`).
/// Lokasi hanya area umum (dibulatkan ±300 m) — PRD 3.8.
class SosOfferDetails extends Equatable {
  const SosOfferDetails({
    required this.offerId,
    required this.requestId,
    required this.requestCode,
    required this.requestStatus,
    required this.state,
    required this.wave,
    required this.distanceM,
    required this.etaMin,
    required this.sentAt,
    required this.expiresAt,
    required this.problemCode,
    this.problemNote,
    this.photos = const [],
    required this.areaLat,
    required this.areaLng,
    required this.callFee,
    required this.nightFee,
    required this.commissionRate,
    required this.netEarnings,
  });

  final String offerId;
  final String requestId;
  final String requestCode;
  final String requestStatus;
  final String state;
  final int wave;
  final int distanceM;
  final int etaMin;
  final DateTime sentAt;
  final DateTime expiresAt;
  final String problemCode;
  final String? problemNote;
  final List<String> photos;
  final double areaLat;
  final double areaLng;
  final int callFee;
  final int nightFee;
  final double commissionRate;
  final int netEarnings;

  factory SosOfferDetails.fromJson(Map<String, dynamic> j) => SosOfferDetails(
        offerId: j['offer_id'] as String,
        requestId: j['request_id'] as String,
        requestCode: j['request_code'] as String? ?? '',
        requestStatus: j['request_status'] as String? ?? '',
        state: j['state'] as String? ?? 'sent',
        wave: (j['wave'] as num?)?.toInt() ?? 1,
        distanceM: (j['distance_m'] as num?)?.toInt() ?? 0,
        etaMin: (j['eta_min'] as num?)?.toInt() ?? 0,
        sentAt: DateTime.parse(j['sent_at'] as String),
        expiresAt: DateTime.parse(j['expires_at'] as String),
        problemCode: j['problem_code'] as String? ?? 'OTHER',
        problemNote: j['problem_note'] as String?,
        photos: (j['photos'] as List?)?.cast<String>() ?? const [],
        areaLat: (j['area_lat'] as num?)?.toDouble() ?? 0,
        areaLng: (j['area_lng'] as num?)?.toDouble() ?? 0,
        callFee: (j['call_fee'] as num?)?.toInt() ?? 0,
        nightFee: (j['night_fee'] as num?)?.toInt() ?? 0,
        commissionRate: (j['commission_rate'] as num?)?.toDouble() ?? 0.08,
        netEarnings: (j['net_earnings'] as num?)?.toInt() ?? 0,
      );

  String get problemLabel {
    final p = SosProblem.values.where((e) => e.name == problemCode);
    return p.isEmpty ? 'Lainnya' : p.first.label;
  }

  bool get isOpen => state == 'sent' && requestStatus == 'MENCARI_BENGKEL';

  @override
  List<Object?> get props => [offerId, state, requestStatus];
}

/// Bengkel milik pemilik saat ini (ringkas).
class OwnerWorkshop extends Equatable {
  const OwnerWorkshop({
    required this.id,
    required this.name,
    required this.status,
    required this.hasLocation,
  });

  final String id;
  final String name;
  final String status;
  final bool hasLocation;

  bool get isVerified => status == 'verified';

  factory OwnerWorkshop.fromJson(Map<String, dynamic> j) => OwnerWorkshop(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Bengkel',
        status: j['status'] as String? ?? 'draft',
        hasLocation: j['location'] != null,
      );

  @override
  List<Object?> get props => [id, status, hasLocation];
}
