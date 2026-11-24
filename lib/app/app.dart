import '../core/network/api_scope.dart';
import '../core/database/sqlite_runtime_scope.dart';
import '../core/database/database_platform.dart' as platform;
import '../features/auth/services/biometric_service.dart';
import '../features/events/widgets/events_scope.dart';
import '../features/donations/widgets/donations_scope.dart';
import '../features/animal_services/widgets/services_scope.dart';
import '../features/reports/widgets/reports_scope.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/repositories/auth_repository.dart';
import '../features/auth/services/auth_backend.dart';
import '../features/auth/state/auth_session.dart';
import '../features/adoption/widgets/adoption_scope.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class AnimoraApp extends StatefulWidget {
  const AnimoraApp({super.key, this.repository, this.backend})
    : assert(repository == null || backend == null);
  final AuthBackend? backend;
  final AuthRepository? repository;
  @override
  State<AnimoraApp> createState() => _AnimoraAppState();
}

class _AnimoraAppState extends State<AnimoraApp> {
  late final AuthRepository _repository;
  AuthBackend? _backend;
  late final AuthSession _session;
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    if (widget.repository == null) {
      _backend = widget.backend ?? createAuthBackend();
    }
    _repository = widget.repository ?? _backend!.repository;
    // Fingerprint/face only with the production backend on Android/iOS.
    _session = AuthSession(
      _repository,
      biometrics:
          widget.repository == null &&
              widget.backend == null &&
              platform.supportsNativeSqlite
          ? DeviceBiometricService()
          : const UnavailableBiometricService(),
    );
    _router = createAppRouter(session: _session);
    unawaited(_session.initialize());
  }

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    if (widget.repository == null && widget.backend == null) {
      _repository.dispose();
      final close = _backend?.close;
      if (close != null) unawaited(close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _session,
    child: ApiScope(
      child: SqliteRuntimeScope(
        context: _backend?.context,
        child: ReportsScope(
          child: AdoptionScope(
            child: ServicesScope(
              child: DonationsScope(
                child: EventsScope(
                  child: MaterialApp.router(
                    title: 'Animora',
                    locale: const Locale('fr'),
                    supportedLocales: const [Locale('fr')],
                    localizationsDelegates:
                        GlobalMaterialLocalizations.delegates,
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    routerConfig: _router,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
