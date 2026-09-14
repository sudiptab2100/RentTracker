import '../core/firestore_utils.dart';

/// A building owned by the flat owner. Top of the property hierarchy.
class Building {
  final String id;
  final String name;
  final String address;
  final DateTime createdAt;

  const Building({
    required this.id,
    required this.name,
    this.address = '',
    required this.createdAt,
  });

  factory Building.fromMap(String id, Map<String, dynamic> map) => Building(
        id: id,
        name: (map['name'] ?? '') as String,
        address: (map['address'] ?? '') as String,
        createdAt: tsToDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'createdAt': dateToTs(createdAt),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        address: (json['address'] ?? '') as String,
        createdAt: tsToDate(json['createdAt']),
      );

  Building copyWith({String? name, String? address}) => Building(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        createdAt: createdAt,
      );
}
