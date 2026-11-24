import '../repositories/sqlite_services_repository.dart';
import '../../../core/database/sqlite_runtime_scope.dart';
import '../database/sqlite_animal_services_database.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_session.dart';
import '../../adoption/repositories/local_catalog_database.dart';
import '../../reports/repositories/reports_storage.dart';
import '../repositories/services_database.dart';
import '../repositories/local_services_repository.dart';
import '../../veterinary/repositories/veterinary_repository.dart';
import '../../veterinary/repositories/availability_repository.dart';
import '../../veterinary/repositories/veterinary_appointment_repository.dart';
import '../../veterinary/repositories/vaccination_repository.dart';
import '../../veterinary/repositories/care_repository.dart';
import '../../veterinary/repositories/reminder_repository.dart';
import '../../pet_sitting/repositories/pet_sitting_repository.dart';
import '../../pet_sitting/repositories/pet_sitting_update_repository.dart';
import '../../pet_sitting/repositories/review_repository.dart';

class ServicesStore extends ChangeNotifier {
  ServicesStore(this.repository, this.database, this.session, this.catalog) {
    database.addListener(changed);
    session.addListener(changed);
    catalog.addListener(changed);
  }
  final LocalServicesRepository repository;
  final ServicesDatabase database;
  final AuthSession session;
  final LocalCatalogDatabase catalog;
  int revision = 0;
  void refresh() => changed();
  void changed() {
    revision++;
    notifyListeners();
  }

  VeterinaryRepository get veterinary => repository;
  AvailabilityRepository get availability => repository;
  VeterinaryAppointmentRepository get appointments => repository;
  VaccinationRepository get vaccinations => repository;
  CareRepository get care => repository;
  ReminderRepository get reminders => repository;
  PetSittingRepository get petSitting => repository;
  PetSittingUpdateRepository get updates => repository;
  ReviewRepository get reviews => repository;
  @override
  void dispose() {
    database.removeListener(changed);
    session.removeListener(changed);
    catalog.removeListener(changed);
    super.dispose();
  }
}

class ServicesScope extends StatefulWidget {
  const ServicesScope({
    super.key,
    required this.child,
    this.storage,
    this.clock,
  });
  final Widget child;
  final ReportsStorage? storage;
  final DateTime Function()? clock;
  @override
  State<ServicesScope> createState() => _ServicesScopeState();
}

class _ServicesScopeState extends State<ServicesScope> {
  late final ServicesDatabase database;
  late final ServicesStore store;
  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>(),
        catalog = context.read<LocalCatalogDatabase>();
    final runtime = context.read<SqliteRuntime?>()?.context;
    final legacy =
        widget.storage ?? SembastReportsStorage(namespace: 'care_services');
    database = runtime == null
        ? ServicesDatabase(legacy)
        : SqliteServicesDatabase(runtime, legacy);
    final repository = runtime == null
        ? LocalServicesRepository(
            database,
            catalog,
            () => session.currentUser,
            session.listServiceProviders,
            clock: widget.clock,
          )
        : SqliteServicesRepository(
            database,
            catalog,
            () => session.currentUser,
            session.listServiceProviders,
            clock: widget.clock,
          );
    store = ServicesStore(repository, database, session, catalog);
  }

  @override
  void dispose() {
    store.dispose();
    database.dispose();
    unawaited(database.storage.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext c) =>
      ChangeNotifierProvider.value(value: store, child: widget.child);
}
