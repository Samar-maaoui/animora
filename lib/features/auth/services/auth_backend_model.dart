import '../../../core/database/sql_module.dart';
import '../repositories/auth_repository.dart';

class AuthBackend {
  const AuthBackend(this.repository, {this.context, this.close});
  final AuthRepository repository;
  final SqliteModuleContext? context;
  final Future<void> Function()? close;
}
