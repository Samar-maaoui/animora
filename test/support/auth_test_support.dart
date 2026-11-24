import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/services/local_auth_storage.dart';
import 'package:animora/features/auth/services/password_hasher.dart';

class MemoryAuthStorage implements AuthStorage {
  MemoryAuthStorage([this.value]);
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('Simulated disk failure');
    this.value = value;
  }
}

Future<String>? _seed;
Future<String> seedDatabase() => _seed ??= _buildSeed();
Future<String> _buildSeed() async {
  final storage = MemoryAuthStorage();
  final repository = LocalAuthRepository(
    storage: storage,
    seedDemoAccounts: true,
    hasher: const PasswordHasher(iterations: 10000),
  );
  await repository.initialize();
  repository.dispose();
  return storage.value!;
}

Future<LocalAuthRepository> testRepository({MemoryAuthStorage? storage}) async {
  final repository = LocalAuthRepository(
    storage: storage ?? MemoryAuthStorage(await seedDatabase()),
    hasher: const PasswordHasher(iterations: 10000),
  );
  await repository.initialize();
  return repository;
}
