import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../reports/repositories/reports_storage.dart';
import '../../veterinary/models/availability.dart';
import '../../veterinary/models/veterinary_appointment.dart';
import '../../veterinary/models/vaccination.dart';
import '../../veterinary/models/care.dart';
import '../../veterinary/models/reminder.dart';
import '../../pet_sitting/models/pet_sitter_settings.dart';
import '../../pet_sitting/models/pet_sitting_request.dart';
import '../../pet_sitting/models/pet_sitting_update.dart';
import '../../pet_sitting/models/review.dart';

class ServicesData {
  int nextId = 1;
  final Map<int, Availability> availability = {};
  final Map<int, VeterinaryAppointment> appointments = {};
  final Map<int, Vaccination> vaccinations = {};
  final Map<int, Care> care = {};
  final Map<int, Reminder> reminders = {};
  final Map<String, PetSitterSettings> settings = {};
  final Map<int, PetSittingRequest> requests = {};
  final Map<int, PetSittingUpdate> updates = {};
  final Map<int, Review> reviews = {};
  Map<String, dynamic> toJson() => {
    'version': 1,
    'nextId': nextId,
    'availability': availability.values.map((v) => v.toJson()).toList(),
    'appointments': appointments.values.map((v) => v.toJson()).toList(),
    'vaccinations': vaccinations.values.map((v) => v.toJson()).toList(),
    'care': care.values.map((v) => v.toJson()).toList(),
    'reminders': reminders.values.map((v) => v.toJson()).toList(),
    'settings': settings.values.map((v) => v.toJson()).toList(),
    'requests': requests.values.map((v) => v.toJson()).toList(),
    'updates': updates.values.map((v) => v.toJson()).toList(),
    'reviews': reviews.values.map((v) => v.toJson()).toList(),
  };
  ServicesData();
  factory ServicesData.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported services schema');
    }
    final d = ServicesData()..nextId = j['nextId'] as int;
    for (final raw in j['availability'] as List) {
      final v = Availability.fromJson(Map<String, dynamic>.from(raw as Map));
      d.availability[v.id] = v;
    }
    for (final raw in j['appointments'] as List) {
      final v = VeterinaryAppointment.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.appointments[v.id] = v;
    }
    for (final raw in j['vaccinations'] as List) {
      final v = Vaccination.fromJson(Map<String, dynamic>.from(raw as Map));
      d.vaccinations[v.id] = v;
    }
    for (final raw in j['care'] as List) {
      final v = Care.fromJson(Map<String, dynamic>.from(raw as Map));
      d.care[v.id] = v;
    }
    for (final raw in j['reminders'] as List) {
      final v = Reminder.fromJson(Map<String, dynamic>.from(raw as Map));
      d.reminders[v.id] = v;
    }
    for (final raw in j['settings'] as List) {
      final v = PetSitterSettings.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.settings[v.userId] = v;
    }
    for (final raw in j['requests'] as List) {
      final v = PetSittingRequest.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.requests[v.id] = v;
    }
    for (final raw in j['updates'] as List) {
      final v = PetSittingUpdate.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.updates[v.id] = v;
    }
    for (final raw in j['reviews'] as List) {
      final v = Review.fromJson(Map<String, dynamic>.from(raw as Map));
      d.reviews[v.id] = v;
    }
    return d;
  }
}

class ServicesDatabase extends ChangeNotifier {
  ServicesDatabase(this.storage);
  final ReportsStorage storage;
  ServicesData? _data;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  Future<void> _load() async {
    if (_data != null) return;
    final raw = await storage.read();
    _data = raw == null
        ? ServicesData()
        : ServicesData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<T> _run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<T> read<T>(Future<T> Function(ServicesData) f) => _run(() async {
    await _load();
    return f(_data!);
  });
  Future<T> mutate<T>(Future<T> Function(ServicesData) f) => _run(() async {
    await _load();
    final draft = ServicesData.fromJson(_data!.toJson());
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
