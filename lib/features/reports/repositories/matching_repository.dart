import '../../../core/enums/match_status.dart';
import '../models/correspondance.dart';

abstract interface class MatchingRepository {
  Future<List<Correspondance>> getMatches();
  Future<void> refreshMatches();
  Future<void> moderateMatch(int id, MatchStatus status);
}
