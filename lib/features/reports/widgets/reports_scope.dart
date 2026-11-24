import '../../../core/database/sqlite_runtime_scope.dart';
import '../database/sqlite_reports_database.dart';
import '../repositories/sqlite_reports_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_session.dart';
import '../repositories/reports_storage.dart';
import '../repositories/reports_database.dart';
import '../repositories/local_reports_repository.dart';
import '../services/report_location_service.dart';

class ReportsScope extends StatefulWidget {
  const ReportsScope({
    super.key,
    required this.child,
    this.storage,
    this.location,
  });
  final Widget child;
  final ReportsStorage? storage;
  final ReportLocationService? location;
  @override
  State<ReportsScope> createState() => _ReportsScopeState();
}

class _ReportsScopeState extends State<ReportsScope> {
  late final ReportsDatabase database;
  late final LocalReportsRepository repository;
  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    final runtime = context.read<SqliteRuntime?>()?.context;
    final legacy = widget.storage ?? SembastReportsStorage();
    if (runtime != null) {
      final sql = SqliteReportsDatabase(runtime, legacy);
      database = sql;
      repository = SqliteReportsRepository(sql, () => session.currentUser);
    } else {
      database = ReportsDatabase(legacy);
      repository = LocalReportsRepository(database, () => session.currentUser);
    }
  }

  @override
  void dispose() {
    database.dispose();
    unawaited(database.storage.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider.value(value: repository),
      ChangeNotifierProvider.value(value: database),
      Provider<ReportLocationService>.value(
        value: widget.location ?? DeviceReportLocationService(),
      ),
    ],
    child: widget.child,
  );
}
