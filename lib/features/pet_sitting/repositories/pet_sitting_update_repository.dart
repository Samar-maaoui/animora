import 'dart:typed_data';

import '../models/pet_sitting_update.dart';

abstract interface class PetSittingUpdateRepository {
  Future<List<PetSittingUpdate>> getUpdates(int requestId);
  Future<void> addUpdate(int requestId, String message, {Uint8List? photo});
  Future<Uint8List?> readUpdatePhoto(int updateId);
}
