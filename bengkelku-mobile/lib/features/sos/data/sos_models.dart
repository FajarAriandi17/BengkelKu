// SOS (Emergency) Models - sesuai PRD v1.3 Section 3

import 'package:equatable/equatable.dart';

enum SosStatus {
  MENUNGGU_PEMBAYARAN,
  MENCARI_BENGKEL,
  DITERIMA,
  MENUJU_LOKASI,
  TIBA,
  MEMERIKSA,
  DIKERJAKAN,
  SELESAI,
  SELESAI_TANPA_PERBAIKAN,
  DIBATALKAN,
  KEDALUWARSA,
  TIDAK_ADA_BENGKEL,
}

enum SosProblem {
  ENGINE_DEAD,
  FLAT_TIRE,
  DEAD_BATTERY,
  OUT_OF_FUEL,
  BRAKE_ISSUE,
  OTHER,
}

extension SosProblemExt on SosProblem {
  String get label {
    switch (this) {
      case SosProblem.ENGINE_DEAD:
        return 'Mesin mati';
      case SosProblem.FLAT_TIRE:
        return 'Ban bocor';
      case SosProblem.DEAD_BATTERY:
        return 'Aki tekor';
      case SosProblem.OUT_OF_FUEL:
        return 'Bensin habis';
      case SosProblem.BRAKE_ISSUE:
        return 'Rem bermasalah';
      case SosProblem.OTHER:
        return 'Lainnya';
    }
  }
}

class SosRequest extends Equatable {
  final String id;
  final String code;
  final String riderId;
  final SosStatus status;
  final String problemCode;
  final String? problemNote;
  final List<String> photos;
  final double lat;
  final double lng;
  final double accuracyM;
  final String? landmark;
  final int tier;
  final int callFee;
  final int nightFee;
  final int serviceFee;
  final int total;
  final double commissionRate;
  final DateTime? paymentExpiresAt;
  final String? acceptedWorkshopId;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final String? arrivalCode;
  final int wave;
  final String? endedReason;
  final int refundPercent;
  final DateTime createdAt;

  // Join data
  final String? workshopName;
  final String? mechanicName;
  final String? mechanicPhoto;
  final String? mechanicPlate;
  final double? workshopRating;

  const SosRequest({
    required this.id,
    required this.code,
    required this.riderId,
    required this.status,
    required this.problemCode,
    this.problemNote,
    this.photos = const [],
    required this.lat,
    required this.lng,
    required this.accuracyM,
    this.landmark,
    required this.tier,
    required this.callFee,
    required this.nightFee,
    required this.serviceFee,
    required this.total,
    required this.commissionRate,
    this.paymentExpiresAt,
    this.acceptedWorkshopId,
    this.acceptedAt,
    this.arrivedAt,
    this.arrivalCode,
    this.wave = 1,
    this.endedReason,
    this.refundPercent = 0,
    required this.createdAt,
    this.workshopName,
    this.mechanicName,
    this.mechanicPhoto,
    this.mechanicPlate,
    this.workshopRating,
  });

  factory SosRequest.fromJson(Map<String, dynamic> json) {
    return SosRequest(
      id: json['id'] as String,
      code: json['code'] as String,
      riderId: json['rider_id'] as String,
      status: SosStatus.values.byName(json['status'] as String),
      problemCode: json['problem_code'] as String,
      problemNote: json['problem_note'] as String?,
      photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyM: (json['accuracy_m'] as num).toDouble(),
      landmark: json['landmark'] as String?,
      tier: json['tier'] as int,
      callFee: json['call_fee'] as int,
      nightFee: json['night_fee'] as int,
      serviceFee: json['service_fee'] as int,
      total: json['total'] as int,
      commissionRate: (json['commission_rate'] as num).toDouble(),
      paymentExpiresAt: json['payment_expires_at'] != null
          ? DateTime.parse(json['payment_expires_at'] as String)
          : null,
      acceptedWorkshopId: json['accepted_workshop_id'] as String?,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      arrivalCode: json['arrival_code'] as String?,
      wave: json['wave'] as int? ?? 1,
      endedReason: json['ended_reason'] as String?,
      refundPercent: json['refund_percent'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      workshopName: json['workshop_name'] as String?,
      mechanicName: json['mechanic_name'] as String?,
      mechanicPhoto: json['mechanic_photo'] as String?,
      mechanicPlate: json['mechanic_plate'] as String?,
      workshopRating: json['workshop_rating'] != null
          ? (json['workshop_rating'] as num).toDouble()
          : null,
    );
  }

  bool get isActive => [
        SosStatus.MENUNGGU_PEMBAYARAN,
        SosStatus.MENCARI_BENGKEL,
        SosStatus.DITERIMA,
        SosStatus.MENUJU_LOKASI,
        SosStatus.TIBA,
        SosStatus.MEMERIKSA,
        SosStatus.DIKERJAKAN,
      ].contains(status);

  /// Label tier untuk tampilan (mengikuti nilai bawaan app_config PRD 3.5).
  String get tierLabel {
    switch (tier) {
      case 1:
        return '≤ 3 km';
      case 2:
        return '> 3 sampai 6 km';
      case 3:
        return '> 6 sampai 10 km';
      case 4:
        return '> 10 sampai 15 km';
      default:
        return 'Tier $tier';
    }
  }

  bool get canCancel => [
        SosStatus.MENUNGGU_PEMBAYARAN,
        SosStatus.MENCARI_BENGKEL,
        SosStatus.DITERIMA,
        SosStatus.MENUJU_LOKASI,
      ].contains(status);

  bool get needsPayment => status == SosStatus.MENUNGGU_PEMBAYARAN;

  @override
  List<Object?> get props => [
        id,
        code,
        riderId,
        status,
        acceptedWorkshopId,
        acceptedAt,
        arrivedAt,
      ];
}

class SosOffer extends Equatable {
  final String id;
  final String requestId;
  final String workshopId;
  final int wave;
  final int distanceM;
  final int etaMin;
  final String state;
  final DateTime sentAt;
  final DateTime expiresAt;

