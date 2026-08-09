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
}
