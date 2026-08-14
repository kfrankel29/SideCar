enum LuggageAllowance {
  backpack('backpack', 'Backpack'),
  oneSuitcase('one_suitcase', '1 suitcase'),
  twoPlusBags('two_plus_bags', '2+ bags');

  const LuggageAllowance(this.value, this.label);

  final String value;
  final String label;

  static LuggageAllowance fromJson(Object? value) {
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => backpack,
    );
  }
}

enum RideGenderRestriction {
  any('any', 'Anyone'),
  womenOnly('women_only', 'Women only'),
  menOnly('men_only', 'Men only');

  const RideGenderRestriction(this.value, this.label);

  final String value;
  final String label;

  static RideGenderRestriction fromJson(Object? value) {
    return values.firstWhere((item) => item.value == value, orElse: () => any);
  }
}

enum DriverGenderFilter {
  any('any', 'Anyone'),
  women('women', 'Female drivers'),
  men('men', 'Male drivers');

  const DriverGenderFilter(this.value, this.label);

  final String value;
  final String label;
}

enum RideSort {
  soonest('soonest', 'Soonest'),
  topRated('top_rated', 'Top rated'),
  mostSeats('most_seats', 'SUV');

  const RideSort(this.value, this.label);

  final String value;
  final String label;
}

