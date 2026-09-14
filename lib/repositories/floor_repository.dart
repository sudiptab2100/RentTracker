import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/floor.dart';
import 'firestore_refs.dart';

class FloorRepository {
  FloorRepository(this.refs);
  final FirestoreRefs? refs;

  Stream<List<Floor>> watchAll(String buildingId) {
    final r = refs;
    if (r == null) return Stream.value(const []);
    return r.floors(buildingId).orderBy('order').snapshots().map(
          (s) => s.docs.map((d) => Floor.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<String> create(String buildingId, Floor floor) async {
    final r = refs!;
    final doc = await r.floors(buildingId).add({...floor.toMap(), 'ownerId': r.uid});
    return doc.id;
  }

  Future<void> update(String buildingId, Floor floor) async {
    final r = refs!;
    await r.floor(buildingId, floor.id).set(
      {...floor.toMap(), 'ownerId': r.uid},
      SetOptions(merge: true),
    );
  }

  Future<void> deleteDeep(String buildingId, String floorId) async {
    final r = refs!;
    final apts = await r.apartments(buildingId, floorId).get();
    for (final a in apts.docs) {
      final records = await r.rentRecords(buildingId, floorId, a.id).get();
      final batch = r.db.batch();
      for (final rec in records.docs) {
        batch.delete(rec.reference);
      }
      batch.delete(a.reference);
      await batch.commit();
    }
    await r.floor(buildingId, floorId).delete();
  }
}

final floorRepositoryProvider = Provider<FloorRepository>(
  (ref) => FloorRepository(ref.watch(firestoreRefsProvider)),
);

final floorsProvider = StreamProvider.autoDispose.family<List<Floor>, String>(
  (ref, buildingId) => ref.watch(floorRepositoryProvider).watchAll(buildingId),
);
