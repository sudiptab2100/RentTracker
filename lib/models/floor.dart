import '../core/firestore_utils.dart';

/// A floor within a [Building].
class Floor {
  final String id;
  final String name;
  final int order;
  final DateTime createdAt;

  const Floor({
    required this.id,
    required this.name,
    this.order = 0,
    required this.createdAt,
  });

  factory Floor.fromMap(String id, Map<String, dynamic> map) => Floor(
        id: id,
        name: (map['name'] ?? '') as String,
        order: asInt(map['order']),
        createdAt: tsToDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'order': order,
        'createdAt': dateToTs(createdAt),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        order: asInt(json['order']),
        createdAt: tsToDate(json['createdAt']),
      );

  Floor copyWith({String? name, int? order}) => Floor(
        id: id,
        name: name ?? this.name,
        order: order ?? this.order,
        createdAt: createdAt,
      );
}
