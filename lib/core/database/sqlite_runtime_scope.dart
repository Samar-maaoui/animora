import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/adoption/database/business_user_source.dart';
import '../../features/adoption/database/sqlite_catalog_database.dart';
import '../../features/adoption/services/catalog_storage.dart';
import '../../features/auth/services/local_auth_storage.dart';
import 'sql_module.dart';
import 'database_platform.dart' as platform;
import 'media_platform.dart' as media;

/// App-level connection owner. Optional injection keeps tests isolated.
class SqliteRuntime {
  const SqliteRuntime(this.context);
  final SqliteModuleContext? context;
}

class SqliteRuntimeScope extends StatefulWidget {
  const SqliteRuntimeScope({super.key, required this.child, this.context});
  final Widget child;
  final SqliteModuleContext? context;
  @override
  State<SqliteRuntimeScope> createState() => _SqliteRuntimeScopeState();
}

class _SqliteRuntimeScopeState extends State<SqliteRuntimeScope> {
  late final SqliteModuleContext? context8;
  @override
  void initState() {
    super.initState();
    if (widget.context != null) {
      context8 = widget.context;
    } else if (platform.supportsNativeSqlite) {
      final helper = platform.createPlatformDatabase();
      final users = BusinessUserSource(PreferencesAuthStorage());
      final catalog = SqliteCatalogDatabase(
        PreferencesCatalogStorage(),
        helper: helper,
        loadBusinessUsers: users.read,
        ownsHelper: false,
      );
      context8 = SqliteModuleContext(
        helper: helper,
        catalog: catalog,
        loadUsers: users.read,
        mediaFactory: media.createMediaStorage,
      );
    } else {
      context8 = null;
    }
  }

  @override
  void dispose() {
    if (widget.context == null && context8 != null) {
      unawaited(context8!.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) =>
      Provider.value(value: SqliteRuntime(context8), child: widget.child);
}
