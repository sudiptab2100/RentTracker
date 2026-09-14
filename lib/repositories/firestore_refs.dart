import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_providers.dart';

typedef Json = Map<String, dynamic>;

/// Builds the owner-scoped Firestore document/collection references. The data
/// tree is:
///
///   users/{uid}/buildings/{bId}
///     .../floors/{fId}
///       .../apartments/{aId}
///         .../rentRecords/{yyyy-MM}
class FirestoreRefs {
  FirestoreRefs(this.db, this.uid);

  final FirebaseFirestore db;
  final String uid;

  DocumentReference<Json> get userDoc => db.collection('users').doc(uid);

  CollectionReference<Json> get buildings => userDoc.collection('buildings');
  DocumentReference<Json> building(String bId) => buildings.doc(bId);

  CollectionReference<Json> floors(String bId) => building(bId).collection('floors');
  DocumentReference<Json> floor(String bId, String fId) => floors(bId).doc(fId);

  CollectionReference<Json> apartments(String bId, String fId) =>
      floor(bId, fId).collection('apartments');
  DocumentReference<Json> apartment(String bId, String fId, String aId) =>
      apartments(bId, fId).doc(aId);

  CollectionReference<Json> rentRecords(String bId, String fId, String aId) =>
      apartment(bId, fId, aId).collection('rentRecords');
  DocumentReference<Json> rentRecord(String bId, String fId, String aId, String month) =>
      rentRecords(bId, fId, aId).doc(month);

  /// Collection-group query over every apartment owned by this user.
  Query<Json> apartmentsGroup() =>
      db.collectionGroup('apartments').where('ownerId', isEqualTo: uid);
}

/// Null when signed out; non-null within authenticated screens.
final firestoreRefsProvider = Provider<FirestoreRefs?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return FirestoreRefs(ref.watch(firestoreProvider), uid);
});
