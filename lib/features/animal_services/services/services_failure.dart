class ServicesFailure implements Exception {
  const ServicesFailure(this.message);
  final String message;
}

String servicesError(Object e) => e is ServicesFailure
    ? e.message
    : 'Opération impossible. Vérifiez votre connexion au stockage local et réessayez.';
