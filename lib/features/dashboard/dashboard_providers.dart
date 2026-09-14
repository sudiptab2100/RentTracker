import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/month_key.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/rent_repository.dart';

/// Current-month status for one apartment.
class ApartmentStatus {
  final ApartmentRef ref;

  /// Signed balance: positive = outstanding, negative = advance.
  final int balance;

  const ApartmentStatus({required this.ref, required this.balance});

  bool get isDue => balance > 0;
  int get outstanding => balance > 0 ? balance : 0;
}

/// Aggregated, current-month view of the whole portfolio for the dashboard.
class PortfolioSummary {
  final List<ApartmentStatus> statuses;
  final String month;

  const PortfolioSummary({required this.statuses, required this.month});

  int get apartmentCount => statuses.length;
  int get tenantCount => statuses.where((s) => s.ref.apartment.hasTenant).length;
  int get totalOutstanding =>
      statuses.fold(0, (sum, s) => sum + s.outstanding);
  int get dueCount => statuses.where((s) => s.isDue).length;

  int outstandingForBuilding(String buildingId) => statuses
      .where((s) => s.ref.buildingId == buildingId)
      .fold(0, (sum, s) => sum + s.outstanding);

  int dueCountForBuilding(String buildingId) =>
      statuses.where((s) => s.ref.buildingId == buildingId && s.isDue).length;

  int apartmentsForBuilding(String buildingId) =>
      statuses.where((s) => s.ref.buildingId == buildingId).length;
}

/// Computes each apartment's current-month balance using its stored record
/// (or, if not yet generated, the scheduled rent). Uses per-document reads so
/// no composite Firestore indexes are required.
final portfolioSummaryProvider =
    FutureProvider.autoDispose<PortfolioSummary>((ref) async {
  final aptRepo = ref.watch(apartmentRepositoryProvider);
  final rentRepo = ref.watch(rentRepositoryProvider);
  final month = MonthKey.current();

  final apartments = await aptRepo.watchAllForOwner().first;
  final statuses = <ApartmentStatus>[];
  for (final a in apartments) {
    final record = await rentRepo.getRecord(a.path, month);
    final first = a.apartment.firstEffectiveMonth;
    final expected = (first != null && MonthKey.compare(first, month) <= 0)
        ? a.apartment.rentForMonth(month)
        : 0;
    final due = record?.totalDue ?? expected;
    final paid = record?.paidAmount ?? 0;
    statuses.add(ApartmentStatus(ref: a, balance: due - paid));
  }
  return PortfolioSummary(statuses: statuses, month: month);
});
