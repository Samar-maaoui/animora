import 'package:sembast_web/sembast_web.dart';

Future<Database> openReportsDatabase({String namespace = 'reports'}) =>
    databaseFactoryWeb.openDatabase('animora_${namespace}_v1');
