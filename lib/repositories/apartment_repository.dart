import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/apartment.dart';
import 'firestore_refs.dart';

/// (buildingId, floorId)
typedef FloorPath = (String, String);

/// (buildingId, floorId, apartmentId)
typedef ApartmentPath = (String, String, String);

/// An apartment together with its location in the hierarchy, used by the
/// dashboard's owner-wide (collection-group) listing.
class ApartmentRef {
  final String buildingId;
  final String floorId;
  final Apartment apartment;

  const ApartmentRef({
    required this.buildingId,
    required this.floorId,
    required this.apartment,
  });

  String get apartmentId => apartment.id;
  ApartmentPath get path => (buildingId, floorId, apartment.id);
}

class ApartmentRepository {
  ApartmentRepository(this.refs);
  final FirestoreRefs? refs;

  Stream<List<Apartment>> watchAll(String buildingId, String floorId) {
    final r = refs;
    if (r == null) return Stream.value(const []);
    return r.apartments(buildingId, floorId).orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => Apartment.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<Apartment?> watchOne(String buildingId, String floorId, String apartmentId) {
    final r = refs;
    if (r == null) return Stream.value(null);
    return r.apartment(buildingId, floorId, apartmentId).snapshots().map(
          (d) => d.exists ? Apartment.fromMap(d.id, d.data()!) : null,
        );
  }

  /// Every apartment owned by this user, regardless of building/floor.
  Stream<List<ApartmentRef>> watchAllForOwner() {
    final r = refs;
    if (r == null) return Stream.value(const []);
    return r.apartmentsGroup().snapshots().map((s) {
      final list = s.docs.map((d) {
        final aptRef = d.reference;
        final floorRef = aptRef.parent.parent!;
        final buildingRef = floorRef.parent.parent!;
        return ApartmentRef(
          buildingId: buildingRef.id,
          floorId: floorRef.id,
          apartment: Apartment.fromMap(d.id, d.data()),
        );
      }).toList();
      list.sort((a, b) => a.apartment.name.compareTo(b.apartment.name));
      return list;
    });
  }

  Future<String> create(String buildingId, String floorId, Apartment apartment) async {
    final r = refs!;
    final doc = await r
        .apartments(buildingId, floorId)
        .add({...apartment.toMap(), 'ownerId': r.uid});
    return doc.id;
  }

  Future<void> update(String buildingId, String floorId, Apartment apartment) async {
    final r = refs!;
    await r.apartment(buildingId, floorId, apartment.id).set(
      {...apartment.toMap(), 'ownerId': r.uid},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteDeep(String buildingId, String floorId, String apartmentId) async {
    final r = refs!;
    final records = await r.rentRecords(buildingId, floorId, apartmentId).get();
    final batch = r.db.batch();
    for (final rec in records.docs) {
      batch.delete(rec.reference);
    }
    batch.delete(r.apartment(buildingId, floorId, apartmentId));
    await batch.commit();
  }
}

final apartmentRepositoryProvider = Provider<ApartmentRepository>(
  (ref) => ApartmentRepository(ref.watch(firestoreRefsProvider)),
);

final apartmentsProvider = StreamProvider.autoDispose.family<List<Apartment>, FloorPath>(
  (ref, path) => ref.watch(apartmentRepositoryProvider).watchAll(path.$1, path.$2),
);

final apartmentProvider = StreamProvider.autoDispose.family<Apartment?, ApartmentPath>(
  (ref, path) =>
      ref.watch(apartmentRepositoryProvider).watchOne(path.$1, path.$2, path.$3),
);

final ownerApartmentsProvider = StreamProvider.autoDispose<List<ApartmentRef>>(
  (ref) => ref.watch(apartmentRepositoryProvider).watchAllForOwner(),
);
