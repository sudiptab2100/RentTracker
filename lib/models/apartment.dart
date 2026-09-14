import '../core/firestore_utils.dart';
import '../core/month_key.dart';
import 'rent_schedule_entry.dart';

/// An apartment/unit within a [Floor], including tenant contact details, the
/// (separately tracked) security deposit and the effective-dated rent schedule.
class Apartment {
  final String id;

  /// Unit label, e.g. "1A" or "Flat 302".
  final String name;
  final String tenantName;
  final String address;
  final String contactNumber;
  final String whatsappNumber;
  final String emergencyNumber;

  /// Security deposit in integer minor units (paise). Tracked separately from
  /// rent and never mixed into the monthly balance.
  final int securityDeposit;

  /// Effective-dated rent amounts, ascending by [RentScheduleEntry.effectiveFrom].
  final List<RentScheduleEntry> rentSchedule;
  final DateTime createdAt;

  const Apartment({
    required this.id,
    required this.name,
    this.tenantName = '',
    this.address = '',
    this.contactNumber = '',
    this.whatsappNumber = '',
    this.emergencyNumber = '',
    this.securityDeposit = 0,
    this.rentSchedule = const [],
    required this.createdAt,
  });

  /// The rent amount (paise) that applies for the given [month] key.
  int rentForMonth(String month) {
    RentScheduleEntry? chosen;
    for (final e in rentSchedule) {
      if (MonthKey.compare(e.effectiveFrom, month) <= 0) {
        if (chosen == null || MonthKey.compare(e.effectiveFrom, chosen.effectiveFrom) > 0) {
          chosen = e;
        }
      }
    }
    if (chosen != null) return chosen.amount;
    // Month precedes the earliest schedule entry: fall back to the earliest.
    RentScheduleEntry? earliest;
    for (final e in rentSchedule) {
      if (earliest == null || MonthKey.compare(e.effectiveFrom, earliest.effectiveFrom) < 0) {
        earliest = e;
      }
    }
    return earliest?.amount ?? 0;
  }

  /// The earliest month for which rent is defined; drives lazy generation.
  String? get firstEffectiveMonth {
    String? earliest;
    for (final e in rentSchedule) {
      if (earliest == null || MonthKey.compare(e.effectiveFrom, earliest) < 0) {
        earliest = e.effectiveFrom;
      }
    }
    return earliest;
  }

  int get currentRent => rentForMonth(MonthKey.current());

  bool get hasTenant => tenantName.trim().isNotEmpty;

  factory Apartment.fromMap(String id, Map<String, dynamic> map) => Apartment(
        id: id,
        name: (map['name'] ?? '') as String,
        tenantName: (map['tenantName'] ?? '') as String,
        address: (map['address'] ?? '') as String,
        contactNumber: (map['contactNumber'] ?? '') as String,
        whatsappNumber: (map['whatsappNumber'] ?? '') as String,
        emergencyNumber: (map['emergencyNumber'] ?? '') as String,
        securityDeposit: asInt(map['securityDeposit']),
        rentSchedule: ((map['rentSchedule'] ?? const []) as List)
            .map((e) => RentScheduleEntry.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: tsToDate(map['createdAt']),
      );

  Map<String, dynamic> _fields() => {
        'name': name,
        'tenantName': tenantName,
        'address': address,
        'contactNumber': contactNumber,
        'whatsappNumber': whatsappNumber,
        'emergencyNumber': emergencyNumber,
        'securityDeposit': securityDeposit,
        'rentSchedule': rentSchedule.map((e) => e.toMap()).toList(),
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

  factory Apartment.fromJson(Map<String, dynamic> json) => Apartment.fromMap(
        (json['id'] ?? '') as String,
        json,
      );

  Apartment copyWith({
    String? name,
    String? tenantName,
    String? address,
    String? contactNumber,
    String? whatsappNumber,
    String? emergencyNumber,
    int? securityDeposit,
    List<RentScheduleEntry>? rentSchedule,
  }) =>
      Apartment(
        id: id,
        name: name ?? this.name,
        tenantName: tenantName ?? this.tenantName,
        address: address ?? this.address,
        contactNumber: contactNumber ?? this.contactNumber,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        emergencyNumber: emergencyNumber ?? this.emergencyNumber,
        securityDeposit: securityDeposit ?? this.securityDeposit,
        rentSchedule: rentSchedule ?? this.rentSchedule,
        createdAt: createdAt,
      );
}
