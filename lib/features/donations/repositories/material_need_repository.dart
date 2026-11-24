import '../models/material_need.dart';

abstract interface class MaterialNeedRepository {
  Future<List<MaterialNeed>> getMaterialNeeds(int campaignId);
  Future<void> saveMaterialNeed(MaterialNeed draft, {required bool creating});
}
