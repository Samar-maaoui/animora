import 'package:sembast/blob.dart';

import 'dart:math';
import 'dart:typed_data';

import 'package:sembast/sembast.dart';

import 'database_native.dart'
    if (dart.library.js_interop) 'database_web.dart'
    as platform;

abstract interface class ReportsStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<String> savePhoto(Uint8List bytes);
  Future<Uint8List?> readPhoto(String reference);
  Future<void> close();
}

class SembastReportsStorage implements ReportsStorage {
  SembastReportsStorage({this.database, this.namespace = 'reports'});
  final String namespace;
  Future<Database>? database;
  Future<Database> get _db =>
      database ??= platform.openReportsDatabase(namespace: namespace);
  final _state = StoreRef<String, String>('metadata').record('state');
  final _media = StoreRef<String, Blob>('media');
  @override
  Future<String?> read() async => _state.get(await _db);
  @override
  Future<void> write(String value) async {
    await _state.put(await _db, value);
  }

  @override
  Future<String> savePhoto(Uint8List bytes) async {
    final random = Random.secure();
    final key = List.generate(
      20,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _media.record(key).put(await _db, Blob(bytes));
    return 'media:$key';
  }

  @override
  Future<Uint8List?> readPhoto(String reference) async {
    if (!reference.startsWith('media:')) return null;
    final blob = await _media.record(reference.substring(6)).get(await _db);
    return blob == null ? null : Uint8List.fromList(blob.bytes);
  }

  @override
  Future<void> close() async {
    if (database != null) await (await database!).close();
  }
}
