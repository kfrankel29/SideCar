import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository(this._auth, this._firestore, this._storage);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  Stream<UserProfile?> watchCurrentProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _firestore.collection('users').doc(user.uid).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      return data == null ? null : UserProfile.fromJson(snapshot.id, data);
    });
  }

  @override
  Future<UserProfile?> loadCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data();
    return data == null ? null : UserProfile.fromJson(snapshot.id, data);
  }

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please sign in again.');
    if (!contentType.startsWith('image/')) {
      throw const AppFailure('Choose a valid photo.');
    }
    final reference = _storage.ref('users/${user.uid}/profile/profile.jpg');
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'private,max-age=3600',
      ),
    );
    return reference.getDownloadURL();
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != profile.userId) {
      throw const AppFailure('Please sign in again.');
    }
    await _firestore.collection('users').doc(user.uid).set({
      ...profile.toJson(),
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please sign in again.');
    await _firestore.collection('users').doc(user.uid).set({
      'primaryRole': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class UnavailableProfileRepository implements ProfileRepository {
  const UnavailableProfileRepository();

  Never _notReady() {
    throw const AppFailure(
      'Firebase is not configured for this build yet.',
      code: 'firebase-not-configured',
    );
  }

  @override
  Future<UserProfile?> loadCurrentProfile() async => null;

  @override
  Future<void> saveProfile(UserProfile profile) async => _notReady();

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async => _notReady();

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => _notReady();

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(null);
}
