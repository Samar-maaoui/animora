import 'dart:async';

import '../../../core/database/sql_module.dart';
import '../repositories/reports_database.dart';
import '../../reports/repositories/reports_storage.dart';
import 'reports_sql_schema.dart';

class SqliteReportsDatabase extends ReportsDatabase {
  SqliteReportsDatabase(this.context8, ReportsStorage legacy) : super(legacy) {
    sql = SqlModuleStore(
      context: context8,
      namespace: 'reports',
      tables: ReportsSqlSchema.tables,
      legacy: legacy,
      empty: () => ReportsData().toJson(),
      canonicalize: (j) => ReportsData.fromJson(j).toJson(),
    );
  }
  final SqliteModuleContext context8;
  late final SqlModuleStore sql;
  @override
  ReportsStorage get storage => sql.storage;
  @override
  Future<void> initialize() => context8.ensure('reports');
  @override
  Future<T> read<T>(T Function(ReportsData) action) =>
      sql.read((j) => action(ReportsData.fromJson(j)));
  @override
  Future<T> mutate<T>(T Function(ReportsData) action) async {
    final result = await sql.mutate((j) async {
      final d = ReportsData.fromJson(j);
      final result = action(d);
      return (d.toJson(), result);
    });
    if (!_disposed8) notifyListeners();
    return result;
  }

  bool _disposed8 = false;
  @override
  void dispose() {
    _disposed8 = true;
    sql.dispose();
    super.dispose();
  }
}
