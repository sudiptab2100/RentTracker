import 'package:cloud_firestore/cloud_firestore.dart';

/// Coerces a Firestore/JSON value into a [DateTime]. Handles [Timestamp]
/// (Firestore), ISO-8601 strings (master export/import) and epoch millis.
DateTime tsToDate(dynamic v, {DateTime? fallback}) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v) ?? (fallback ?? DateTime.now());
  return fallback ?? DateTime.now();
}

/// Wraps a [DateTime] as a Firestore [Timestamp].
Timestamp dateToTs(DateTime d) => Timestamp.fromDate(d);

/// Safely reads an integer field that may arrive as int, double or num.
int asInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}
