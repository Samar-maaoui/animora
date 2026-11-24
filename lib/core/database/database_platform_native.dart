import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

bool get supportsNativeSqlite => Platform.isAndroid || Platform.isIOS;
DatabaseHelper createPlatformDatabase() =>
    DatabaseHelper(factory: databaseFactory);
