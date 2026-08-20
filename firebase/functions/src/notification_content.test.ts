import assert from "node:assert/strict";
import test from "node:test";

import {notificationCopy} from "./notification_content.js";

test("message notifications include the sender, preview, and inbox route", () => {
  assert.deepEqual(notificationCopy("new_message", {
    senderName: "Maya Chen",
    preview: "I am by the library.",
  }), {
    title: "Maya Chen",
    body: "I am by the library.",
    route: "messages",
  });
});

test("every booking lifecycle notification opens a valid destination", () => {
  const expectedRoutes: Record<string, string> = {
    seat_request: "my_rides",
    seat_request_accepted: "my_rides",
    seat_request_declined: "my_rides",
    payment_confirmed: "my_rides",
    payment_failed: "my_rides",
    seat_booked: "my_rides",
    trip_reminder: "my_rides",
    pickup_code_reminder: "my_rides",
    pickup_confirmed: "live_trip",
    trip_completed: "rating",
    payout_released: "my_rides",
    ride_cancelled_full_refund: "my_rides",
    payment_refunded_seat_unavailable: "my_rides",
    confirmed_booking_cancelled: "my_rides",
    seat_request_cancelled: "my_rides",
    payment_window_expired: "my_rides",
    seat_request_expired: "my_rides",
  };

  for (const [type, route] of Object.entries(expectedRoutes)) {
    const copy = notificationCopy(type, {});
    assert.equal(copy.route, route, type);
    assert.notEqual(copy.title.trim(), "", type);
    assert.notEqual(copy.body.trim(), "", type);
  }
});

test("unknown notification types fail safely to My rides", () => {
  assert.deepEqual(notificationCopy("future_booking_event", {}), {
    title: "SideCar update",
    body: "There is an update to your ride.",
    route: "my_rides",
  });
});
