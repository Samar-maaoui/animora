import 'package:animora/features/adoption/services/catalog_storage.dart';

class MemoryCatalogStorage implements CatalogStorage {
  MemoryCatalogStorage([this.value]);
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('Simulated storage failure');
    this.value = value;
  }
}
