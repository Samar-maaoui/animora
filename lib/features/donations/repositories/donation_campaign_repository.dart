import 'dart:typed_data';

import '../models/donation_campaign.dart';
import '../../../core/enums/campaign_status.dart';

abstract interface class DonationCampaignRepository {
  Future<List<DonationCampaign>> getCampaigns();
  Future<DonationCampaign> getCampaign(int id);
  Future<DonationCampaign> saveCampaign(
    DonationCampaign draft, {
    required bool creating,
    Uint8List? imageBytes,
    bool removeImage = false,
  });
  Future<void> changeCampaignStatus(int id, CampaignStatus status);
  Future<Uint8List?> readCampaignImage(int id);
}
