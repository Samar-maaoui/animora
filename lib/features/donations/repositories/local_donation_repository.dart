import 'dart:math';
import 'dart:typed_data';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/enums/campaign_status.dart';
import '../../../core/enums/donation_type.dart';
import '../../../core/enums/donation_status.dart';
import '../../../core/enums/material_type.dart';
import '../../../core/enums/material_donation_status.dart';
import '../../../core/enums/donation_frequency.dart';
import '../../../core/enums/recurring_donation_status.dart';
import '../../../core/enums/material_need_status.dart';
import '../../users/models/user.dart';
import '../models/donation_campaign.dart';
import '../models/donation.dart';
import '../models/material_donation.dart';
import '../models/recurring_donation.dart';
import '../models/donation_receipt.dart';
import '../models/material_need.dart';
import '../models/transparency_report.dart';
import '../services/donation_rules.dart';
import 'donations_database.dart';
import 'donation_campaign_repository.dart';
import 'donation_repository.dart';
import 'material_donation_repository.dart';
import 'recurring_donation_repository.dart';
import 'donation_receipt_repository.dart';
import 'material_need_repository.dart';
import 'transparency_report_repository.dart';

class LocalDonationRepository
    implements
        DonationCampaignRepository,
        DonationRepository,
        MaterialDonationRepository,
        RecurringDonationRepository,
        DonationReceiptRepository,
        MaterialNeedRepository,
        TransparencyReportRepository {
  LocalDonationRepository(
    this.database,
    this.currentUser, {
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final DonationsDatabase database;
  final User? Function() currentUser;
  final DateTime Function() clock;
  Never _fail(String s) => throw DonationFailure(s);
  User _actor() {
    final u = currentUser();
    if (u == null || u.status != AccountStatus.active) {
      _fail('Un compte actif est nécessaire.');
    }
    return u;
  }

  bool _admin(User u) => u.profile == UserProfile.admin;
  void _requireAdmin(User u) {
    if (!_admin(u)) _fail('Action réservée à ADMIN.');
  }

  void _text(String s, int min, {int max = 10000}) {
    if (s.trim().length < min || s.length > max) {
      _fail('Saisissez entre $min et $max caractères.');
    }
  }

  void _quantity(int q) {
    if (q < 1 || q > 1000000000) {
      _fail('Quantité entière de 1 à 1 milliard attendue.');
    }
  }

  Future<T> _read<T>(T Function(DonationsData, User) f) async {
    final id = _actor().id;
    return database.read((d) {
      final u = _actor();
      if (u.id != id) _fail('La session a changé.');
      return f(d, u);
    });
  }

  Future<T> _write<T>(T Function(DonationsData, User) f) async {
    final id = _actor().id;
    return database.mutate((d) {
      final u = _actor();
      if (u.id != id) _fail('La session a changé.');
      return f(d, u);
    });
  }

  DonationCampaign _campaign(DonationsData d, User u, int id) {
    final c = d.campaigns[id];
    if (c == null || (c.status == CampaignStatus.DRAFT && !_admin(u))) {
      _fail('Campagne inaccessible.');
    }
    return c;
  }

  DonationCampaign _openCampaign(DonationsData d, User u, int id) {
    final c = _campaign(d, u, id);
    if (c.status != CampaignStatus.ACTIVE ||
        clock().isBefore(c.startDate) ||
        !clock().isBefore(c.endDate)) {
      _fail('Cette campagne n’accepte pas de contributions sur cette période.');
    }
    return c;
  }

  int _collected(DonationsData d, int id) => d.donations.values
      .where(
        (x) =>
            x.campaignId == id &&
            x.type == DonationType.FINANCIAL &&
            x.status == DonationStatus.CONFIRMED,
      )
      .fold(0, (sum, x) => sum + DonationMoney.mills(x.amount!));
  DonationCampaign _view(DonationsData d, DonationCampaign c) =>
      c.copyWith(collectedAmount: _collected(d, c.id) / 1000);
  Donation _donation(DonationsData d, User u, int id) {
    final x = d.donations[id];
    if (x == null || (!_admin(u) && x.donorUserId != u.id)) {
      _fail('Ce don est privé ou introuvable.');
    }
    return x;
  }

  MaterialDonation _material(DonationsData d, User u, int id) {
    final m = d.materials[id];
    if (m == null) _fail('Proposition introuvable.');
    _donation(d, u, m.donationId);
    return m;
  }

  RecurringDonation _recurring(
    DonationsData d,
    User u,
    int id, {
    bool owner = false,
  }) {
    final r = d.recurring[id];
    if (r == null || (r.donorUserId != u.id && (owner || !_admin(u)))) {
      _fail('Ce programme est privé ou introuvable.');
    }
    return r;
  }

  MaterialNeed _need(
    DonationsData d,
    int id,
    int campaignId,
    MaterialType type,
  ) {
    final n = d.needs[id];
    if (n == null || n.campaignId != campaignId || n.itemType != type) {
      _fail(
        'Le besoin doit appartenir à la campagne et au type de matériel choisi.',
      );
    }
    return n;
  }

  int _receivedQuantity(DonationsData d, int needId) => d.materials.values
      .where(
        (m) =>
            m.materialNeedId == needId &&
            m.status == MaterialDonationStatus.RECEIVED &&
            d.donations[m.donationId]?.status == DonationStatus.CONFIRMED,
      )
      .fold(0, (sum, m) => sum + m.quantity);
  MaterialNeed _needView(DonationsData d, MaterialNeed n) {
    final q = _receivedQuantity(d, n.id);
    return n.copyWith(
      receivedQuantity: q,
      status: q == 0
          ? MaterialNeedStatus.OPEN
          : q >= n.requestedQuantity
          ? MaterialNeedStatus.FULFILLED
          : MaterialNeedStatus.PARTIALLY_FULFILLED,
    );
  }

  void _key(String? key) {
    if (key != null && (key.trim().isEmpty || key.length > 100)) {
      _fail('Référence de demande invalide.');
    }
  }

  Donation? _existing(DonationsData d, User u, String? key) {
    _key(key);
    if (key == null) return null;
    if (d.recurring.values.any(
      (r) => r.donorUserId == u.id && r.requestKey == key,
    )) {
      _fail('Cette référence est déjà utilisée pour un programme récurrent.');
    }
    return d.donations.values
        .where((x) => x.donorUserId == u.id && x.requestKey == key)
        .firstOrNull;
  }

  @override
  Future<List<DonationCampaign>> getCampaigns() => _read(
    (d, u) =>
        d.campaigns.values
            .where((c) => c.status != CampaignStatus.DRAFT || _admin(u))
            .map((c) => _view(d, c))
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate)),
  );
  @override
  Future<DonationCampaign> getCampaign(int id) =>
      _read((d, u) => _view(d, _campaign(d, u, id)));
  @override
  Future<DonationCampaign> saveCampaign(
    DonationCampaign draft, {
    required bool creating,
    Uint8List? imageBytes,
    bool removeImage = false,
  }) async {
    final identity = _actor().id;
    await _read((d, u) {
      _requireAdmin(u);
      if (!creating) _campaign(d, u, draft.id);
    });
    if (imageBytes != null &&
        (imageBytes.isEmpty || imageBytes.length > 2 * 1024 * 1024)) {
      _fail('Image limitée à 2 Mo après préparation.');
    }
    final image = imageBytes == null
        ? null
        : await database.storage.savePhoto(imageBytes);
    if (_actor().id != identity) _fail('La session a changé.');
    return _write((d, u) {
      _requireAdmin(u);
      _text(draft.title, 5, max: 150);
      _text(draft.description, 20);
      DonationMoney.mills(draft.targetAmount);
      if (!draft.endDate.isAfter(draft.startDate) ||
          !draft.endDate.isAfter(clock())) {
        _fail('La fin doit être future et postérieure au début.');
      }
      final old = creating ? null : _campaign(d, u, draft.id);
      if (old != null &&
          ![CampaignStatus.DRAFT, CampaignStatus.ACTIVE].contains(old.status)) {
        _fail('Une campagne clôturée ou annulée ne peut plus être modifiée.');
      }
      if (old != null &&
          (old.startDate != draft.startDate || old.endDate != draft.endDate) &&
          (d.donations.values.any((x) => x.campaignId == old.id) ||
              d.recurring.values.any((r) => r.campaignId == old.id))) {
        _fail(
          'Les dates sont figées après la première contribution ou programmation.',
        );
      }
      final c = draft.copyWith(
        id: old?.id ?? d.nextId++,
        status: old?.status ?? CampaignStatus.DRAFT,
        collectedAmount: 0,
        image: removeImage ? null : image ?? old?.image,
      );
      d.campaigns[c.id] = c;
      return _view(d, c);
    });
  }

  void _cancelPending(DonationsData d, Donation x) {
    d.donations[x.id] = x.copyWith(status: DonationStatus.CANCELLED);
    for (final m
        in d.materials.values.where((m) => m.donationId == x.id).toList()) {
      if (m.status == MaterialDonationStatus.PENDING) {
        d.materials[m.id] = m.copyWith(status: MaterialDonationStatus.REJECTED);
      }
    }
  }

  @override
  Future<void> changeCampaignStatus(int id, CampaignStatus status) => _write((
    d,
    u,
  ) {
    _requireAdmin(u);
    final c = _campaign(d, u, id);
    if (status == CampaignStatus.ACTIVE) {
      if (c.status != CampaignStatus.DRAFT || !c.endDate.isAfter(clock())) {
        _fail('Seule une campagne brouillon non expirée peut être publiée.');
      }
    } else if (status == CampaignStatus.COMPLETED) {
      if (c.status != CampaignStatus.ACTIVE) {
        _fail('Seule une campagne active peut être clôturée.');
      }
    } else if (status == CampaignStatus.CANCELLED) {
      if (![CampaignStatus.DRAFT, CampaignStatus.ACTIVE].contains(c.status)) {
        _fail('Cette campagne est déjà terminée.');
      }
    } else {
      _fail('Transition de campagne interdite.');
    }
    d.campaigns[id] = c.copyWith(status: status);
    if ([CampaignStatus.COMPLETED, CampaignStatus.CANCELLED].contains(status)) {
      for (final x
          in d.donations.values
              .where(
                (x) => x.campaignId == id && x.status == DonationStatus.PENDING,
              )
              .toList()) {
        _cancelPending(d, x);
      }
      for (final r
          in d.recurring.values
              .where(
                (r) =>
                    r.campaignId == id &&
                    r.status != RecurringDonationStatus.CANCELLED,
              )
              .toList()) {
        d.recurring[r.id] = r.copyWith(
          status: RecurringDonationStatus.CANCELLED,
          terminationReason: 'Campagne clôturée ou annulée.',
        );
      }
    }
  });
  @override
  Future<Uint8List?> readCampaignImage(int id) async {
    final identity = _actor().id;
    final ref = await _read((d, u) => _campaign(d, u, id).image);
    if (ref == null) return null;
    final bytes = await database.storage.readPhoto(ref);
    if (_actor().id != identity) _fail('La session a changé.');
    await getCampaign(id);
    return bytes;
  }

  @override
  Future<List<Donation>> getDonations({int? campaignId}) => _read(
    (d, u) =>
        d.donations.values
            .where(
              (x) =>
                  (_admin(u) || x.donorUserId == u.id) &&
                  (campaignId == null || x.campaignId == campaignId),
            )
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id)),
  );
  @override
  Future<Donation> getDonation(int id) => _read((d, u) => _donation(d, u, id));
  Donation _newFinancial(
    DonationsData d,
    User u,
    DonationCampaign c,
    double amount, {
    String? key,
    int? recurringId,
    DateTime? scheduledFor,
  }) {
    final x = Donation(
      id: d.nextId++,
      donorUserId: u.id,
      campaignId: c.id,
      type: DonationType.FINANCIAL,
      amount: DonationMoney.mills(amount) / 1000,
      donationDate: clock(),
      status: DonationStatus.PENDING,
      donorName: u.fullName,
      campaignTitle: c.title,
      requestKey: key,
      recurringDonationId: recurringId,
      scheduledFor: scheduledFor,
    );
    d.donations[x.id] = x;
    return x;
  }

  DateTime _nextDate(RecurringDonation r, DateTime date) {
    if (r.frequency == DonationFrequency.WEEKLY) {
      return date.add(const Duration(days: 7));
    }
    final last = DateTime(date.year, date.month + 2, 0).day;
    return DateTime(
      date.year,
      date.month + 1,
      min(r.anchorDay, last),
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  void _issueReceipt(DonationsData d, Donation x) {
    if (x.status != DonationStatus.CONFIRMED ||
        d.receipts.values.any((r) => r.donationId == x.id)) {
      return;
    }
    final material = d.materials.values
        .where(
          (m) =>
              m.donationId == x.id &&
              m.status == MaterialDonationStatus.RECEIVED,
        )
        .firstOrNull;
    if (x.type == DonationType.MATERIAL && material == null) {
      _fail('La réception du matériel est nécessaire pour un reçu.');
    }
    final id = d.nextId++;
    d.receipts[id] = DonationReceipt(
      id: id,
      donationId: x.id,
      issueDate: clock(),
      reference: 'DEMO-RECU-${id.toString().padLeft(6, '0')}',
      donationReference: donationReference(x.id),
      donorName: x.donorName,
      campaignTitle: x.campaignTitle,
      type: x.type,
      amount: x.amount,
      materialDescription: material == null
          ? null
          : '${material.itemType.label} • ${material.quantity} unité(s)\n${material.description}',
    );
  }

  void _confirmFinancial(DonationsData d, User u, Donation x) {
    _openCampaign(d, u, x.campaignId);
    if (x.type != DonationType.FINANCIAL ||
        x.status != DonationStatus.PENDING) {
      _fail(
        'Seul un don financier simulé en attente peut être confirmé une seule fois.',
      );
    }
    DonationMoney.mills(x.amount!);
    if (x.recurringDonationId != null) {
      final r = _recurring(d, u, x.recurringDonationId!);
      if (r.status != RecurringDonationStatus.ACTIVE ||
          r.nextDonationDate != x.scheduledFor) {
        _fail('Cette occurrence n’est plus disponible.');
      }
      var next = _nextDate(r, r.nextDonationDate);
      while (!next.isAfter(clock())) {
        next = _nextDate(r, next);
      }
      final campaign = d.campaigns[r.campaignId]!;
      d.recurring[r.id] = r.copyWith(
        nextDonationDate: next,
        status: next.isBefore(campaign.endDate)
            ? RecurringDonationStatus.ACTIVE
            : RecurringDonationStatus.CANCELLED,
        terminationReason: next.isBefore(campaign.endDate)
            ? null
            : 'La prochaine date dépasse la fin de campagne.',
      );
    }
    final confirmed = x.copyWith(status: DonationStatus.CONFIRMED);
    d.donations[x.id] = confirmed;
    _issueReceipt(d, confirmed);
  }

  @override
  Future<Donation> createFinancialDonation(
    int campaignId,
    double amount, {
    bool confirmSimulation = false,
    String? requestKey,
  }) => _write((d, u) {
    DonationMoney.mills(amount);
    final existing = _existing(d, u, requestKey);
    if (existing != null) {
      if (existing.type != DonationType.FINANCIAL ||
          existing.campaignId != campaignId ||
          existing.amount != amount ||
          existing.recurringDonationId != null) {
        _fail('Cette référence est déjà utilisée pour une autre contribution.');
      }
      return existing;
    }
    final c = _openCampaign(d, u, campaignId);
    final x = _newFinancial(d, u, c, amount, key: requestKey);
    if (confirmSimulation) _confirmFinancial(d, u, x);
    return d.donations[x.id]!;
  });
  @override
  Future<void> confirmFinancialDonation(int id) => _write((d, u) {
    final x = _donation(d, u, id);
    _confirmFinancial(d, u, x);
  });
  @override
  Future<void> cancelDonation(int id) => _write((d, u) {
    final x = _donation(d, u, id);
    if (x.status != DonationStatus.PENDING) {
      _fail('Seul un don en attente peut être annulé.');
    }
    _cancelPending(d, x);
  });
  @override
  Future<List<MaterialDonation>> getMaterialDonations({int? campaignId}) =>
      _read(
        (d, u) => d.materials.values.where((m) {
          final x = d.donations[m.donationId];
          return x != null &&
              (_admin(u) || x.donorUserId == u.id) &&
              (campaignId == null || x.campaignId == campaignId);
        }).toList()..sort((a, b) => b.id.compareTo(a.id)),
      );
  @override
  Future<MaterialDonation?> getMaterialForDonation(int id) => _read((d, u) {
    _donation(d, u, id);
    return d.materials.values.where((m) => m.donationId == id).firstOrNull;
  });
  @override
  Future<void> createMaterialDonation(
    int campaignId,
    MaterialType type,
    int quantity,
    String description, {
    int? needId,
    String? requestKey,
  }) => _write((d, u) {
    _quantity(quantity);
    _text(description, 10);
    final existing = _existing(d, u, requestKey);
    if (existing != null) {
      final old = d.materials.values
          .where((m) => m.donationId == existing.id)
          .firstOrNull;
      if (existing.type != DonationType.MATERIAL ||
          existing.campaignId != campaignId ||
          old?.quantity != quantity ||
          old?.itemType != type ||
          old?.description != description.trim()) {
        _fail('Cette référence est déjà utilisée pour une autre proposition.');
      }
      return;
    }
    final c = _openCampaign(d, u, campaignId);
    if (needId != null) _need(d, needId, c.id, type);
    final x = Donation(
      id: d.nextId++,
      donorUserId: u.id,
      campaignId: c.id,
      type: DonationType.MATERIAL,
      donationDate: clock(),
      status: DonationStatus.PENDING,
      donorName: u.fullName,
      campaignTitle: c.title,
      requestKey: requestKey,
    );
    d.donations[x.id] = x;
    final m = MaterialDonation(
      id: d.nextId++,
      donationId: x.id,
      itemType: type,
      quantity: quantity,
      description: description.trim(),
      status: MaterialDonationStatus.PENDING,
      materialNeedId: needId,
    );
    d.materials[m.id] = m;
  });
  @override
  Future<void> receiveMaterialDonation(int id, {int? needId}) => _write((d, u) {
    _requireAdmin(u);
    final m = _material(d, u, id), x = _donation(d, u, m.donationId);
    if (m.status != MaterialDonationStatus.PENDING ||
        x.status != DonationStatus.PENDING) {
      _fail('Cette proposition a déjà été traitée.');
    }
    _openCampaign(d, u, x.campaignId);
    final linked = needId ?? m.materialNeedId;
    if (linked != null) _need(d, linked, x.campaignId, m.itemType);
    d.materials[id] = m.copyWith(
      status: MaterialDonationStatus.RECEIVED,
      materialNeedId: linked,
    );
    final confirmed = x.copyWith(status: DonationStatus.CONFIRMED);
    d.donations[x.id] = confirmed;
    _issueReceipt(d, confirmed);
  });
  @override
  Future<void> rejectMaterialDonation(int id) => _write((d, u) {
    _requireAdmin(u);
    final m = _material(d, u, id), x = _donation(d, u, m.donationId);
    if (m.status != MaterialDonationStatus.PENDING ||
        x.status != DonationStatus.PENDING) {
      _fail('Cette proposition a déjà été traitée.');
    }
    d.materials[id] = m.copyWith(status: MaterialDonationStatus.REJECTED);
    d.donations[x.id] = x.copyWith(status: DonationStatus.CANCELLED);
  });
  @override
  Future<List<RecurringDonation>> getRecurringDonations() => _read(
    (d, u) =>
        d.recurring.values
            .where((r) => _admin(u) || r.donorUserId == u.id)
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id)),
  );
  @override
  Future<void> createRecurringDonation(
    int campaignId,
    double amount,
    DonationFrequency frequency,
    DateTime nextDate, {
    String? requestKey,
  }) => _write((d, u) {
    DonationMoney.mills(amount);
    _key(requestKey);
    final old = requestKey == null
        ? null
        : d.recurring.values
              .where((r) => r.donorUserId == u.id && r.requestKey == requestKey)
              .firstOrNull;
    if (old != null) {
      if (old.campaignId != campaignId ||
          old.amount != amount ||
          old.frequency != frequency) {
        _fail('Référence déjà utilisée.');
      }
      return;
    }
    if (requestKey != null &&
        d.donations.values.any(
          (x) => x.donorUserId == u.id && x.requestKey == requestKey,
        )) {
      _fail('Référence déjà utilisée pour un don.');
    }
    final c = _openCampaign(d, u, campaignId);
    if (!nextDate.isAfter(clock()) ||
        nextDate.isBefore(c.startDate) ||
        !nextDate.isBefore(c.endDate)) {
      _fail('La prochaine date doit être future et comprise dans la campagne.');
    }
    final r = RecurringDonation(
      id: d.nextId++,
      donorUserId: u.id,
      campaignId: campaignId,
      amount: DonationMoney.mills(amount) / 1000,
      frequency: frequency,
      nextDonationDate: nextDate,
      status: RecurringDonationStatus.ACTIVE,
      anchorDay: nextDate.day,
      donorName: u.fullName,
      campaignTitle: c.title,
      requestKey: requestKey,
    );
    d.recurring[r.id] = r;
  });
  @override
  Future<void> changeRecurringStatus(int id, RecurringDonationStatus status) =>
      _write((d, u) {
        final r = _recurring(d, u, id, owner: true);
        if (r.status == RecurringDonationStatus.CANCELLED ||
            r.status == status) {
          _fail('Transition de programme interdite.');
        }
        if (status == RecurringDonationStatus.ACTIVE) {
          _openCampaign(d, u, r.campaignId);
        }
        d.recurring[id] = r.copyWith(
          status: status,
          terminationReason: status == RecurringDonationStatus.CANCELLED
              ? 'Annulé par le donateur.'
              : null,
        );
        if (status != RecurringDonationStatus.ACTIVE) {
          for (final x
              in d.donations.values
                  .where(
                    (x) =>
                        x.recurringDonationId == id &&
                        x.status == DonationStatus.PENDING,
                  )
                  .toList()) {
            _cancelPending(d, x);
          }
        }
      });
  @override
  Future<Donation> prepareRecurringOccurrence(int id) => _write((d, u) {
    final r = _recurring(d, u, id, owner: true);
    if (r.status != RecurringDonationStatus.ACTIVE ||
        r.nextDonationDate.isAfter(clock())) {
      _fail('Ce programme n’a pas d’occurrence active arrivée à échéance.');
    }
    final c = _openCampaign(d, u, r.campaignId);
    final existing = d.donations.values
        .where(
          (x) =>
              x.recurringDonationId == id &&
              x.scheduledFor == r.nextDonationDate &&
              x.status == DonationStatus.PENDING,
        )
        .firstOrNull;
    if (existing != null) return existing;
    return _newFinancial(
      d,
      u,
      c,
      r.amount,
      recurringId: id,
      scheduledFor: r.nextDonationDate,
    );
  });
  @override
  Future<DonationReceipt?> getReceiptForDonation(int id) => _read((d, u) {
    final x = _donation(d, u, id);
    if (x.status != DonationStatus.CONFIRMED) return null;
    return d.receipts.values.where((r) => r.donationId == id).firstOrNull;
  });
  @override
  Future<DonationReceipt> getReceipt(int id) => _read((d, u) {
    final r = d.receipts[id];
    if (r == null) _fail('Reçu introuvable.');
    final x = _donation(d, u, r.donationId);
    if (x.status != DonationStatus.CONFIRMED) {
      _fail('Un reçu nécessite un don confirmé.');
    }
    return r;
  });
  @override
  Future<List<MaterialNeed>> getMaterialNeeds(int id) => _read((d, u) {
    _campaign(d, u, id);
    return d.needs.values
        .where((n) => n.campaignId == id)
        .map((n) => _needView(d, n))
        .toList();
  });
  @override
  Future<void> saveMaterialNeed(MaterialNeed draft, {required bool creating}) =>
      _write((d, u) {
        _requireAdmin(u);
        final c = _campaign(d, u, draft.campaignId);
        if (![CampaignStatus.DRAFT, CampaignStatus.ACTIVE].contains(c.status)) {
          _fail('La campagne est terminée.');
        }
        _text(draft.description, 10);
        _quantity(draft.requestedQuantity);
        final old = creating ? null : d.needs[draft.id];
        if (!creating && (old == null || old.campaignId != draft.campaignId)) {
          _fail('Besoin introuvable.');
        }
        if (old != null &&
            old.itemType != draft.itemType &&
            d.materials.values.any((m) => m.materialNeedId == old.id)) {
          _fail(
            'Le type est figé dès qu’une proposition est associée à ce besoin.',
          );
        }
        final n = draft.copyWith(
          id: old?.id ?? d.nextId++,
          receivedQuantity: 0,
          status: MaterialNeedStatus.OPEN,
        );
        d.needs[n.id] = n;
      });
  @override
  Future<List<TransparencyReport>> getTransparencyReports(int id) =>
      _read((d, u) {
        _campaign(d, u, id);
        return d.reports.values.where((r) => r.campaignId == id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
  @override
  Future<void> publishTransparencyReport(
    int id,
    String description,
    String content,
  ) => _write((d, u) {
    _requireAdmin(u);
    final c = _campaign(d, u, id);
    if (c.status == CampaignStatus.DRAFT) {
      _fail('Publiez la campagne avant son rapport.');
    }
    _text(description, 10, max: 300);
    _text(content, 20);
    final received = d.materials.values
        .where(
          (m) =>
              m.status == MaterialDonationStatus.RECEIVED &&
              d.donations[m.donationId]?.campaignId == id &&
              d.donations[m.donationId]?.status == DonationStatus.CONFIRMED,
        )
        .toList();
    final summary = MaterialType.values
        .map(
          (t) =>
              '${t.label} : ${received.where((m) => m.itemType == t).fold(0, (sum, m) => sum + m.quantity)} unité(s) déclarée(s)',
        )
        .join('\n');
    final r = TransparencyReport(
      id: d.nextId++,
      campaignId: id,
      description: description.trim(),
      content: content.trim(),
      createdAt: clock(),
      financialTotal: _collected(d, id) / 1000,
      receivedMaterialCount: received.length,
      receivedMaterialSummary: summary,
    );
    d.reports[r.id] = r;
  });
}
