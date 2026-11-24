import '../models/annonce.dart';
import '../models/zone_recherche.dart';
import '../models/histoire_retrouvailles.dart';

abstract interface class AnnouncementRepository {
  Future<List<Annonce>> getAnnouncements();
  Future<Annonce> getAnnouncement(int id);
  Future<Annonce> saveAnnouncement(
    Annonce draft, {
    required bool creating,
    bool locationConsent = false,
  });
  Future<void> closeAnnouncement(int id);
  Future<void> moderateAnnouncement(int id, bool hidden);
  Future<ZoneRecherche?> getSearchZone(int id);
  Future<void> saveSearchZone(
    int id,
    double latitude,
    double longitude,
    double radius, {
    required bool consent,
  });
  Future<List<HistoireRetrouvailles>> getStories();
  Future<void> publishStory(int announcementId, String title, {String? photo});
}
