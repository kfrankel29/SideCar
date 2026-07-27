import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';

class FirebaseVerificationRepository implements VerificationRepository {
  FirebaseVerificationRepository(
    this._auth,
    this._firestore,
    this._storage,
    this._functions,
  );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  static const _timeout = Duration(seconds: 25);
  static const _documentUploadTimeout = Duration(seconds: 60);

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppFailure('Please sign in again.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get _statusReference => _firestore
      .collection('users')
      .doc(_uid)
      .collection('verifications')
      .doc('current');

  DocumentReference<Map<String, dynamic>> get _vehicleReference => _firestore
      .collection('users')
      .doc(_uid)
      .collection('vehicles')
      .doc('primary');

  @override
  Stream<VerificationSummary> watchCurrentVerification() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const VerificationSummary());
    final status = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('verifications')
        .doc('current')
        .snapshots();
    final vehicle = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vehicles')
        .doc('primary')
        .snapshots();

    return Stream<VerificationSummary>.multi((controller) {
      DocumentSnapshot<Map<String, dynamic>>? latestStatus;
      DocumentSnapshot<Map<String, dynamic>>? latestVehicle;

      void emitIfReady() {
        if (latestStatus == null || latestVehicle == null) return;
        controller.add(
          VerificationSummary.fromJson(
            latestStatus!.data(),
            latestVehicle!.data(),
          ),
        );
      }

      final statusSubscription = status.listen((snapshot) {
        latestStatus = snapshot;
        emitIfReady();
      }, onError: controller.addError);
      final vehicleSubscription = vehicle.listen((snapshot) {
        latestVehicle = snapshot;
        emitIfReady();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await statusSubscription.cancel();
        await vehicleSubscription.cancel();
      };
    });
  }

  @override
  Future<VerificationSummary> loadCurrentVerification() async {
    try {
      final results = await Future.wait([
        _statusReference.get(const GetOptions(source: Source.server)),
        _vehicleReference.get(const GetOptions(source: Source.server)),
      ]).timeout(_timeout);
      return VerificationSummary.fromJson(results[0].data(), results[1].data());
    } on TimeoutException {
      throw const AppFailure(
        'Verification status took too long to load. Check your connection.',
      );
    } on FirebaseException {
      throw const AppFailure(
        'We could not load your verification status. Try again.',
      );
    }
  }

  @override
  Future<Uri> createIdentityVerificationSession() async {
    try {
      final result = await _functions
          .httpsCallable('createIdentityVerificationSession')
          .call<Map<String, dynamic>>()
          .timeout(_timeout);
      final value = result.data['url'];
      final uri = value is String ? Uri.tryParse(value) : null;
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw const AppFailure(
          'Stripe did not return a valid verification link.',
        );
      }
      return uri;
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(
        error.message ?? 'We could not start identity verification.',
        code: error.code,
      );
    } on TimeoutException {
      throw const AppFailure(
        'Identity verification took too long to start. Try again.',
      );
    }
  }

  @override
  Future<void> saveVehicle(VehicleProfile vehicle) async {
    if (!vehicle.isComplete) {
      throw const AppFailure('Complete every required vehicle detail.');
    }
    try {
      await _vehicleReference
          .set({
            ...vehicle.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_timeout);
    } on TimeoutException {
      throw const AppFailure(
        'Your vehicle took too long to save. Check your connection.',
      );
    } on FirebaseException {
      throw const AppFailure('We could not save your vehicle. Try again.');
    }
  }

  @override
  Future<String> uploadVehiclePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!contentType.startsWith('image/')) {
      throw const AppFailure('Choose a valid vehicle photo.');
    }
    if (bytes.isEmpty || bytes.lengthInBytes >= 8 * 1024 * 1024) {
      throw const AppFailure('Choose a vehicle photo smaller than 8 MB.');
    }
    final reference = _storage.ref(
      'users/$_uid/verification/vehicle/primary.jpg',
    );
    try {
      await reference
          .putData(
            bytes,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'private,max-age=3600',
            ),
          )
          .timeout(_timeout);
      return await reference.getDownloadURL().timeout(_timeout);
    } on TimeoutException {
      throw const AppFailure(
        'Your vehicle photo took too long to upload. Try again.',
      );
    } on FirebaseException {
      throw const AppFailure(
        'We could not upload your vehicle photo. Try again.',
      );
    }
  }

  @override
  Future<void> submitInsuranceDocument({
    required Uint8List bytes,
    required String contentType,
  }) async {
    const supportedContentTypes = {
      'image/jpeg',
      'image/png',
      'application/pdf',
    };
    if (!supportedContentTypes.contains(contentType)) {
      throw const AppFailure('Upload a JPG, PNG, or PDF insurance document.');
    }
    if (bytes.isEmpty || bytes.lengthInBytes >= 10 * 1024 * 1024) {
      throw const AppFailure(
        'Upload an insurance document smaller than 10 MB.',
      );
    }
    try {
      await _functions
          .httpsCallable('submitManualInsuranceDocument')
          .call<Map<String, dynamic>>({
            'encodedBytes': base64Encode(bytes),
            'contentType': contentType,
          })
          .timeout(_documentUploadTimeout);
    } on TimeoutException {
      throw const AppFailure(
        'Your document took too long to upload. Check your connection.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(
        error.message ??
            'We could not submit your insurance document. Try again.',
        code: error.code,
      );
    }
  }
}

class UnavailableVerificationRepository implements VerificationRepository {
  const UnavailableVerificationRepository();

  Never _notReady() => throw const AppFailure(
    'Verification services are unavailable in this build.',
    code: 'firebase-not-configured',
  );

  @override
  Future<Uri> createIdentityVerificationSession() async => _notReady();

  @override
  Future<VerificationSummary> loadCurrentVerification() async =>
      const VerificationSummary();

  @override
  Future<void> saveVehicle(VehicleProfile vehicle) async => _notReady();

  @override
  Future<String> uploadVehiclePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => _notReady();

  @override
  Future<void> submitInsuranceDocument({
    required Uint8List bytes,
    required String contentType,
  }) async => _notReady();

  @override
  Stream<VerificationSummary> watchCurrentVerification() =>
      Stream.value(const VerificationSummary());
}
