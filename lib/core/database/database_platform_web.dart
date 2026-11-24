import 'database_helper.dart';

bool get supportsNativeSqlite => false;
DatabaseHelper createPlatformDatabase() => throw UnsupportedError(
  'SQFlite natif n’est pas utilisé sur cette plateforme.',
);
