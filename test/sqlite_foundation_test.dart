import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:animora/core/database/database_helper.dart';
import 'package:animora/core/database/database_constants.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('Real SQLite schema enables FK and creates requested tables', () async {
    final helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    addTearDown(helper.close);
    final db = await helper.database;
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    final names = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    )).map((r) => r['name']);
    expect(names, containsAll(DatabaseConstants.tables));
  });
}
