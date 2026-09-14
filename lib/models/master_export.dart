import 'apartment.dart';
import 'building.dart';
import 'floor.dart';
import 'rent_record.dart';

/// Nested export tree used by the master export/import feature. Serializes the
/// entire owner data set into a single portable JSON document so it can be
/// migrated to a different app or a different Firebase project.

class ApartmentExport {
  final Apartment apartment;
  final List<RentRecord> rentRecords;

  const ApartmentExport({required this.apartment, this.rentRecords = const []});

  Map<String, dynamic> toJson() => {
        'apartment': apartment.toJson(),
        'rentRecords': rentRecords.map((r) => r.toJson()).toList(),
      };

  factory ApartmentExport.fromJson(Map<String, dynamic> json) => ApartmentExport(
        apartment: Apartment.fromJson(Map<String, dynamic>.from(json['apartment'] as Map)),
        rentRecords: ((json['rentRecords'] ?? const []) as List)
            .map((e) => RentRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class FloorExport {
  final Floor floor;
  final List<ApartmentExport> apartments;

  const FloorExport({required this.floor, this.apartments = const []});

  Map<String, dynamic> toJson() => {
        'floor': floor.toJson(),
        'apartments': apartments.map((a) => a.toJson()).toList(),
      };

  factory FloorExport.fromJson(Map<String, dynamic> json) => FloorExport(
        floor: Floor.fromJson(Map<String, dynamic>.from(json['floor'] as Map)),
        apartments: ((json['apartments'] ?? const []) as List)
            .map((e) => ApartmentExport.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class BuildingExport {
  final Building building;
  final List<FloorExport> floors;

  const BuildingExport({required this.building, this.floors = const []});

  Map<String, dynamic> toJson() => {
        'building': building.toJson(),
        'floors': floors.map((f) => f.toJson()).toList(),
      };

  factory BuildingExport.fromJson(Map<String, dynamic> json) => BuildingExport(
        building: Building.fromJson(Map<String, dynamic>.from(json['building'] as Map)),
        floors: ((json['floors'] ?? const []) as List)
            .map((e) => FloorExport.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class MasterExport {
  static const int currentVersion = 1;

  final int version;
  final DateTime exportedAt;
  final String ownerId;
  final List<BuildingExport> buildings;

  const MasterExport({
    this.version = currentVersion,
    required this.exportedAt,
    required this.ownerId,
    this.buildings = const [],
  });

  int get buildingCount => buildings.length;
  int get floorCount => buildings.fold(0, (s, b) => s + b.floors.length);
  int get apartmentCount =>
      buildings.fold(0, (s, b) => s + b.floors.fold(0, (s2, f) => s2 + f.apartments.length));

  Map<String, dynamic> toJson() => {
        'schema': 'renttracker.master',
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'ownerId': ownerId,
        'buildings': buildings.map((b) => b.toJson()).toList(),
      };

  factory MasterExport.fromJson(Map<String, dynamic> json) => MasterExport(
        version: (json['version'] ?? currentVersion) as int,
        exportedAt: DateTime.tryParse((json['exportedAt'] ?? '') as String) ?? DateTime.now(),
        ownerId: (json['ownerId'] ?? '') as String,
        buildings: ((json['buildings'] ?? const []) as List)
            .map((e) => BuildingExport.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
