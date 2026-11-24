import '../../users/models/user.dart';
import 'adoption.dart';
import 'questionnaire_adoptant.dart';
import 'contrat_adoption.dart';
import 'suivi_adoption.dart';
import 'hebergement.dart';

class WorkflowData {
  WorkflowData({
    this.nextId = 1,
    Map<int, Adoption>? adoptions,
    Map<int, QuestionnaireAdoptant>? questionnaires,
    Map<int, ContratAdoption>? contracts,
    Map<int, SuiviAdoption>? followUps,
    Map<int, Hebergement>? placements,
    Map<int, User>? applicants,
  }) : adoptions = adoptions ?? {},
       questionnaires = questionnaires ?? {},
       contracts = contracts ?? {},
       followUps = followUps ?? {},
       placements = placements ?? {},
       applicants = applicants ?? {};
  int nextId;
  final Map<int, Adoption> adoptions;
  final Map<int, QuestionnaireAdoptant> questionnaires;
  final Map<int, ContratAdoption> contracts;
  final Map<int, SuiviAdoption> followUps;
  final Map<int, Hebergement> placements;
  final Map<int, User> applicants;
  WorkflowData clone() => WorkflowData(
    nextId: nextId,
    adoptions: Map.of(adoptions),
    questionnaires: Map.of(questionnaires),
    contracts: Map.of(contracts),
    followUps: Map.of(followUps),
    placements: Map.of(placements),
    applicants: Map.of(applicants),
  );
  Map<String, dynamic> toJson() => {
    'nextId': nextId,
    'adoptions': adoptions.values.map((a) => a.toJson()).toList(),
    'questionnaires': questionnaires.values.map((a) => a.toJson()).toList(),
    'contracts': contracts.values.map((a) => a.toJson()).toList(),
    'followUps': followUps.values.map((a) => a.toJson()).toList(),
    'placements': placements.values.map((a) => a.toJson()).toList(),
    'applicants': {
      for (final e in applicants.entries) e.key.toString(): e.value.toJson(),
    },
  };
  factory WorkflowData.fromJson(Map<String, dynamic> j) => WorkflowData(
    nextId: j['nextId'] as int,
    adoptions: {
      for (final e in j['adoptions'] as List)
        (e['id'] as int): Adoption.fromJson(e as Map<String, dynamic>),
    },
    questionnaires: {
      for (final e in j['questionnaires'] as List)
        (e['adoptionId'] as int): QuestionnaireAdoptant.fromJson(
          e as Map<String, dynamic>,
        ),
    },
    contracts: {
      for (final e in j['contracts'] as List)
        (e['adoptionId'] as int): ContratAdoption.fromJson(
          e as Map<String, dynamic>,
        ),
    },
    followUps: {
      for (final e in j['followUps'] as List)
        (e['id'] as int): SuiviAdoption.fromJson(e as Map<String, dynamic>),
    },
    placements: {
      for (final e in j['placements'] as List)
        (e['id'] as int): Hebergement.fromJson(e as Map<String, dynamic>),
    },
    applicants: {
      for (final e in (j['applicants'] as Map<String, dynamic>).entries)
        int.parse(e.key): User.fromJson(e.value as Map<String, dynamic>),
    },
  );
}
