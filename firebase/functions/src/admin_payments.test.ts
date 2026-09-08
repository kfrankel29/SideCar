import assert from "node:assert/strict";
import test from "node:test";

import {
  adminBookingRecord,
  bookingMatchesAdminView,
} from "./admin_payments.js";

const timestamp = (value: string) => ({toDate: () => new Date(value)});

test("payments include paid or priced bookings but exclude empty requests", () => {
  assert.equal(bookingMatchesAdminView("payments", {}), false);
  assert.equal(bookingMatchesAdminView("payments", {totalCents: 1500}), true);
  assert.equal(bookingMatchesAdminView("payments", {paymentStatus: "failed"}), true);
});

test("refunds and disputes are classified by every supported production signal", () => {
  assert.equal(bookingMatchesAdminView("refunds", {paymentStatus: "refund_pending"}), true);
  assert.equal(bookingMatchesAdminView("refunds", {refundedAt: timestamp("2026-08-01")}), true);
  assert.equal(bookingMatchesAdminView("refunds", {refundReason: "safety_block"}), true);
  assert.equal(bookingMatchesAdminView("refunds", {cancellationSummary: {riderRefundCents: 500}}), true);
  assert.equal(bookingMatchesAdminView("disputes", {status: "disputed"}), true);
  assert.equal(bookingMatchesAdminView("disputes", {disputeReason: "chargeback"}), true);
  assert.equal(bookingMatchesAdminView("disputes", {}), false);
});

test("payment records preserve money, refund, payout, and lifecycle timestamps", () => {
  const record = adminBookingRecord("booking-1", {
    rideId: "ride-1",
    riderId: "rider-1",
    driverId: "driver-1",
    status: "refunded",
    paymentStatus: "refunded",
    payoutStatus: "held",
    totalCents: 6000,
    cancellationSummary: {riderRefundCents: 4500},
    refundReason: "rider_cancelled",
    disputeReason: "",
    confirmedAt: timestamp("2026-08-01T12:00:00.000Z"),
    refundedAt: timestamp("2026-08-02T12:00:00.000Z"),
  });

  assert.equal(record.id, "booking-1");
  assert.equal(record.totalCents, 6000);
  assert.equal(record.riderRefundCents, 4500);
  assert.equal(record.paymentStatus, "refunded");
  assert.equal(record.payoutStatus, "held");
  assert.equal(record.confirmedAt, "2026-08-01T12:00:00.000Z");
  assert.equal(record.refundedAt, "2026-08-02T12:00:00.000Z");
});

test("payment records support legacy base fares and missing optional data", () => {
  const record = adminBookingRecord("booking-legacy", {baseFareCents: 3200});
  assert.equal(record.totalCents, 3200);
  assert.equal(record.riderRefundCents, 0);
  assert.equal(record.createdAt, null);
});
