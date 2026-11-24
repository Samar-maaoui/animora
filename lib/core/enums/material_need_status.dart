// ignore_for_file: constant_identifier_names
enum MaterialNeedStatus { OPEN, PARTIALLY_FULFILLED, FULFILLED }

extension MaterialNeedStatusLabel on MaterialNeedStatus {
  String get label => switch (this) {
    MaterialNeedStatus.OPEN => 'Ouvert',
    MaterialNeedStatus.PARTIALLY_FULFILLED => 'Partiellement satisfait',
    MaterialNeedStatus.FULFILLED => 'Satisfait',
  };
}
