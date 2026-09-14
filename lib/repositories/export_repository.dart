import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/apartment.dart';
import '../models/building.dart';
import '../models/floor.dart';
import '../models/master_export.dart';
import '../models/rent_record.dart';
import 'firestore_refs.dart';

class ImportResult {
  final int buildings;
  final int floors;
  final int apartments;
  final int records;

  const ImportResult({
    this.buildings = 0,
    this.floors = 0,
    this.apartments = 0,
    this.records = 0,
  });

  @override
  String toString() =>
      '$buildings building(s), $floors floor(s), $apartments apartment(s), $records rent record(s)';
}

/// Reads/writes the entire owner data tree for the master export & import
/// (migration) feature.
class ExportRepository {
  ExportRepository(this.refs);
  final FirestoreRefs? refs;

  Future<MasterExport> exportAll() async {
    final r = refs!;
    final buildingExports = <BuildingExport>[];

    final buildingsSnap = await r.buildings.orderBy('createdAt').get();
    for (final b in buildingsSnap.docs) {
      final building = Building.fromMap(b.id, b.data());
      final floorExports = <FloorExport>[];

      final floorsSnap = await r.floors(b.id).orderBy('order').get();
      for (final f in floorsSnap.docs) {
        final floor = Floor.fromMap(f.id, f.data());
        final aptExports = <ApartmentExport>[];

        final aptsSnap = await r.apartments(b.id, f.id).orderBy('name').get();
        for (final a in aptsSnap.docs) {
          final apt = Apartment.fromMap(a.id, a.data());
          final recSnap =
              await r.rentRecords(b.id, f.id, a.id).orderBy('month').get();
          final records =
              recSnap.docs.map((d) => RentRecord.fromMap(d.id, d.data())).toList();
          aptExports.add(ApartmentExport(apartment: apt, rentRecords: records));
        }
        floorExports.add(FloorExport(floor: floor, apartments: aptExports));
      }
      buildingExports.add(BuildingExport(building: building, floors: floorExports));
    }

    return MasterExport(
      exportedAt: DateTime.now(),
      ownerId: r.uid,
      buildings: buildingExports,
    );
  }

  /// Upserts [data] into the current user's Firestore tree. When
  /// [wipeExisting] is true, all current data is deleted first. Original ids
  /// are preserved where present so cross-project migration stays stable.
  Future<ImportResult> importAll(MasterExport data, {bool wipeExisting = false}) async {
    final r = refs!;
    if (wipeExisting) await _wipeAll(r);

    var bc = 0, fc = 0, ac = 0, rc = 0;
    for (final be in data.buildings) {
      final bid = be.building.id.isNotEmpty ? be.building.id : r.buildings.doc().id;
      await r.building(bid).set(
        {...be.building.toMap(), 'ownerId': r.uid},
        SetOptions(merge: true),
      );
      bc++;
      for (final fe in be.floors) {
        final fid = fe.floor.id.isNotEmpty ? fe.floor.id : r.floors(bid).doc().id;
        await r.floor(bid, fid).set(
          {...fe.floor.toMap(), 'ownerId': r.uid},
          SetOptions(merge: true),
        );
        fc++;
        for (final ae in fe.apartments) {
          final aid = ae.apartment.id.isNotEmpty
              ? ae.apartment.id
              : r.apartments(bid, fid).doc().id;
          await r.apartment(bid, fid, aid).set(
            {...ae.apartment.toMap(), 'ownerId': r.uid},
            SetOptions(merge: true),
          );
          ac++;
          if (ae.rentRecords.isNotEmpty) {
            final batch = r.db.batch();
            for (final record in ae.rentRecords) {
              batch.set(
                r.rentRecord(bid, fid, aid, record.month),
                {...record.toMap(), 'ownerId': r.uid},
                SetOptions(merge: true),
              );
              rc++;
            }
            await batch.commit();
          }
        }
      }
    }
    return ImportResult(buildings: bc, floors: fc, apartments: ac, records: rc);
  }

  Future<void> _wipeAll(FirestoreRefs r) async {
    final buildingsSnap = await r.buildings.get();
    for (final b in buildingsSnap.docs) {
      final floorsSnap = await r.floors(b.id).get();
      for (final f in floorsSnap.docs) {
        final aptsSnap = await r.apartments(b.id, f.id).get();
        for (final a in aptsSnap.docs) {
          final recSnap = await r.rentRecords(b.id, f.id, a.id).get();
          final batch = r.db.batch();
          for (final rec in recSnap.docs) {
            batch.delete(rec.reference);
          }
          batch.delete(a.reference);
          await batch.commit();
        }
        await f.reference.delete();
      }
      await b.reference.delete();
    }
  }
}

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(firestoreRefsProvider)),
);