  const SosOffer({
    required this.id,
    required this.requestId,
    required this.workshopId,
    required this.wave,
    required this.distanceM,
    required this.etaMin,
    required this.state,
    required this.sentAt,
    required this.expiresAt,
  });

  factory SosOffer.fromJson(Map<String, dynamic> json) {
    return SosOffer(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      workshopId: json['workshop_id'] as String,
      wave: json['wave'] as int,
      distanceM: json['distance_m'] as int,
      etaMin: json['eta_min'] as int,
      state: json['state'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, requestId, workshopId, state];
}

class MechanicLocation extends Equatable {
  final double lat;
  final double lng;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;

  const MechanicLocation({
    required this.lat,
    required this.lng,
    this.speed,
    this.heading,
    required this.recordedAt,
  });

  factory MechanicLocation.fromJson(Map<String, dynamic> json) {
    return MechanicLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      heading:
          json['heading'] != null ? (json['heading'] as num).toDouble() : null,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

  @override
  List<Object?> get props => [lat, lng, recordedAt];
}

// Tier biaya sesuai PRD Section 3.5
class SosFeeCalculation {
  final int tier;
  final int callFee;
  final int nightFee;
  final int serviceFee;
  final int total;
  final String tierLabel;

  const SosFeeCalculation({
    required this.tier,
    required this.callFee,
    required this.nightFee,
    required this.serviceFee,
    required this.total,
    required this.tierLabel,
  });

  factory SosFeeCalculation.fromJson(Map<String, dynamic> json) {
    return SosFeeCalculation(
      tier: json['tier'] as int,
      callFee: json['call_fee'] as int,
      nightFee: json['night_fee'] as int,
      serviceFee: json['service_fee'] as int,
      total: json['total'] as int,
      tierLabel: json['tier_label'] as String,
    );
  }
}

// Workshop standby sesuai PRD Section 3.3
class WorkshopStandby extends Equatable {
  final String workshopId;
  final bool emergencyReady;
  final bool afterHours;
  final int radiusTierMax;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastSeenAt;
  final double acceptRate;

  const WorkshopStandby({
    required this.workshopId,
    required this.emergencyReady,
    this.afterHours = false,
    required this.radiusTierMax,
    this.lastLat,
    this.lastLng,
    this.lastSeenAt,
    this.acceptRate = 1.0,
  });

  factory WorkshopStandby.fromJson(Map<String, dynamic> json) {
    return WorkshopStandby(
      workshopId: json['workshop_id'] as String,
      emergencyReady: json['emergency_ready'] as bool,
      afterHours: json['after_hours'] as bool? ?? false,
      radiusTierMax: json['radius_tier_max'] as int,
      lastLat: json['last_lat'] != null
          ? (json['last_lat'] as num).toDouble()
          : null,
      lastLng: json['last_lng'] != null
          ? (json['last_lng'] as num).toDouble()
          : null,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
      acceptRate: json['accept_rate'] != null
          ? (json['accept_rate'] as num).toDouble()
          : 1.0,
    );
  }

  @override
  List<Object?> get props => [
        workshopId,
        emergencyReady,
        lastLat,
        lastLng,
        lastSeenAt,
      ];
}
