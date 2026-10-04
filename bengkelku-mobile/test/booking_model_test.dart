import "package:bengkelku/features/booking/data/booking_model.dart";
import "package:bengkelku/features/booking/data/booking_repository.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("Booking.fromDetail parses RPC booking_detail payload", () {
    final b = Booking.fromDetail({
      "id": "a1b2c3d4-0000-0000-0000-000000000000",
      "rider_id": "r",
      "workshop_id": "w",
      "status": "MENUNGGU_PEMBAYARAN",
      "scheduled_at": "2030-01-02T02:00:00+00:00",
      "subtotal_idr": 120000,
      "total_idr": 122000.0,
      "payment_deadline": "2030-01-01T03:00:00+00:00",
      "workshop": {"name": "Jaya Motor", "address": "Jl. A"},
      "vehicle": {"brand": "Honda", "model": "Vario", "plate": "B 1 X"},
      "items": [
        {"id": "i1", "name": "Servis", "price_idr": 120000, "is_addon": false},
      ],
      "refund": null,
    });
    expect(b.code, "BK-A1B2C3");
    expect(b.totalIdr, 122000);
    expect(b.workshopName, "Jaya Motor");
    expect(b.vehicleInfo, contains("Vario"));
    expect(b.items.single.priceIdr, 120000);
    expect(b.canCancel, isTrue);
    expect(b.isActive, isTrue);
  });

  test("status lifecycle helpers", () {
    Booking mk(String s) => Booking.fromJson({
          "id": "x",
          "status": s,
          "scheduled_at": "2030-01-02T02:00:00Z",
        });
    expect(mk("DIKERJAKAN").canCancel, isFalse);
    expect(mk("DIKERJAKAN").isActive, isTrue);
    expect(mk("SELESAI").isActive, isFalse);
    expect(mk("DIBATALKAN").canCancel, isFalse);
  });

  test("BookingSlot.fromJson", () {
    final s = BookingSlot.fromJson(
        {"slot_at": "2030-01-02T01:00:00Z", "label": "08:00", "remaining": 0});
    expect(s.available, isFalse);
    expect(s.label, "08:00");
  });
}