class RidePlacePrediction {
  const RidePlacePrediction({
    required this.placeId,
    required this.displayName,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String displayName;
  final String mainText;
  final String secondaryText;

  factory RidePlacePrediction.fromJson(Map<String, dynamic> json) {
    return RidePlacePrediction(
      placeId: json['placeId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      mainText: json['mainText'] as String? ?? '',
      secondaryText: json['secondaryText'] as String? ?? '',
    );
  }
}

class RideLocation {
  const RideLocation({
    required this.placeId,
    required this.displayName,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  final String placeId;
  final String displayName;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  factory RideLocation.fromJson(Map<String, dynamic> json) {
    return RideLocation(
      placeId: json['placeId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RideVehicle {
  const RideVehicle({
    required this.makeAndModel,
    required this.year,
    required this.color,
    required this.photoUrl,
  });

  final String makeAndModel;
  final int year;
  final String color;
  final String photoUrl;

  factory RideVehicle.fromJson(Map<String, dynamic> json) {
    return RideVehicle(
      makeAndModel: json['makeAndModel'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      color: json['color'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
    );
  }
}

enum LiveTripPhase {
  pickups,
  dropoffs,
  complete;

  static LiveTripPhase fromJson(Object? value) => switch (value) {
    'dropoffs' => dropoffs,
    'complete' => complete,
    _ => pickups,
  };
}

enum LiveTripStopKind {
  pickup,
  dropoff;

  static LiveTripStopKind fromJson(Object? value) =>
      value == 'dropoff' ? dropoff : pickup;
}

class LiveTripStop {
  const LiveTripStop({
    required this.bookingId,
    required this.riderId,
    required this.riderName,
    required this.kind,
    required this.order,
    required this.location,
    required this.eta,
    required this.completedAt,
  });

  final String bookingId;
  final String riderId;
  final String riderName;
  final LiveTripStopKind kind;
  final int order;
  final RideLocation location;
  final DateTime? eta;
  final DateTime? completedAt;

  factory LiveTripStop.fromJson(Map<String, dynamic> json) => LiveTripStop(
    bookingId: json['bookingId'] as String? ?? '',
    riderId: json['riderId'] as String? ?? '',
    riderName: json['riderName'] as String? ?? '',
    kind: LiveTripStopKind.fromJson(json['kind']),
    order: (json['order'] as num?)?.toInt() ?? 0,
    location: RideLocation.fromJson(_map(json['location'])),
    eta: DateTime.tryParse(json['eta'] as String? ?? '')?.toLocal(),
    completedAt: DateTime.tryParse(
      json['completedAt'] as String? ?? '',
    )?.toLocal(),
  );
}

class LiveTripPlan {
  const LiveTripPlan({
    required this.phase,
    required this.startedAt,
    required this.updatedAt,
    required this.pickupStops,
    required this.dropoffStops,
    required this.pickupPolyline,
    required this.dropoffPolyline,
  });

  final LiveTripPhase phase;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final List<LiveTripStop> pickupStops;
  final List<LiveTripStop> dropoffStops;
  final String pickupPolyline;
  final String dropoffPolyline;

  factory LiveTripPlan.fromJson(Map<String, dynamic> json) => LiveTripPlan(
    phase: LiveTripPhase.fromJson(json['phase']),
    startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '')?.toLocal(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal(),
    pickupStops: _list(
      json['pickupStops'],
    ).map((item) => LiveTripStop.fromJson(_map(item))).toList(growable: false),
    dropoffStops: _list(
      json['dropoffStops'],
    ).map((item) => LiveTripStop.fromJson(_map(item))).toList(growable: false),
    pickupPolyline: json['pickupPolyline'] as String? ?? '',
    dropoffPolyline: json['dropoffPolyline'] as String? ?? '',
  );
}

class Ride {
  const Ride({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverInitials,
    this.driverPhotoUrl = '',
    required this.driverGender,
    this.driverLanguage = '',
    required this.driverRating,
    required this.driverTrips,
    required this.vehicle,
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.distanceMiles,
    required this.durationSeconds,
    required this.seatsTotal,
    required this.seatsAvailable,
    required this.bookedSeats,
    required this.pricePerSeatCents,
    required this.maximumPriceCents,
    required this.luggageAllowance,
    required this.genderRestriction,
    required this.status,
    required this.shareUrl,
    this.mapPreviewUrl = '',
    this.encodedPolyline = '',
    this.repeatWeekly = false,
    this.recurrenceId = '',
  });

  final String id;
  final String driverId;
  final String driverName;
  final String driverInitials;
  final String driverPhotoUrl;
  final String driverGender;
  final String driverLanguage;
  final double driverRating;
  final int driverTrips;
  final RideVehicle vehicle;
  final RideLocation origin;
  final RideLocation destination;
  final DateTime departureAt;
  final double distanceMiles;
  final int durationSeconds;
  final int seatsTotal;
  final int seatsAvailable;
  final int bookedSeats;
  final int pricePerSeatCents;
  final int maximumPriceCents;
  final LuggageAllowance luggageAllowance;
  final RideGenderRestriction genderRestriction;
  final String status;
  final String shareUrl;
  final String mapPreviewUrl;
  final String encodedPolyline;
  final bool repeatWeekly;
  final String recurrenceId;

  Ride copyWith({int? seatsAvailable, int? bookedSeats, String? status}) {
    return Ride(
      id: id,
      driverId: driverId,
      driverName: driverName,
      driverInitials: driverInitials,
      driverPhotoUrl: driverPhotoUrl,
      driverGender: driverGender,
      driverLanguage: driverLanguage,
      driverRating: driverRating,
      driverTrips: driverTrips,
      vehicle: vehicle,
      origin: origin,
      destination: destination,
      departureAt: departureAt,
      distanceMiles: distanceMiles,
      durationSeconds: durationSeconds,
      seatsTotal: seatsTotal,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      bookedSeats: bookedSeats ?? this.bookedSeats,
      pricePerSeatCents: pricePerSeatCents,
      maximumPriceCents: maximumPriceCents,
      luggageAllowance: luggageAllowance,
      genderRestriction: genderRestriction,
      status: status ?? this.status,
      shareUrl: shareUrl,
      mapPreviewUrl: mapPreviewUrl,
      encodedPolyline: encodedPolyline,
      repeatWeekly: repeatWeekly,
      recurrenceId: recurrenceId,
    );
  }

  String get priceLabel {
    final dollars = pricePerSeatCents / 100;
    return dollars == dollars.roundToDouble()
        ? '\$${dollars.toStringAsFixed(0)}'
        : '\$${dollars.toStringAsFixed(2)}';
  }

  factory Ride.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? '';
    final seatsTotal = (json['seatsTotal'] as num?)?.toInt() ?? 0;
    final rawAvailable = (json['seatsAvailable'] as num?)?.toInt() ?? 0;
    final seatsAvailable = status == 'cancelled'
        ? seatsTotal
        : rawAvailable.clamp(0, seatsTotal);
    final rawBooked = (json['bookedSeats'] as num?)?.toInt();
    final bookedSeats = status == 'cancelled'
        ? 0
        : (rawBooked ?? seatsTotal - seatsAvailable).clamp(0, seatsTotal);
    return Ride(
      id: json['id'] as String? ?? '',
      driverId: json['driverId'] as String? ?? '',
      driverName: json['driverName'] as String? ?? '',
      driverInitials: json['driverInitials'] as String? ?? '',
      driverPhotoUrl: json['driverPhotoUrl'] as String? ?? '',
      driverGender: json['driverGender'] as String? ?? '',
      driverLanguage: json['driverLanguage'] as String? ?? '',
      driverRating: (json['driverRating'] as num?)?.toDouble() ?? 0,
      driverTrips: (json['driverTrips'] as num?)?.toInt() ?? 0,
      vehicle: RideVehicle.fromJson(_map(json['vehicle'])),
      origin: RideLocation.fromJson(_map(json['origin'])),
      destination: RideLocation.fromJson(_map(json['destination'])),
      departureAt:
          DateTime.tryParse(json['departureAt'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      distanceMiles: (json['distanceMiles'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      seatsTotal: seatsTotal,
      seatsAvailable: seatsAvailable,
      bookedSeats: bookedSeats,
      pricePerSeatCents: (json['pricePerSeatCents'] as num?)?.toInt() ?? 0,
      maximumPriceCents: (json['maximumPriceCents'] as num?)?.toInt() ?? 0,
      luggageAllowance: LuggageAllowance.fromJson(json['luggageAllowance']),
      genderRestriction: RideGenderRestriction.fromJson(
        json['genderRestriction'],
      ),
      status: status,
      shareUrl: json['shareUrl'] as String? ?? '',
      mapPreviewUrl: json['mapPreviewUrl'] as String? ?? '',
      encodedPolyline: json['encodedPolyline'] as String? ?? '',
      repeatWeekly: json['repeatWeekly'] as bool? ?? false,
      recurrenceId: json['recurrenceId'] as String? ?? '',
    );
  }
}

class RideDraft {
  const RideDraft({
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.seats,
    required this.pricePerSeatCents,
    required this.luggageAllowance,
    required this.genderRestriction,
    this.repeatWeekly = false,
  });

  final RidePlacePrediction origin;
  final RidePlacePrediction destination;
  final DateTime departureAt;
  final int seats;
  final int pricePerSeatCents;
  final LuggageAllowance luggageAllowance;
  final RideGenderRestriction genderRestriction;
  final bool repeatWeekly;

  Map<String, Object?> toJson() => {
    'originPlaceId': origin.placeId,
    'destinationPlaceId': destination.placeId,
    'departureAt': departureAt.toUtc().toIso8601String(),
    'seats': seats,
    'pricePerSeatCents': pricePerSeatCents,
    'luggageAllowance': luggageAllowance.value,
    'genderRestriction': genderRestriction.value,
    'repeatWeekly': repeatWeekly,
  };
}

class RideUpdate {
  const RideUpdate({
    required this.rideId,
    required this.departureAt,
    required this.seats,
    required this.pricePerSeatCents,
    required this.luggageAllowance,
    required this.genderRestriction,
  });

  final String rideId;
  final DateTime departureAt;
  final int seats;
  final int pricePerSeatCents;
  final LuggageAllowance luggageAllowance;
  final RideGenderRestriction genderRestriction;

  Map<String, Object?> toJson() => {
    'rideId': rideId,
    'departureAt': departureAt.toUtc().toIso8601String(),
    'seats': seats,
    'pricePerSeatCents': pricePerSeatCents,
    'luggageAllowance': luggageAllowance.value,
    'genderRestriction': genderRestriction.value,
  };
}

class RideSearchCriteria {
  const RideSearchCriteria({
    required this.originQuery,
    required this.destinationQuery,
    required this.pickupPlaceId,
    required this.dropoffPlaceId,
    required this.startAt,
    required this.endAt,
    this.driverGender = DriverGenderFilter.any,
    this.driverLanguage = '',
    this.luggageRequired = LuggageAllowance.backpack,
    this.minimumRating = 0,
    this.sort = RideSort.soonest,
  });

  final String originQuery;
  final String destinationQuery;
  final String pickupPlaceId;
  final String dropoffPlaceId;
  final DateTime startAt;
  final DateTime endAt;
  final DriverGenderFilter driverGender;
  final String driverLanguage;
  final LuggageAllowance luggageRequired;
  final double minimumRating;
  final RideSort sort;

  RideSearchCriteria copyWith({
    String? originQuery,
    String? destinationQuery,
    String? pickupPlaceId,
    String? dropoffPlaceId,
    DateTime? startAt,
    DateTime? endAt,
    DriverGenderFilter? driverGender,
    String? driverLanguage,
    LuggageAllowance? luggageRequired,
    double? minimumRating,
    RideSort? sort,
  }) {
    return RideSearchCriteria(
      originQuery: originQuery ?? this.originQuery,
      destinationQuery: destinationQuery ?? this.destinationQuery,
      pickupPlaceId: pickupPlaceId ?? this.pickupPlaceId,
      dropoffPlaceId: dropoffPlaceId ?? this.dropoffPlaceId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      driverGender: driverGender ?? this.driverGender,
      driverLanguage: driverLanguage ?? this.driverLanguage,
      luggageRequired: luggageRequired ?? this.luggageRequired,
      minimumRating: minimumRating ?? this.minimumRating,
      sort: sort ?? this.sort,
    );
  }

  Map<String, Object?> toJson() => {
    'originQuery': originQuery.trim(),
    'destinationQuery': destinationQuery.trim(),
    'pickupPlaceId': pickupPlaceId,
    'dropoffPlaceId': dropoffPlaceId,
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'driverGender': driverGender.value,
    'driverLanguage': driverLanguage.trim(),
    'luggageRequired': luggageRequired.value,
    'minimumRating': minimumRating,
    'sort': sort.value,
  };
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const {};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];
