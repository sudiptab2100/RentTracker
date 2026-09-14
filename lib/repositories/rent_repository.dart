import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/rent_record.dart';
import 'apartment_repository.dart';
import 'firestore_refs.dart';

class RentRepository {
  RentRepository(this.refs);
  final FirestoreRefs? refs;

  Stream<List<RentRecord>> watchRecords(ApartmentPath p) {
    final r = refs;
    if (r == null) return Stream.value(const []);
    return r
        .rentRecords(p.$1, p.$2, p.$3)
        .orderBy('month', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => RentRecord.fromMap(d.id, d.data())).toList());
  }

  Stream<RentRecord?> watchRecord(ApartmentPath p, String month) {
    final r = refs;
    if (r == null) return Stream.value(null);
    return r.rentRecord(p.$1, p.$2, p.$3, month).snapshots().map(
          (d) => d.exists ? RentRecord.fromMap(d.id, d.data()!) : null,
        );
  }

  Future<RentRecord?> getRecord(ApartmentPath p, String month) async {
    final r = refs;
    if (r == null) return null;
    final d = await r.rentRecord(p.$1, p.$2, p.$3, month).get();
    return d.exists ? RentRecord.fromMap(d.id, d.data()!) : null;
  }

  Future<List<RentRecord>> getAllRecords(ApartmentPath p) async {
    final r = refs;
    if (r == null) return const [];
    final s = await r.rentRecords(p.$1, p.$2, p.$3).orderBy('month').get();
    return s.docs.map((d) => RentRecord.fromMap(d.id, d.data())).toList();
  }

  Future<void> setRecord(ApartmentPath p, RentRecord record) async {
    final r = refs!;
    await r.rentRecord(p.$1, p.$2, p.$3, record.month).set(
      {...record.toMap(), 'ownerId': r.uid},
      SetOptions(merge: true),
    );
  }

  /// Writes several records at once (used by lazy monthly generation).
  Future<void> setRecords(ApartmentPath p, List<RentRecord> records) async {
    if (records.isEmpty) return;
    final r = refs!;
    final batch = r.db.batch();
    for (final record in records) {
      batch.set(
        r.rentRecord(p.$1, p.$2, p.$3, record.month),
        {...record.toMap(), 'ownerId': r.uid},
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> deleteRecord(ApartmentPath p, String month) async {
    final r = refs!;
    await r.rentRecord(p.$1, p.$2, p.$3, month).delete();
  }
}

final rentRepositoryProvider = Provider<RentRepository>(
  (ref) => RentRepository(ref.watch(firestoreRefsProvider)),
);

final rentRecordsProvider =
    StreamProvider.autoDispose.family<List<RentRecord>, ApartmentPath>(
  (ref, path) => ref.watch(rentRepositoryProvider).watchRecords(path),
);
