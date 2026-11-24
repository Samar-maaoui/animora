import '../repositories/sqlite_event_repository.dart';
import '../../../core/database/sqlite_runtime_scope.dart';
import '../database/sqlite_events_database.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_session.dart';
import '../../reports/repositories/reports_storage.dart';
import '../repositories/events_database.dart';
import '../repositories/local_event_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/event_registration_repository.dart';
import '../repositories/event_ticket_repository.dart';
import '../repositories/event_activity_repository.dart';
import '../repositories/volunteer_task_repository.dart';
import '../repositories/event_report_repository.dart';

class EventsStore extends ChangeNotifier {
  EventsStore(this.repository, this.database, this.session) {
    database.addListener(refresh);
    session.addListener(refresh);
  }
  final LocalEventRepository repository;
  final EventsDatabase database;
  final AuthSession session;
  int revision = 0;
  void refresh() {
    revision++;
    notifyListeners();
  }

  EventRepository get events => repository;
  EventRegistrationRepository get registrations => repository;
  EventTicketRepository get tickets => repository;
  EventActivityRepository get activities => repository;
  VolunteerTaskRepository get tasks => repository;
  EventReportRepository get reports => repository;
  DateTime get now => repository.clock();
  @override
  void dispose() {
    database.removeListener(refresh);
    session.removeListener(refresh);
    super.dispose();
  }
}

class EventsScope extends StatefulWidget {
  const EventsScope({super.key, required this.child, this.storage, this.clock});
  final Widget child;
  final ReportsStorage? storage;
  final DateTime Function()? clock;
  @override
  State<EventsScope> createState() => _EventsScopeState();
}

class _EventsScopeState extends State<EventsScope> {
  late final EventsDatabase database;
  late final EventsStore store;
  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    final runtime = context.read<SqliteRuntime?>()?.context;
    final legacy = widget.storage ?? SembastReportsStorage(namespace: 'events');
    database = runtime == null
        ? EventsDatabase(legacy)
        : SqliteEventsDatabase(runtime, legacy);
    store = EventsStore(
      runtime == null
          ? LocalEventRepository(
              database,
              () => session.currentUser,
              session.isUserActive,
              clock: widget.clock,
            )
          : SqliteEventRepository(
              database,
              () => session.currentUser,
              session.isUserActive,
              clock: widget.clock,
            ),
      database,
      session,
    );
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
