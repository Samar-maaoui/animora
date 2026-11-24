import 'dart:async';

import '../../../core/database/sql_module.dart';
import '../repositories/events_database.dart';
import '../../reports/repositories/reports_storage.dart';
import 'events_sql_schema.dart';

class SqliteEventsDatabase extends EventsDatabase {
  SqliteEventsDatabase(this.context8, ReportsStorage legacy) : super(legacy) {
    sql = SqlModuleStore(
      context: context8,
      namespace: 'events',
      tables: EventsSqlSchema.tables,
      legacy: legacy,
      empty: () => EventsData().toJson(),
      canonicalize: (j) => EventsData.fromJson(j).toJson(),
    );
  }
  final SqliteModuleContext context8;
  late final SqlModuleStore sql;
  @override
  ReportsStorage get storage => sql.storage;

  @override
  Future<T> read<T>(FutureOr<T> Function(EventsData) f) =>
      sql.read((j) => f(EventsData.fromJson(j)));
  @override
  Future<T> mutate<T>(FutureOr<T> Function(EventsData) f) async {
    final result = await sql.mutate((j) async {
      final d = EventsData.fromJson(j);
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
