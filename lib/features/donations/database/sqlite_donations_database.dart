import 'dart:async';

import '../../../core/database/sql_module.dart';
import '../repositories/donations_database.dart';
import '../../reports/repositories/reports_storage.dart';
import 'donations_sql_schema.dart';

class SqliteDonationsDatabase extends DonationsDatabase {
  SqliteDonationsDatabase(this.context8, ReportsStorage legacy)
    : super(legacy) {
    sql = SqlModuleStore(
      context: context8,
      namespace: 'donations',
      tables: DonationsSqlSchema.tables,
      legacy: legacy,
      empty: () => DonationsData().toJson(),
      canonicalize: (j) => DonationsData.fromJson(j).toJson(),
      normalize: _totals,
    );
  }
  final SqliteModuleContext context8;
  late final SqlModuleStore sql;
  @override
  ReportsStorage get storage => sql.storage;

  @override
  Future<T> read<T>(T Function(DonationsData) f) =>
      sql.read((j) => f(DonationsData.fromJson(j)));
  @override
  Future<T> mutate<T>(T Function(DonationsData) f) async {
    final result = await sql.mutate((j) async {
      final d = DonationsData.fromJson(j);
      final result = f(d);
      return (d.toJson(), result);
    });
    if (!_disposed8) notifyListeners();
    return result;
  }

  static void _totals(Map<String, dynamic> d) {
    final donations = (d['donations'] as List).cast<Map<String, dynamic>>();
    for (final c in d['campaigns'] as List) {
      var total = 0;
      for (final x in donations) {
        if (x['campaignId'] == c['id'] &&
            x['type'] == 'FINANCIAL' &&
            x['status'] == 'CONFIRMED') {
          total += ((x['amount'] as num) * 1000).round();
        }
      }
      c['collectedAmount'] = total / 1000;
    }
    for (final n in d['needs'] as List) {
      var q = 0;
      for (final m in d['materials'] as List) {
        if (m['materialNeedId'] == n['id'] &&
            m['status'] == 'RECEIVED' &&
            donations.any(
              (x) => x['id'] == m['donationId'] && x['status'] == 'CONFIRMED',
            )) {
          q += m['quantity'] as int;
        }
      }
      n['receivedQuantity'] = q;
      n['status'] = q == 0
          ? 'OPEN'
          : q >= (n['requestedQuantity'] as int)
          ? 'FULFILLED'
          : 'PARTIALLY_FULFILLED';
    }
  }

  bool _disposed8 = false;
  @override
  void dispose() {
    _disposed8 = true;
    sql.dispose();
    super.dispose();
  }
}
