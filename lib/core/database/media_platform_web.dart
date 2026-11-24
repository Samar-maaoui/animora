import '../../features/reports/repositories/reports_storage.dart';
import 'sql_module.dart';

MigratingMediaStorage createMediaStorage(
  String namespace,
  ReportsStorage legacy,
) => throw UnsupportedError('Les médias Web restent dans Sembast Web.');
