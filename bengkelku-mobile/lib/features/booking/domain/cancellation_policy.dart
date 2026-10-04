/// Logika MURNI kebijakan pembatalan booking & pengembalian dana (refund).
///
/// Aturan PRD (Bagian 7):
/// - >= 2 jam sebelum slot  : refund 100%
/// - < 2 jam sebelum slot   : refund 50%
/// - No-show / lewat slot   : refund 0%
library;

class RefundCalculation {
  const RefundCalculation({
    required this.percentage,
    required this.refundAmountIdr,
    required this.explanation,
  });

  final double percentage; // 1.0, 0.5, 0.0
  final int refundAmountIdr;
  final String explanation;
}

RefundCalculation calculateRefund({
  required DateTime scheduledAt,
  required DateTime now,
  required int totalPaidIdr,
}) {
  final diffHours = scheduledAt.difference(now).inMinutes / 60.0;

  if (diffHours >= 2.0) {
    return RefundCalculation(
      percentage: 1.0,
      refundAmountIdr: totalPaidIdr,
      explanation: "Pembatalan >= 2 jam sebelum slot. Refund 100%.",
    );
  } else if (diffHours > 0.0) {
    final amount = (totalPaidIdr * 0.5).round();
    return RefundCalculation(
      percentage: 0.5,
      refundAmountIdr: amount,
      explanation: "Pembatalan < 2 jam sebelum slot. Refund 50%.",
    );
  } else {
    return const RefundCalculation(
      percentage: 0.0,
      refundAmountIdr: 0,
      explanation:
          "Waktu slot telah lewat atau Tidak Hadir (No-Show). Refund 0%.",
    );
  }
}
