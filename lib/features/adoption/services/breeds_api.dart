import '../../../core/network/api_client.dart';

class BreedInfo {
  const BreedInfo(
    this.id,
    this.name,
    this.description,
    this.temperament,
    this.lifeSpan,
    this.origin,
    this.weight,
  );
  final String id, name, description, temperament, lifeSpan, origin, weight;
  factory BreedInfo.fromJson(Map<String, dynamic> j) {
    if (j['id'] == null || j['name'] is! String) {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Race incomplète dans la réponse.',
      );
    }
    return BreedInfo(
      j['id'].toString(),
      j['name'] as String,
      j['description'] as String? ?? '',
      j['temperament'] as String? ?? '',
      j['life_span'] as String? ?? '',
      j['origin'] as String? ?? '',
      j['weight']?['metric'] as String? ?? '',
    );
  }
}

class BreedsApi {
  BreedsApi(
    this.client, {
    this.dogKey = const String.fromEnvironment('DOG_API_KEY'),
    this.catKey = const String.fromEnvironment('CAT_API_KEY'),
  });
  final ApiClient client;
  final String dogKey, catKey;
  Future<ApiValue<List<BreedInfo>>> breeds(
    String species, {
    bool refresh = false,
  }) async {
    final dog = species.toLowerCase() == 'chien';
    if (!dog && species.toLowerCase() != 'chat') {
      throw const ApiFailure(
        ApiErrorKind.invalid,
        'Informations disponibles uniquement pour chiens et chats. La race reste saisissable manuellement.',
      );
    }
    final key = dog ? dogKey : catKey;
    if (key.isEmpty) {
      throw ApiFailure(
        ApiErrorKind.configuration,
        'Clé ${dog ? 'The Dog API' : 'The Cat API'} absente. Conservez la saisie manuelle de la race.',
      );
    }
    final response = await client.get(
      Uri.https(dog ? 'api.thedogapi.com' : 'api.thecatapi.com', '/v1/breeds'),
      headers: {'x-api-key': key},
      ttl: const Duration(days: 7),
      refresh: refresh,
    );
    if (response.json is! List) {
      throw const ApiFailure(ApiErrorKind.invalid, 'Liste de races invalide.');
    }
    return ApiValue(
      (response.json as List)
          .map((j) => BreedInfo.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList(),
      response,
    );
  }
}
