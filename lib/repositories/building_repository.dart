import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/building.dart';
import 'firestore_refs.dart';

class BuildingRepository {
  BuildingRepository(this.refs);
  final FirestoreRefs? refs;

  Stream<List<Building>> watchAll() {
    final r = refs;
    if (r == null) return Stream.value(const []);
    return r.buildings.orderBy('createdAt').snapshots().map(
          (s) => s.docs.map((d) => Building.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<String> create(Building building) async {
    final r = refs!;
    final doc = await r.buildings.add({...building.toMap(), 'ownerId': r.uid});
    return doc.id;
  }

  Future<void> update(Building building) async {
    final r = refs!;
    await r.building(building.id).set(
      {...building.toMap(), 'ownerId': r.uid},
      SetOptions(merge: true),
    );
  }

  /// Deletes a building along with all of its floors, apartments and rent
  /// records (Firestore does not cascade).
  Future<void> deleteDeep(String buildingId) async {
    final r = refs!;
    final floors = await r.floors(buildingId).get();
    for (final f in floors.docs) {
      await _deleteFloor(r, buildingId, f.id);
    }
    await r.building(buildingId).delete();
  }

  static Future<void> _deleteFloor(FirestoreRefs r, String bId, String fId) async {
    final apts = await r.apartments(bId, fId).get();
    for (final a in apts.docs) {
      await _deleteApartment(r, bId, fId, a.id);
    }
    await r.floor(bId, fId).delete();
  }

  static Future<void> _deleteApartment(
    FirestoreRefs r,
    String bId,
    String fId,
    String aId,
  ) async {
    final records = await r.rentRecords(bId, fId, aId).get();
    final batch = r.db.batch();
    for (final rec in records.docs) {
      batch.delete(rec.reference);
    }
    batch.delete(r.apartment(bId, fId, aId));
    await batch.commit();
  }
}

final buildingRepositoryProvider = Provider<BuildingRepository>(
  (ref) => BuildingRepository(ref.watch(firestoreRefsProvider)),
);

final buildingsProvider = StreamProvider.autoDispose<List<Building>>(
  (ref) => ref.watch(buildingRepositoryProvider).watchAll(),
);
