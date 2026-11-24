import '../models/contrat_adoption.dart';

abstract interface class AdoptionContractRepository {
  Future<ContratAdoption> getContract(int adoptionId);
  Future<void> signContract(int adoptionId, {required bool confirmed});
}
