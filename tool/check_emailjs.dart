// Diagnostic EmailJS SANS envoyer d'e-mail :
//   dart run tool/check_emailjs.dart
// Lit config/api-keys.json et appelle EmailJS avec un identifiant de modèle
// volontairement invalide. La réponse indique si les clés et l'option
// « non-browser » sont acceptées. N'affiche jamais les clés.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final file = File('config/api-keys.json');
  if (!file.existsSync()) {
    stdout.writeln('✗ config/api-keys.json introuvable.');
    exit(1);
  }
  final keys = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  String key(String name) => (keys[name] as String? ?? '').trim();
  for (final name in [
    'EMAILJS_SERVICE_ID',
    'EMAILJS_TEMPLATE_ID',
    'EMAILJS_PUBLIC_KEY',
    'EMAILJS_PRIVATE_KEY',
  ]) {
    stdout.writeln('${key(name).isEmpty ? '✗' : '✓'} $name '
        '${key(name).isEmpty ? 'ABSENTE' : 'présente'}');
  }
  final client = HttpClient()..userAgent = 'Dart/3 (dart:io)';
  final request = await client.postUrl(
    Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
  );
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({
    'service_id': key('EMAILJS_SERVICE_ID'),
    'template_id': 'template_diagnostic_invalide',
    'user_id': key('EMAILJS_PUBLIC_KEY'),
    'accessToken': key('EMAILJS_PRIVATE_KEY'),
    'template_params': <String, String>{},
  }));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  client.close();
  final b = body.toLowerCase();
  stdout.writeln('\nRéponse EmailJS : HTTP ${response.statusCode}');
  if (b.contains('non-browser')) {
    stdout.writeln('✗ Option « Allow EmailJS API for non-browser applications » '
        'DÉSACTIVÉE (Account → Security). Activez-la et enregistrez.');
  } else if (response.statusCode >= 500) {
    stdout.writeln('? EmailJS indisponible (HTTP ${response.statusCode}). Réessayez.');
  } else if (b.contains('public key') || b.contains('user_id')) {
    stdout.writeln('✗ Clé publique refusée.');
  } else if (b.contains('private key') || b.contains('accesstoken')) {
    stdout.writeln('✗ Clé privée refusée.');
  } else if (b.contains('service id') || b.contains('service_id')) {
    stdout.writeln('✗ Service refusé (ID ou connexion Gmail).');
  } else if (b.contains('template id') || b.contains('template_id')) {
    stdout.writeln('✓ Clés et option non-browser acceptées (le modèle de test '
        'est invalide exprès). Vérifiez enfin que EMAILJS_TEMPLATE_ID est le bon.');
  } else {
    stdout.writeln('? Réponse inattendue : '
        '${body.length > 200 ? body.substring(0, 200) : body}');
  }
}
