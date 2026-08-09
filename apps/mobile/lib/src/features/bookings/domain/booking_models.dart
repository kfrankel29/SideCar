enum BookingStatus {
  pendingDriver('pending_driver'),
  declined('declined'),
  acceptedPaymentPending('accepted_payment_pending'),
  paymentProcessing('payment_processing'),
  confirmed('confirmed'),
  expired('expired'),
  cancelled('cancelled'),
  lostSeat('lost_seat'),
  inProgress('in_progress'),
  completed('completed'),
  disputed('disputed'),
  payoutHeld('payout_held'),
  refunded('refunded'),
  cancellationProcessing('cancellation_processing'),
  completionProcessing('completion_processing');

  const BookingStatus(this.wireValue);
  final String wireValue;

  static BookingStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireValue == value,
    orElse: () => BookingStatus.pendingDriver,
  );
}

enum BookingPaymentMethod {
  card('card'),
  bank('bank');

  const BookingPaymentMethod(this.wireValue);
  final String wireValue;
}

class BookingPaymentQuote {
  const BookingPaymentQuote({
    required this.baseFareCents,
    required this.serviceFeeCents,
    required this.processingFeeCents,
    required this.totalCents,
  });

  factory BookingPaymentQuote.fromJson(Map<String, dynamic> json) =>
      BookingPaymentQuote(
        baseFareCents: (json['baseFareCents'] as num?)?.round() ?? 0,
        serviceFeeCents: (json['serviceFeeCents'] as num?)?.round() ?? 0,
        processingFeeCents: (json['processingFeeCents'] as num?)?.round() ?? 0,
        totalCents: (json['totalCents'] as num?)?.round() ?? 0,
      );

  final int baseFareCents;
  final int serviceFeeCents;
  final int processingFeeCents;
  final int totalCents;

  String label(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
  String get totalLabel => label(totalCents);
}

class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    required this.detail,
  });

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) =>
      SavedPaymentMethod(
        id: json['id'] as String? ?? '',
        type: json['type'] == 'bank'
            ? BookingPaymentMethod.bank
            : BookingPaymentMethod.card,
        label: json['label'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );

  final String id;
  final BookingPaymentMethod type;
  final String label;
  final String detail;
}

class SeatBooking {
  const SeatBooking({
    required this.id,
    required this.rideId,
    required this.riderId,
    required this.riderName,
    required this.riderInitials,
    required this.riderPhotoUrl,
    required this.driverId,
    required this.driverName,
    required this.status,
    required this.originName,
    required this.destinationName,
    required this.departureAt,
    required this.baseFareCents,
    required this.serviceFeeCents,
    required this.processingFeeCents,
    required this.totalCents,
    this.paymentStatus = '',
    this.payoutStatus = '',
    this.driverPayoutCents = 0,
    this.paymentExpiresAt,
    this.pickupCode,
    this.disputeReason,
  });

  factory SeatBooking.fromJson(Map<String, dynamic> json) => SeatBooking(
    id: json['id'] as String? ?? '',
    rideId: json['rideId'] as String? ?? '',
    riderId: json['riderId'] as String? ?? '',
    riderName: json['riderName'] as String? ?? '',
    riderInitials: json['riderInitials'] as String? ?? '',
    riderPhotoUrl: json['riderPhotoUrl'] as String? ?? '',
    driverId: json['driverId'] as String? ?? '',
    driverName: json['driverName'] as String? ?? '',
    status: BookingStatus.fromWire(json['status']),
    originName: json['originName'] as String? ?? '',
    destinationName: json['destinationName'] as String? ?? '',
    departureAt:
        DateTime.tryParse(json['departureAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    paymentExpiresAt: DateTime.tryParse(
      json['paymentExpiresAt'] as String? ?? '',
    ),
    baseFareCents: (json['baseFareCents'] as num?)?.round() ?? 0,
    serviceFeeCents: (json['serviceFeeCents'] as num?)?.round() ?? 0,
    processingFeeCents: (json['processingFeeCents'] as num?)?.round() ?? 0,
    totalCents: (json['totalCents'] as num?)?.round() ?? 0,
    paymentStatus: json['paymentStatus'] as String? ?? '',
    payoutStatus: json['payoutStatus'] as String? ?? '',
    driverPayoutCents: (json['driverPayoutCents'] as num?)?.round() ?? 0,
    pickupCode: json['pickupCode'] as String?,
    disputeReason: json['disputeReason'] as String?,
  );

  final String id;
  final String rideId;
  final String riderId;
  final String riderName;
  final String riderInitials;
  final String riderPhotoUrl;
  final String driverId;
  final String driverName;
  final BookingStatus status;
  final String originName;
  final String destinationName;
  final DateTime departureAt;
  final DateTime? paymentExpiresAt;
  final int baseFareCents;
  final int serviceFeeCents;
  final int processingFeeCents;
  final int totalCents;
  final String paymentStatus;
  final String payoutStatus;
  final int driverPayoutCents;
  final String? pickupCode;
  final String? disputeReason;

  String get totalLabel => '\$${(totalCents / 100).toStringAsFixed(2)}';

  bool get hasFinancialActivity =>
      totalCents > 0 || paymentStatus.isNotEmpty || payoutStatus.isNotEmpty;
}

class DriverPayoutStatus {
  const DriverPayoutStatus({
    required this.connected,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
    this.bankName = '',
    this.last4 = '',
    this.availableCents = 0,
    this.pendingCents = 0,
  });

  factory DriverPayoutStatus.fromJson(Map<String, dynamic> json) =>
      DriverPayoutStatus(
        connected: json['connected'] == true,
        payoutsEnabled: json['payoutsEnabled'] == true,
        detailsSubmitted: json['detailsSubmitted'] == true,
        bankName: json['bankName'] as String? ?? '',
        last4: json['last4'] as String? ?? '',
        availableCents: (json['availableCents'] as num?)?.round() ?? 0,
        pendingCents: (json['pendingCents'] as num?)?.round() ?? 0,
      );

  final bool connected;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final String bankName;
  final String last4;
  final int availableCents;
  final int pendingCents;
}
