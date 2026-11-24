import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../reports/repositories/reports_storage.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import '../models/event_ticket.dart';
import '../models/event_activity.dart';
import '../models/volunteer_task.dart';
import '../models/event_report.dart';

class EventsData {
  int nextId = 1;
  final Map<int, Event> events = {};
  final Map<int, EventRegistration> registrations = {};
  final Map<int, EventTicket> tickets = {};
  final Map<int, EventActivity> activities = {};
  final Map<int, VolunteerTask> tasks = {};
  final Map<int, EventReport> reports = {};
  EventsData();
  Map<String, dynamic> toJson() => {
    'version': 1,
    'nextId': nextId,
    'events': events.values.map((x) => x.toJson()).toList(),
    'registrations': registrations.values.map((x) => x.toJson()).toList(),
    'tickets': tickets.values.map((x) => x.toJson()).toList(),
    'activities': activities.values.map((x) => x.toJson()).toList(),
    'tasks': tasks.values.map((x) => x.toJson()).toList(),
    'reports': reports.values.map((x) => x.toJson()).toList(),
  };
  factory EventsData.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported event schema');
    }
    final d = EventsData()..nextId = j['nextId'] as int;
    for (final raw in j['events'] as List) {
      final x = Event.fromJson(Map<String, dynamic>.from(raw as Map));
      d.events[x.id] = x;
    }
    for (final raw in j['registrations'] as List) {
      final x = EventRegistration.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.registrations[x.id] = x;
    }
    for (final raw in j['tickets'] as List) {
      final x = EventTicket.fromJson(Map<String, dynamic>.from(raw as Map));
      d.tickets[x.id] = x;
    }
    for (final raw in j['activities'] as List) {
      final x = EventActivity.fromJson(Map<String, dynamic>.from(raw as Map));
      d.activities[x.id] = x;
    }
    for (final raw in j['tasks'] as List) {
      final x = VolunteerTask.fromJson(Map<String, dynamic>.from(raw as Map));
      d.tasks[x.id] = x;
    }
    for (final raw in j['reports'] as List) {
      final x = EventReport.fromJson(Map<String, dynamic>.from(raw as Map));
      d.reports[x.id] = x;
    }
    return d;
  }
}

class EventsDatabase extends ChangeNotifier {
  EventsDatabase(this.storage);
  final ReportsStorage storage;
  EventsData? _data;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  Future<void> _load() async {
    if (_data != null) return;
    final raw = await storage.read();
    _data = raw == null
        ? EventsData()
        : EventsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<T> _run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<T> read<T>(FutureOr<T> Function(EventsData) f) => _run(() async {
    await _load();
    return f(_data!);
  });
  Future<T> mutate<T>(FutureOr<T> Function(EventsData) f) => _run(() async {
    await _load();
    final draft = EventsData.fromJson(_data!.toJson());
    final result = await f(draft);
    await storage.write(jsonEncode(draft.toJson()));
    _data = draft;
    if (!_disposed) notifyListeners();
    return result;
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
