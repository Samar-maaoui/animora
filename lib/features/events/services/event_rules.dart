class EventFailure implements Exception {
  const EventFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String eventError(Object e) => e is EventFailure
    ? e.message
    : 'Impossible de terminer cette opération locale. Réessayez.';
