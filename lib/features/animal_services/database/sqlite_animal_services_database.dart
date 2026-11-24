import 'dart:async';

import '../../../core/database/sql_module.dart';
import '../repositories/services_database.dart';
import '../../reports/repositories/reports_storage.dart';
import 'animal_services_sql_schema.dart';

class SqliteServicesDatabase extends ServicesDatabase {
  SqliteServicesDatabase(this.context8, ReportsStorage legacy) : super(legacy) {
    sql = SqlModuleStore(
      context: context8,
      namespace: 'care_services',
      tables: ServicesSqlSchema.tables,
      legacy: legacy,
      empty: () => ServicesData().toJson(),
      canonicalize: (j) => ServicesData.fromJson(j).toJson(),
    );
  }
  final SqliteModuleContext context8;
  late final SqlModuleStore sql;
  @override
  ReportsStorage get storage => sql.storage;

  @override
  Future<T> read<T>(Future<T> Function(ServicesData) f) =>
      sql.read((j) => f(ServicesData.fromJson(j)));
  @override
  Future<T> mutate<T>(Future<T> Function(ServicesData) f) async {
    final result = await sql.mutate((j) async {
      final d = ServicesData.fromJson(j);
      final result = await f(d);
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
