import '../core/firestore_utils.dart';

/// A building owned by the flat owner. Top of the property hierarchy.
class Building {
  final String id;
  final String name;
  final String address;

  /// Electricity price per meter unit, in integer minor units (paise/unit).
  /// Set per building and applied to all its apartments.
  final int electricityUnitPrice;
  final DateTime createdAt;

  const Building({
    required this.id,
    required this.name,
    this.address = '',
    this.electricityUnitPrice = 0,
    required this.createdAt,
  });

  factory Building.fromMap(String id, Map<String, dynamic> map) => Building(
        id: id,
        name: (map['name'] ?? '') as String,
        address: (map['address'] ?? '') as String,
        electricityUnitPrice: asInt(map['electricityUnitPrice']),
        createdAt: tsToDate(map['createdAt']),
      );

  Map<String, dynamic> _fields() => {
        'name': name,
        'address': address,
        'electricityUnitPrice': electricityUnitPrice,
      };

  Map<String, dynamic> toMap() => {
        ..._fields(),
        'createdAt': dateToTs(createdAt),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        ..._fields(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        address: (json['address'] ?? '') as String,
        electricityUnitPrice: asInt(json['electricityUnitPrice']),
        createdAt: tsToDate(json['createdAt']),
      );

  Building copyWith({String? name, String? address, int? electricityUnitPrice}) => Building(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        electricityUnitPrice: electricityUnitPrice ?? this.electricityUnitPrice,
        createdAt: createdAt,
      );
}
