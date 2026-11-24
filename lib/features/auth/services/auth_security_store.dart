import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_event.dart';

/// Security journal and small per-device settings (biometric enrollment).
/// Kept apart from the account snapshot: it never contains passwords,
/// hashes or session identifiers.
abstract interface class AuthSecurityStore {
  Future<void> record(AuthEvent event);

  /// Newest first. [email] filters one account; [since] keeps recent events.
  Future<List<AuthEvent>> events({
    int limit = 100,
    String? email,
    DateTime? since,
  });
  Future<String?> readSetting(String key);
  Future<void> writeSetting(String key, String? value);
}

/// Shared filtering for the list-based stores below.
List<AuthEvent> _select(
  Iterable<AuthEvent> all, {
  required int limit,
  String? email,
  DateTime? since,
}) {
  final list =
      all
          .where((e) => email == null || e.email == email)
          .where((e) => since == null || e.createdAt.isAfter(since))
          .toList()
        ..sort((a, b) {
          final byDate = b.createdAt.compareTo(a.createdAt);
          return byDate != 0 ? byDate : b.id.compareTo(a.id);
        });
  return list.take(limit).toList();
}

/// Tests and platforms without persistence.
class MemoryAuthSecurityStore implements AuthSecurityStore {
  final _events = <AuthEvent>[];
  final _settings = <String, String>{};
  @override
  Future<void> record(AuthEvent event) async => _events.add(
    AuthEvent(
      id: _events.length + 1,
      type: event.type,
      createdAt: event.createdAt,
      email: event.email,
      userId: event.userId,
      actorId: event.actorId,
      details: event.details,
    ),
  );
  @override
  Future<List<AuthEvent>> events({
    int limit = 100,
    String? email,
    DateTime? since,
  }) async => _select(_events, limit: limit, email: email, since: since);
  @override
  Future<String?> readSetting(String key) async => _settings[key];
  @override
  Future<void> writeSetting(String key, String? value) async {
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
  }
}

Map<String, Object?> authEventToJson(AuthEvent e) => {
  'id': e.id,
  'type': e.type.name,
  'createdAt': e.createdAt.toUtc().toIso8601String(),
  'email': e.email,
  'userId': e.userId,
  'actorId': e.actorId,
  'details': e.details,
};

AuthEvent authEventFromJson(Map<String, Object?> j) => AuthEvent(
  id: j['id']! as int,
  type: AuthEventType.values.byName(j['type']! as String),
  createdAt: DateTime.parse(j['createdAt']! as String),
  email: j['email'] as String?,
  userId: j['userId'] as String?,
  actorId: j['actorId'] as String?,
  details: j['details'] as String?,
);

/// Web: browser storage, capped to the latest [maxEvents] entries.
class PreferencesAuthSecurityStore implements AuthSecurityStore {
  PreferencesAuthSecurityStore({this.maxEvents = 500});
  static const eventsKey = 'animora.auth_security.events.v1',
      settingsPrefix = 'animora.auth_security.setting.';
  final int maxEvents;

  Future<List<AuthEvent>> _all(SharedPreferences prefs) async {
    final raw = prefs.getString(eventsKey);
    if (raw == null) return [];
    return [
      for (final row in jsonDecode(raw) as List)
        authEventFromJson(Map<String, Object?>.from(row as Map)),
    ];
  }

  @override
  Future<void> record(AuthEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _all(prefs);
    final nextId = all.isEmpty
        ? 1
        : all.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
    all.add(
      AuthEvent(
        id: nextId,
        type: event.type,
        createdAt: event.createdAt,
        email: event.email,
        userId: event.userId,
        actorId: event.actorId,
        details: event.details,
      ),
    );
    final kept = all.length > maxEvents
        ? all.sublist(all.length - maxEvents)
        : all;
    await prefs.setString(
      eventsKey,
      jsonEncode([for (final e in kept) authEventToJson(e)]),
    );
  }

  @override
  Future<List<AuthEvent>> events({
    int limit = 100,
    String? email,
    DateTime? since,
  }) async => _select(
    await _all(await SharedPreferences.getInstance()),
    limit: limit,
    email: email,
    since: since,
  );

  @override
  Future<String?> readSetting(String key) async =>
      (await SharedPreferences.getInstance()).getString('$settingsPrefix$key');

  @override
  Future<void> writeSetting(String key, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    value == null
        ? await prefs.remove('$settingsPrefix$key')
        : await prefs.setString('$settingsPrefix$key', value);
  }
}
