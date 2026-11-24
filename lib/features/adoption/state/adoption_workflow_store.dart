import 'package:flutter/foundation.dart';

import '../../auth/state/auth_session.dart';
import '../repositories/adoption_repository.dart';
import '../repositories/questionnaire_repository.dart';
import '../repositories/adoption_contract_repository.dart';
import '../repositories/adoption_follow_up_repository.dart';
import '../repositories/foster_placement_repository.dart';
import '../repositories/animal_repository.dart';

class AdoptionWorkflowStore extends ChangeNotifier {
  AdoptionWorkflowStore({
    required this.adoptions,
    required this.questionnaires,
    required this.contracts,
    required this.followUps,
    required this.placements,
    required this.changes,
    required this.session,
  }) {
    changes.addListener(_changed);
    session.addListener(_sessionChanged);
    _identity = _currentIdentity;
  }
  final AdoptionRepository adoptions;
  final QuestionnaireRepository questionnaires;
  final AdoptionContractRepository contracts;
  final AdoptionFollowUpRepository followUps;
  final FosterPlacementRepository placements;
  final Listenable changes;
  final AuthSession session;
  int revision = 0;
  bool busy = false, _disposed = false;
  String? _identity;
  String get _currentIdentity =>
      '${session.currentUser?.id}/${session.currentUser?.status}/${session.currentUser?.profile}';
  void _sessionChanged() {
    if (_identity != _currentIdentity) {
      _identity = _currentIdentity;
      _changed();
    }
  }

  void _changed() {
    revision++;
    if (!_disposed) notifyListeners();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) throw const CatalogFailure('Une opération est déjà en cours.');
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      await action();
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    changes.removeListener(_changed);
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
