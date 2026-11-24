import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openReportsDatabase({String namespace = 'reports'}) async {
  final directory = await getApplicationSupportDirectory();
  return databaseFactoryIo.openDatabase(
    path.join(directory.path, 'animora_$namespace.db'),
  );
}
