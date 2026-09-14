import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/month_key.dart';
import '../../models/apartment.dart';
import '../../models/extra_charge.dart';
import '../../models/payment.dart';
import '../../models/rent_record.dart';
import '../../models/rent_schedule_entry.dart';
import '../../repositories/apartment_repository.dart';
import '../../repositories/rent_repository.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

/// Business logic for the monthly rent ledger: lazy month generation, payments,
/// charges and effective-dated rent changes.
class RentEngine {
  RentEngine(this._rent, this._apartments);

  final RentRepository _rent;
  final ApartmentRepository _apartments;

  /// Ensures a [RentRecord] exists for every month from the apartment's first
  /// effective rent month up to the current month. Idempotent: only missing
  /// months are created. No-op for apartments without a rent schedule.
  Future<int> ensureGenerated(ApartmentPath path, Apartment apt) async {
    final start = apt.firstEffectiveMonth;
    if (start == null) return 0; // no rent configured yet
    final end = MonthKey.current();
    if (MonthKey.compare(start, end) > 0) return 0;

    final existing = await _rent.getAllRecords(path);
    final existingMonths = existing.map((r) => r.month).toSet();

    final toCreate = <RentRecord>[];
    for (final month in MonthKey.range(start, end)) {
      if (existingMonths.contains(month)) continue;
      toCreate.add(RentRecord(
        month: month,
        rentAmount: apt.rentForMonth(month),
        createdAt: DateTime.now(),
      ));
    }
    await _rent.setRecords(path, toCreate);
    return toCreate.length;
  }

  /// Returns the record for [month], creating (and persisting) it from the
  /// apartment's schedule if it does not yet exist.
  Future<RentRecord> ensureRecord(ApartmentPath path, Apartment apt, String month) async {
    final existing = await _rent.getRecord(path, month);
    if (existing != null) return existing;
    final record = RentRecord(
      month: month,
      rentAmount: apt.rentForMonth(month),
      createdAt: DateTime.now(),
    );
    await _rent.setRecord(path, record);
    return record;
  }

  Future<void> addPayment(
    ApartmentPath path,
    Apartment apt,
    String month, {
    required int amount,
    DateTime? date,
    String note = '',
  }) async {
    final record = await ensureRecord(path, apt, month);
    final payment = Payment(
      id: newId(),
      amount: amount,
      date: date ?? DateTime.now(),
      note: note,
    );
    await _rent.setRecord(path, record.copyWith(payments: [...record.payments, payment]));
  }

  Future<void> deletePayment(ApartmentPath path, String month, String paymentId) async {
    final record = await _rent.getRecord(path, month);
    if (record == null) return;
    final payments = record.payments.where((p) => p.id != paymentId).toList();
    await _rent.setRecord(path, record.copyWith(payments: payments));
  }

  Future<void> setElectricBill(
    ApartmentPath path,
    Apartment apt,
    String month,
    int amount,
  ) async {
    final record = await ensureRecord(path, apt, month);
    await _rent.setRecord(path, record.copyWith(electricBill: amount));
  }

  Future<void> setExtraCharges(
    ApartmentPath path,
    Apartment apt,
    String month,
    List<ExtraCharge> charges,
  ) async {
    final record = await ensureRecord(path, apt, month);
    await _rent.setRecord(path, record.copyWith(extraCharges: charges));
  }

  Future<void> setRentForMonth(
    ApartmentPath path,
    Apartment apt,
    String month,
    int rentAmount,
  ) async {
    final record = await ensureRecord(path, apt, month);
    await _rent.setRecord(path, record.copyWith(rentAmount: rentAmount));
  }

  /// Applies a rent change. When [effectiveThisMonth] is true it takes effect
  /// from the current month (updating the current record too); otherwise it
  /// takes effect next month.
  Future<void> updateRent(
    ApartmentPath path,
    Apartment apt,
    int newAmount, {
    required bool effectiveThisMonth,
  }) async {
    final effectiveFrom = effectiveThisMonth ? MonthKey.current() : MonthKey.next(MonthKey.current());

    final schedule = apt.rentSchedule
        .where((e) => e.effectiveFrom != effectiveFrom)
        .toList()
      ..add(RentScheduleEntry(effectiveFrom: effectiveFrom, amount: newAmount))
      ..sort((a, b) => MonthKey.compare(a.effectiveFrom, b.effectiveFrom));

    await _apartments.update(path.$1, path.$2, apt.copyWith(rentSchedule: schedule));

    if (effectiveThisMonth) {
      final current = await _rent.getRecord(path, effectiveFrom);
      if (current != null) {
        await _rent.setRecord(path, current.copyWith(rentAmount: newAmount));
      }
    }
  }
}

final rentEngineProvider = Provider<RentEngine>(
  (ref) => RentEngine(
    ref.watch(rentRepositoryProvider),
    ref.watch(apartmentRepositoryProvider),
  ),
);
