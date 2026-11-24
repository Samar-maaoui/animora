import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'reports_storage.dart';
import '../models/signalement.dart';
import '../models/confirmation_signalement.dart';
import '../models/annonce.dart';
import '../models/temoignage.dart';
import '../models/zone_recherche.dart';
import '../models/correspondance.dart';
import '../models/reclamation.dart';
import '../models/histoire_retrouvailles.dart';

class ReportsData {
  int nextId = 1;
  final Map<int, Signalement> reports = {};
  final Map<int, ConfirmationSignalement> confirmations = {};
  final Map<int, Annonce> announcements = {};
  final Map<int, Temoignage> testimonies = {};
  final Map<int, ZoneRecherche> zones = {};
  final Map<int, Correspondance> matches = {};
  final Map<int, Reclamation> claims = {};
  final Map<int, HistoireRetrouvailles> stories = {};
  Map<String, dynamic> toJson() => {
    'nextId': nextId,
    'reports': reports.values.map((v) => v.toJson()).toList(),
    'confirmations': confirmations.values.map((v) => v.toJson()).toList(),
    'announcements': announcements.values.map((v) => v.toJson()).toList(),
    'testimonies': testimonies.values.map((v) => v.toJson()).toList(),
    'zones': zones.values.map((v) => v.toJson()).toList(),
    'matches': matches.values.map((v) => v.toJson()).toList(),
    'claims': claims.values.map((v) => v.toJson()).toList(),
    'stories': stories.values.map((v) => v.toJson()).toList(),
  };
  factory ReportsData.fromJson(Map<String, dynamic> j) {
    final d = ReportsData()..nextId = j['nextId'] as int;
    for (final value in j['reports'] as List) {
      final v = Signalement.fromJson(Map<String, dynamic>.from(value as Map));
      d.reports[v.id] = v;
    }
    for (final value in j['confirmations'] as List) {
      final v = ConfirmationSignalement.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      d.confirmations[v.id] = v;
    }
    for (final value in j['announcements'] as List) {
      final v = Annonce.fromJson(Map<String, dynamic>.from(value as Map));
      d.announcements[v.id] = v;
    }
    for (final value in j['testimonies'] as List) {
      final v = Temoignage.fromJson(Map<String, dynamic>.from(value as Map));
      d.testimonies[v.id] = v;
    }
    for (final value in j['zones'] as List) {
      final v = ZoneRecherche.fromJson(Map<String, dynamic>.from(value as Map));
      d.zones[v.announcementId] = v;
    }
    for (final value in j['matches'] as List) {
      final v = Correspondance.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      d.matches[v.id] = v;
    }
    for (final value in j['claims'] as List) {
      final v = Reclamation.fromJson(Map<String, dynamic>.from(value as Map));
      d.claims[v.id] = v;
    }
    for (final value in j['stories'] as List) {
      final v = HistoireRetrouvailles.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      d.stories[v.id] = v;
    }
    return d;
  }
  ReportsData();
}

class ReportsDatabase extends ChangeNotifier {
  ReportsDatabase(this.storage);
  final ReportsStorage storage;
  ReportsData? _data;
  Future<void>? _loading;
  Future<void> _tail = Future.value();
  Future<void> initialize() => _loading ??= _load();
  Future<void> _load() async {
    final raw = await storage.read();
    _data = raw == null
        ? ReportsData()
        : ReportsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<T> read<T>(T Function(ReportsData) action) async {
    await initialize();
    await _tail;
    return action(_data!);
  }

  Future<T> mutate<T>(T Function(ReportsData) action) {
    final result = _tail.then((_) async {
      await initialize();
      final draft = ReportsData.fromJson(_data!.toJson());
      final value = action(draft);
      await storage.write(jsonEncode(draft.toJson()));
      _data = draft;
      notifyListeners();
      return value;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
