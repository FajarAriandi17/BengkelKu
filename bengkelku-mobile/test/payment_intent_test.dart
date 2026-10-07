import "package:bengkelku/features/booking/data/booking_repository.dart";
import "package:flutter_test/flutter_test.dart";
import "package:supabase_flutter/supabase_flutter.dart";

void main() {
  group("PaymentIntent", () {
    test("fromJson memetakan field gateway", () {
      final intent = PaymentIntent.fromJson({
        "payment_id": "p1",
        "provider_ref": "bk-abc123",
        "amount_idr": 120000,
        "method": null,
        "expires_at": "2026-10-06T12:00:00.000Z",
        "invoice_url": "https://mayar.id/invoices/abc",
        "gateway_txn_id": "maya-txn-001",
      });

      expect(intent.providerRef, "bk-abc123");
      expect(intent.amountIdr, 120000);
      expect(intent.method, isNull);
      expect(intent.invoiceUrl, "https://mayar.id/invoices/abc");
      expect(intent.gatewayTxnId, "maya-txn-001");
      expect(intent.expiresAt, isNotNull);
    });

    test("kanal dari webhook tersimpan sebagai method", () {
      final intent = PaymentIntent.fromJson({
        "provider_ref": "bk-abc123",
        "amount_idr": 120000,
        "method": "qris",
      });
      expect(intent.method, "qris");
    });

    test("null aman: nilai default dipakai", () {
      final intent = PaymentIntent.fromJson({});
      expect(intent.providerRef, "");
      expect(intent.amountIdr, 0);
      expect(intent.method, isNull);
      expect(intent.invoiceUrl, isNull);
      expect(intent.gatewayTxnId, isNull);
      expect(intent.expiresAt, isNull);
    });
  });

  group("bookingErrorMessage", () {
    test("FunctionException mengambil pesan error gateway", () {
      const e = FunctionsHttpException(
        status: 400,
        details: {"error": "Batas waktu pembayaran sudah lewat"},
      );
      expect(bookingErrorMessage(e), "Batas waktu pembayaran sudah lewat");
    });

    test("PostgrestException memakai message", () {
      const e = PostgrestException(
        message: "Slot tidak tersedia",
        code: "P0001",
      );
      expect(bookingErrorMessage(e), "Slot tidak tersedia");
    });

    test("Exception biasa dibersihkan dari prefiks", () {
      expect(
        bookingErrorMessage(Exception("Booking tidak ditemukan")),
        "Booking tidak ditemukan",
      );
    });
  });
}
