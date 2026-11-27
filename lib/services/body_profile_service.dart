import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/body_profile.dart';

class BodyProfileService {
  BodyProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _weights(String uid) =>
      _user(uid).collection('pesagens');

  Stream<BodyProfile> watchProfile(String uid) => _user(uid).snapshots().map(
        (doc) => BodyProfile.fromMap(
          doc.data()?['perfil'] as Map<String, dynamic>?,
        ),
      );

  Future<void> saveProfile(String uid, BodyProfile profile) {
    return _user(uid).set({
      'perfil': {
        ...profile.toMap(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  /// Newest first.
  Stream<List<BodyWeightEntry>> watchWeights(String uid) => _weights(uid)
      .orderBy('data', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => BodyWeightEntry.fromMap(doc.data(), id: doc.id))
          .toList());

  Future<void> addWeight(String uid, BodyWeightEntry entry) {
    return _weights(uid).add({
      ...entry.toMap(),
      'criadoEm': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteWeight(String uid, String id) =>
      _weights(uid).doc(id).delete();
}
