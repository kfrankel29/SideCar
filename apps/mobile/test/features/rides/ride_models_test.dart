import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';

void main() {
  test('ride draft serializes server-owned creation fields', () {
    final departure = DateTime.utc(2026, 8, 10, 22);
    final draft = RideDraft(
      origin: const RidePlacePrediction(
        placeId: 'origin-id',
        displayName: 'UCSB / Isla Vista',
        mainText: 'UCSB',
        secondaryText: 'Santa Barbara, CA',
      ),
      destination: const RidePlacePrediction(
        placeId: 'destination-id',
        displayName: 'Palo Alto Caltrain',
        mainText: 'Palo Alto Caltrain',
        secondaryText: 'Palo Alto, CA',
      ),
      departureAt: departure,
      seats: 3,
      pricePerSeatCents: 5600,
      luggageAllowance: LuggageAllowance.oneSuitcase,
      genderRestriction: RideGenderRestriction.womenOnly,
    );

    expect(draft.toJson(), {
      'originPlaceId': 'origin-id',
      'destinationPlaceId': 'destination-id',
      'departureAt': departure.toIso8601String(),
      'seats': 3,
      'pricePerSeatCents': 5600,
      'luggageAllowance': 'one_suitcase',
      'genderRestriction': 'women_only',
      'repeatWeekly': false,
    });
  });

  test('ride response parsing preserves money and filters', () {
    final ride = Ride.fromJson({
      'id': 'ride-1',
      'driverId': 'driver-1',
      'driverName': 'Jordan T.',
      'driverInitials': 'JT',
      'driverPhotoUrl': 'https://example.com/jordan.jpg',
      'driverGender': 'male',
      'driverLanguage': 'Uzbek',
      'driverRating': 4.9,
      'driverTrips': 12,
      'vehicle': {
        'makeAndModel': 'Honda CR-V',
        'year': 2019,
        'color': 'White',
        'photoUrl': '',
      },
      'origin': {
        'placeId': 'a',
        'displayName': 'Isla Vista',
        'formattedAddress': 'Isla Vista, CA',
        'latitude': 34.41,
        'longitude': -119.86,
      },
      'destination': {
        'placeId': 'b',
        'displayName': 'Palo Alto',
        'formattedAddress': 'Palo Alto, CA',
        'latitude': 37.44,
        'longitude': -122.16,
      },
      'departureAt': '2026-08-10T22:00:00.000Z',
      'distanceMiles': 302.5,
      'durationSeconds': 18400,
      'seatsTotal': 3,
      'seatsAvailable': 2,
      'bookedSeats': 1,
      'pricePerSeatCents': 5587,
      'maximumPriceCents': 5600,
      'luggageAllowance': 'one_suitcase',
      'genderRestriction': 'any',
      'status': 'published',
      'shareUrl': 'https://example.com/ride-1',
      'mapPreviewUrl': 'https://example.com/ride-map?id=ride-1',
      'encodedPolyline': 'abc',
      'repeatWeekly': true,
      'recurrenceId': 'series-1',
    });

    expect(ride.priceLabel, r'$55.87');
    expect(ride.luggageAllowance, LuggageAllowance.oneSuitcase);
    expect(ride.seatsAvailable, 2);
    expect(ride.bookedSeats, 1);
    expect(ride.driverLanguage, 'Uzbek');
    expect(ride.driverPhotoUrl, 'https://example.com/jordan.jpg');
    expect(ride.vehicle.makeAndModel, 'Honda CR-V');
    expect(ride.mapPreviewUrl, 'https://example.com/ride-map?id=ride-1');
    expect(ride.encodedPolyline, 'abc');
    expect(ride.repeatWeekly, isTrue);
    expect(ride.recurrenceId, 'series-1');
  });

  test('cancelled rides never report refunded seats as booked', () {
    final ride = Ride.fromJson({
      'seatsTotal': 3,
      'seatsAvailable': 0,
      'bookedSeats': 3,
      'status': 'cancelled',
    });

    expect(ride.bookedSeats, 0);
    expect(ride.seatsAvailable, 3);
  });

  test('ride search serializes the selected spoken language', () {
    final criteria = RideSearchCriteria(
      originQuery: 'UCSB',
      destinationQuery: 'Palo Alto',
      pickupPlaceId: 'pickup',
      dropoffPlaceId: 'dropoff',
      startAt: DateTime.utc(2026, 8, 10),
      endAt: DateTime.utc(2026, 8, 11),
      driverLanguage: 'Uzbek',
    );

    expect(criteria.toJson()['driverLanguage'], 'Uzbek');
  });

  test('similar-date notifications cover three days on either side', () {
    final selected = DateTime(2026, 9, 10);
    final criteria = RideSearchCriteria(
      originQuery: 'Isla Vista',
      destinationQuery: 'Palo Alto',
      pickupPlaceId: 'pickup',
      dropoffPlaceId: 'dropoff',
      startAt: selected,
      endAt: selected.add(const Duration(days: 1)),
    );

    final alert = criteria.forSimilarDateAlert();

    expect(alert.startAt, DateTime(2026, 9, 7));
    expect(alert.endAt, DateTime(2026, 9, 14));
    expect(criteria.startAt, selected);
    expect(criteria.endAt, selected.add(const Duration(days: 1)));
  });

  test('stop picker removes gas stations beyond one mile of the route', () {
    final context = RideStopPickerContext.fromJson({
      'routePoints': [
        {'latitude': 37.33, 'longitude': -121.90},
        {'latitude': 37.43, 'longitude': -121.90},
      ],
      'gasStations': [
        {
          'placeId': 'near',
          'displayName': 'Near route',
          'mainText': 'Near route',
          'secondaryText': 'San Jose, CA',
          'latitude': 37.38,
          'longitude': -121.905,
        },
        {
          'placeId': 'far',
          'displayName': 'Far from route',
          'mainText': 'Far from route',
          'secondaryText': 'San Jose, CA',
          'latitude': 37.38,
          'longitude': -121.93,
        },
      ],
    });

    expect(context.gasStations.map((station) => station.placeId), ['near']);
  });

  test(
    'stop picker excludes borderline markers using the route safety margin',
    () {
      final context = RideStopPickerContext.fromJson({
        'routePoints': [
          {'latitude': 37.30, 'longitude': -121.90},
          {'latitude': 37.50, 'longitude': -121.90},
        ],
        'gasStations': [
          {'placeId': 'inside', 'latitude': 37.40, 'longitude': -121.895},
          {'placeId': 'borderline', 'latitude': 37.40, 'longitude': -121.89},
        ],
      });

      expect(context.gasStations.map((station) => station.placeId), ['inside']);
    },
  );
}
