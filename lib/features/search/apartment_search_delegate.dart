import 'package:flutter/material.dart';

import '../../widgets/balance_view.dart';
import '../dashboard/dashboard_providers.dart';

/// Searches the already-loaded apartments in memory (from overviewProvider) by
/// tenant name (and unit name). No Firestore fields, indexes or queries change.
/// Returns the chosen apartment so the caller can navigate to it.
class ApartmentSearchDelegate extends SearchDelegate<ApartmentOverview?> {
  ApartmentSearchDelegate(this.apartments)
      : super(searchFieldLabel: 'Search by tenant name');

  final List<ApartmentOverview> apartments;

  List<ApartmentOverview> _matches() {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return apartments;
    return apartments.where((a) {
      final tenant = a.apartment.tenantName.toLowerCase();
      final unit = a.apartment.name.toLowerCase();
      return tenant.contains(q) || unit.contains(q);
    }).toList();
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final results = _matches();
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No matching tenants'),
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final a = results[i];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(a.apartment.tenantName.isEmpty ? 'Vacant' : a.apartment.tenantName),
          subtitle: Text(
            '${a.apartment.name} \u00B7 ${a.buildingName}'
            '${a.floorName.isEmpty ? '' : ' \u00B7 ${a.floorName}'}',
          ),
          trailing: a.balance != 0 ? BalanceChip(balance: a.balance) : null,
          onTap: () => close(context, a),
        );
      },
    );
  }
}
