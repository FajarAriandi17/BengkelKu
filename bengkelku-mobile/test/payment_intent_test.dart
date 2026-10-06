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
        "method": "qris",
        "expires_at": "2026-10-06T12:00:00.000Z",
        "invoice_url": "https://xendit.co/i/1",
        "qr_string": "00020101QRIS",
      });

      expect(intent.providerRef, "bk-abc123");
      expect(intent.amountIdr, 120000);
      expect(intent.method, "qris");
      expect(intent.invoiceUrl, "https://xendit.co/i/1");
      expect(intent.qrString, "00020101QRIS");
      expect(intent.expiresAt, isNotNull);
    });

    test("showsQr hanya untuk QRIS yang punya qr_string", () {
      expect(
        const PaymentIntent(
          providerRef: "r1",
          amountIdr: 1000,
          method: "qris",
          qrString: "00020101",
        ).showsQr,
        isTrue,
      );
      expect(
        const PaymentIntent(
          providerRef: "r2",
          amountIdr: 1000,
          method: "va",
          qrString: "00020101",
        ).showsQr,
        isFalse,
      );
      expect(
        const PaymentIntent(
          providerRef: "r3",
          amountIdr: 1000,
          method: "qris",
        ).showsQr,
        isFalse,
      );
    });

    test("null aman: nilai default dipakai", () {
      final intent = PaymentIntent.fromJson({});
      expect(intent.providerRef, "");
      expect(intent.amountIdr, 0);
      expect(intent.method, "qris");
      expect(intent.expiresAt, isNull);
      expect(intent.showsQr, isFalse);
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
