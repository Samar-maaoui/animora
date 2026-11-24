// ignore_for_file: constant_identifier_names
enum CampaignStatus { DRAFT, ACTIVE, COMPLETED, CANCELLED }

extension CampaignStatusLabel on CampaignStatus {
  String get label => switch (this) {
    CampaignStatus.DRAFT => 'Brouillon',
    CampaignStatus.ACTIVE => 'Active',
    CampaignStatus.COMPLETED => 'Clôturée',
    CampaignStatus.CANCELLED => 'Annulée',
  };
}
