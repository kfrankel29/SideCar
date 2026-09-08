export type NotificationCopy = {
  title: string;
  body: string;
  route: string;
};

export function isRideUpdateNotification(type: string): boolean {
  return type.trim() !== "" && type !== "new_message";
}

export function notificationCopy(
  type: string,
  data: Record<string, string>,
): NotificationCopy {
  switch (type) {
  case "new_message":
    return {
      title: data.senderName || "New message",
      body: data.preview || "You received a new ride message.",
      route: "messages",
    };
  case "seat_request":
    return {title: "New seat request", body: "A rider requested a seat on your trip.", route: "my_rides"};
  case "ride_search_match":
    return {
      title: "A matching ride was posted",
      body: `${data.originName || "Your pickup"} → ${data.destinationName || "destination"}`,
      route: "search",
    };
  case "seat_request_accepted":
    return {title: "Seat request accepted", body: "Pay within 24 hours to hold your seat.", route: "my_rides"};
  case "seat_request_declined":
    return {title: "Seat request declined", body: "This driver could not accept your request.", route: "my_rides"};
  case "payment_confirmed":
    return {title: "Your ride is confirmed", body: "Your pickup code is ready in My rides.", route: "my_rides"};
  case "payment_failed":
    return {title: "Payment failed", body: "Your payment could not be completed. Please try again.", route: "my_rides"};
  case "seat_booked":
    return {title: "Seat booked", body: "A rider completed payment for your trip.", route: "my_rides"};
  case "trip_reminder":
    return {
      title: "Upcoming SideCar trip",
      body: data.reminderMinutes === "1440" ? "Your trip leaves in about 24 hours." :
        data.reminderMinutes === "30" ? "Your trip leaves in about 30 minutes." :
          data.reminderMinutes === "10" ? "Your trip leaves in about 10 minutes." :
            "Your trip is coming up soon.",
      route: "my_rides",
    };
  case "pickup_code_reminder":
    return {title: "Pickup code ready", body: "Have your pickup code ready for the driver.", route: "my_rides"};
  case "trip_started":
    return {
      title: "Your trip has started",
      body: "Follow the live pickup and drop-off progress in SideCar.",
      route: "live_trip",
    };
  case "pickup_confirmed":
    return {title: "Pickup confirmed", body: "Your trip is now in progress.", route: "live_trip"};
  case "rider_marked_no_show":
    return {
      title: "Marked as no-show",
      body: "The driver marked you as a no-show after the 10-minute pickup wait.",
      route: "my_rides",
    };
  case "no_show_trip_completed":
    return {
      title: "Trip completed",
      body: "This ride was completed with your booking marked as a no-show.",
      route: "my_rides",
    };
  case "trip_completed":
    return {title: "Trip complete", body: "Rate your driver and trip when you have a moment.", route: "rating"};
  case "payout_released":
    return {title: "Payout released", body: "Your completed-trip payout has been released.", route: "my_rides"};
  case "ride_cancelled_full_refund":
  case "payment_refunded_seat_unavailable":
  case "confirmed_booking_cancelled":
    return {title: "Ride cancelled", body: "Your payment was refunded according to the cancellation policy.", route: "my_rides"};
  case "seat_request_cancelled":
    return {title: "Request cancelled", body: "A rider cancelled their seat request.", route: "my_rides"};
  case "payment_window_expired":
    return {title: "Payment window expired", body: "The seat is no longer being held.", route: "my_rides"};
  case "seat_request_expired":
    return {title: "Seat request expired", body: "The rider did not complete payment in time.", route: "my_rides"};
  default:
    return {title: "SideCar update", body: "There is an update to your ride.", route: "my_rides"};
  }
}
