import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/master_export.dart';
import '../../repositories/building_repository.dart';
import '../../repositories/export_repository.dart';
import '../../widgets/ui_helpers.dart';
import '../dashboard/dashboard_providers.dart';
import '../reports/csv_export.dart';
import '../whatsapp/whatsapp_service.dart';

class DataTransferScreen extends ConsumerStatefulWidget {
  const DataTransferScreen({super.key});

  @override
  ConsumerState<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends ConsumerState<DataTransferScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = label;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stamp() => DateTime.now().toIso8601String().split('T').first;

  Future<void> _masterExport() => _run('Building master export…', () async {
        final data = await ref.read(exportRepositoryProvider).exportAll();
        final json = const JsonEncoder.withIndent('  ').convert(data.toJson());
        await whatsAppService.shareBytes(
          Uint8List.fromList(utf8.encode(json)),
          'renttracker_backup_${_stamp()}.json',
          subject: 'RentTracker master backup',
          text: 'RentTracker backup — ${data.buildingCount} building(s), '
              '${data.apartmentCount} apartment(s).',
        );
      });

  Future<void> _exportTenantsCsv() => _run('Building tenants CSV…', () async {
        final data = await ref.read(exportRepositoryProvider).exportAll();
        final csv = CsvExport.masterTenants(data);
        await whatsAppService.shareBytes(
          Uint8List.fromList(utf8.encode(csv)),
          'tenants_${_stamp()}.csv',
          subject: 'Tenant details',
        );
      });

  Future<void> _exportLedgerCsv() => _run('Building ledger CSV…', () async {
        final data = await ref.read(exportRepositoryProvider).exportAll();
        final csv = CsvExport.masterLedger(data);
        await whatsAppService.shareBytes(
          Uint8List.fromList(utf8.encode(csv)),
          'rent_ledger_${_stamp()}.csv',
          subject: 'Full rent ledger',
        );
      });

  Future<void> _masterImport() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty) return;

    final Uint8List bytes = await files.first.readAsBytes();

    MasterExport data;
    try {
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      data = MasterExport.fromJson(decoded);
    } catch (e) {
      if (mounted) showSnack(context, 'Invalid backup file: $e', isError: true);
      return;
    }

    if (!mounted) return;
    final mode = await _askImportMode(data);
    if (mode == null) return;

    await _run('Importing data…', () async {
      final res = await ref
          .read(exportRepositoryProvider)
          .importAll(data, wipeExisting: mode == _ImportMode.replace);
      ref.invalidate(buildingsProvider);
      ref.invalidate(overviewProvider);
      if (mounted) {
        showSnack(context, 'Imported $res');
      }
    });
  }

  Future<_ImportMode?> _askImportMode(MasterExport data) {
    return showDialog<_ImportMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This backup contains:'),
            const SizedBox(height: 8),
            Text('• ${data.buildingCount} building(s)'),
            Text('• ${data.floorCount} floor(s)'),
            Text('• ${data.apartmentCount} apartment(s)'),
            const SizedBox(height: 16),
            const Text('How should it be imported?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ImportMode.merge),
            child: const Text('Merge'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, _ImportMode.replace),
            child: const Text('Replace all'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data export & import')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(context, 'Master backup (migration)'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_download_outlined),
                      title: const Text('Master export (JSON)'),
                      subtitle: const Text(
                          'Full backup of all buildings, floors, apartments and rent history'),
                      onTap: _busy ? null : _masterExport,
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: const Text('Master import (JSON)'),
                      subtitle: const Text(
                          'Restore or migrate into this Firebase project (merge or replace)'),
                      onTap: _busy ? null : _masterImport,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section(context, 'CSV exports (record-keeping)'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.people_outline),
                      title: const Text('Tenant details (CSV)'),
                      subtitle: const Text('One row per apartment with balances'),
                      onTap: _busy ? null : _exportTenantsCsv,
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.table_chart_outlined),
                      title: const Text('Full rent ledger (CSV)'),
                      subtitle: const Text('One row per month per apartment'),
                      onTap: _busy ? null : _exportLedgerCsv,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The JSON backup is the recommended format for migrating to another '
                'app or a different Firebase project. Original IDs are preserved so '
                'imports stay stable.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_status),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

enum _ImportMode { merge, replace }
