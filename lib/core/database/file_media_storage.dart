import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../features/reports/repositories/reports_storage.dart';
import 'sql_module.dart';
import 'database_helper.dart';

/// SQL contains references only; the old Sembast files are retained untouched.
class FileMediaStorage implements MigratingMediaStorage {
  FileMediaStorage(this.namespace, this.legacy, {this.directory});
  final String namespace;
  final ReportsStorage legacy;
  final String? directory;
  Future<Directory> get _root async => Directory(
    path.join(
      directory ?? (await getApplicationSupportDirectory()).path,
      'animora_media',
      namespace,
    ),
  ).create(recursive: true);
  String _key(String ref) {
    final match = RegExp(r'^media:([A-Za-z0-9_-]{1,128})$').firstMatch(ref);
    if (match == null) throw const DatabaseFailure('Référence média invalide.');
    return match.group(1)!;
  }

  Future<File> _file(String ref) async =>
      File(path.join((await _root).path, '${_key(ref)}.bin'));
  String _random() => List.generate(
    20,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  @override
  Future<String?> read() => legacy.read();
  @override
  Future<void> write(String value) async => throw const DatabaseFailure(
    'Les métadonnées sont écrites par transaction SQLite.',
  );
  @override
  Future<void> importPhoto(String ref) async {
    final file = await _file(ref);
    final bytes = await legacy.readPhoto(ref);
    if (await file.exists()) {
      if (bytes != null && !listEquals(await file.readAsBytes(), bytes)) {
        throw const DatabaseFailure(
          'Conflit de média : aucun fichier existant écrasé.',
        );
      }
      return;
    }
    if (bytes == null) {
      throw const DatabaseFailure(
        'Photo source absente : migration annulée sans effacement.',
      );
    }
    await _save(file, bytes);
  }

  Future<void> _save(File file, Uint8List bytes) async {
    final tmp = File('${file.path}.${_random()}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<String> savePhoto(Uint8List bytes) async {
    final ref = 'media:${_random()}';
    await _save(await _file(ref), bytes);
    return ref;
  }

  @override
  Future<Uint8List?> readPhoto(String ref) async {
    if (!ref.startsWith('media:')) return null;
    final file = await _file(ref);
    return await file.exists() ? file.readAsBytes() : null;
  }

  // Lifetime is owned by the shared SQL context after all queues have drained.
  @override
  Future<void> close() async {}
  @override
  Future<void> disposeStorage() => legacy.close();
}
