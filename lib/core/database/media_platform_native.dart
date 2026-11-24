import '../../features/reports/repositories/reports_storage.dart';
import 'file_media_storage.dart';
import 'sql_module.dart';

MigratingMediaStorage createMediaStorage(
  String namespace,
  ReportsStorage legacy,
) => FileMediaStorage(namespace, legacy);
