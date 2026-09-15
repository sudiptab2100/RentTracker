import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/apartment.dart';
import '../../models/building.dart';
import '../../models/floor.dart';
import '../../models/ledger.dart';
import '../../models/rent_record.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/firestore_refs.dart';

/// One apartment with its running ledger and location names.
class ApartmentOverview {
  final String buildingId;
  final String floorId;
  final Apartment apartment;
  final Ledger ledger;
  final String buildingName;
  final String floorName;

  const ApartmentOverview({
    required this.buildingId,
    required this.floorId,
    required this.apartment,
    required this.ledger,
    required this.buildingName,
    required this.floorName,
  });

  ApartmentPath get path => (buildingId, floorId, apartment.id);

  /// Signed cumulative balance (>0 = owes, <0 = advance).
  int get balance => ledger.outstanding;
  int get outstanding => balance > 0 ? balance : 0;
  bool get isDue => balance > 0;
}

/// Portfolio-wide, cumulative view used by the dashboard and Unpaid tab.
class Overview {
  final List<ApartmentOverview> apartments;
  const Overview(this.apartments);

  int get apartmentCount => apartments.length;
  int get tenantCount => apartments.where((a) => a.apartment.hasTenant).length;
  int get totalOutstanding => apartments.fold(0, (s, a) => s + a.outstanding);
  int get dueCount => apartments.where((a) => a.isDue).length;

  int outstandingForBuilding(String id) =>
      apartments.where((a) => a.buildingId == id).fold(0, (s, a) => s + a.outstanding);
  int dueCountForBuilding(String id) =>
      apartments.where((a) => a.buildingId == id && a.isDue).length;
  int apartmentsForBuilding(String id) =>
      apartments.where((a) => a.buildingId == id).length;

  /// Apartments with a positive cumulative balance, highest first.
  List<ApartmentOverview> get dueList {
    final list = apartments.where((a) => a.isDue).toList();
    list.sort((a, b) => b.outstanding.compareTo(a.outstanding));
    return list;
  }
}

/// Loads every apartment and rent record (owner-scoped collection groups),
/// builds a running ledger per apartment, and joins building/floor names.
final overviewProvider = FutureProvider.autoDispose<Overview>((ref) async {
  final refs = ref.watch(firestoreRefsProvider);
  if (refs == null) return const Overview([]);

  final results = await Future.wait([
    refs.apartmentsGroup().get(),
    refs.rentRecordsGroup().get(),
    refs.floorsGroup().get(),
    refs.buildings.get(),
  ]);
  final aptSnap = results[0];
  final recSnap = results[1];
  final floorSnap = results[2];
  final buildingSnap = results[3];

  final buildingNames = {
    for (final d in buildingSnap.docs) d.id: Building.fromMap(d.id, d.data()).name
  };
  final floorNames = {
    for (final d in floorSnap.docs) d.id: Floor.fromMap(d.id, d.data()).name
  };

  final recordsByApt = <String, List<RentRecord>>{};
  for (final d in recSnap.docs) {
    final aptId = d.reference.parent.parent?.id;
    if (aptId == null) continue;
    (recordsByApt[aptId] ??= []).add(RentRecord.fromMap(d.id, d.data()));
  }

  final apartments = <ApartmentOverview>[];
  for (final d in aptSnap.docs) {
    final floorRef = d.reference.parent.parent!;
    final buildingRef = floorRef.parent.parent!;
    apartments.add(ApartmentOverview(
      buildingId: buildingRef.id,
      floorId: floorRef.id,
      apartment: Apartment.fromMap(d.id, d.data()),
      ledger: Ledger.from(recordsByApt[d.id] ?? const []),
      buildingName: buildingNames[buildingRef.id] ?? '',
      floorName: floorNames[floorRef.id] ?? '',
    ));
  }
  apartments.sort((a, b) => a.apartment.name.compareTo(b.apartment.name));
  return Overview(apartments);
});
