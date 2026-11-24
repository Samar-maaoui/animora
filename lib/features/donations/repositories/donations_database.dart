import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../reports/repositories/reports_storage.dart';
import '../models/donation_campaign.dart';
import '../models/donation.dart';
import '../models/material_donation.dart';
import '../models/recurring_donation.dart';
import '../models/donation_receipt.dart';
import '../models/material_need.dart';
import '../models/transparency_report.dart';

class DonationsData {
  int nextId = 1;
  final Map<int, DonationCampaign> campaigns = {};
  final Map<int, Donation> donations = {};
  final Map<int, MaterialDonation> materials = {};
  final Map<int, RecurringDonation> recurring = {};
  final Map<int, DonationReceipt> receipts = {};
  final Map<int, MaterialNeed> needs = {};
  final Map<int, TransparencyReport> reports = {};
  DonationsData();
  Map<String, dynamic> toJson() => {
    'version': 1,
    'nextId': nextId,
    'campaigns': campaigns.values.map((v) => v.toJson()).toList(),
    'donations': donations.values.map((v) => v.toJson()).toList(),
    'materials': materials.values.map((v) => v.toJson()).toList(),
    'recurring': recurring.values.map((v) => v.toJson()).toList(),
    'receipts': receipts.values.map((v) => v.toJson()).toList(),
    'needs': needs.values.map((v) => v.toJson()).toList(),
    'reports': reports.values.map((v) => v.toJson()).toList(),
  };
  factory DonationsData.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported donation schema');
    }
    final d = DonationsData()..nextId = j['nextId'] as int;
    for (final raw in j['campaigns'] as List) {
      final v = DonationCampaign.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.campaigns[v.id] = v;
    }
    for (final raw in j['donations'] as List) {
      final v = Donation.fromJson(Map<String, dynamic>.from(raw as Map));
      d.donations[v.id] = v;
    }
    for (final raw in j['materials'] as List) {
      final v = MaterialDonation.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.materials[v.id] = v;
    }
    for (final raw in j['recurring'] as List) {
      final v = RecurringDonation.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.recurring[v.id] = v;
    }
    for (final raw in j['receipts'] as List) {
      final v = DonationReceipt.fromJson(Map<String, dynamic>.from(raw as Map));
      d.receipts[v.id] = v;
    }
    for (final raw in j['needs'] as List) {
      final v = MaterialNeed.fromJson(Map<String, dynamic>.from(raw as Map));
      d.needs[v.id] = v;
    }
    for (final raw in j['reports'] as List) {
      final v = TransparencyReport.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      d.reports[v.id] = v;
    }
    return d;
  }
}

class DonationsDatabase extends ChangeNotifier {
  DonationsDatabase(this.storage);
  final ReportsStorage storage;
  DonationsData? _data;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  Future<void> _load() async {
    if (_data != null) return;
    final raw = await storage.read();
    _data = raw == null
        ? DonationsData()
        : DonationsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<T> _run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<T> read<T>(T Function(DonationsData) f) => _run(() async {
    await _load();
    return f(_data!);
  });
  Future<T> mutate<T>(T Function(DonationsData) f) => _run(() async {
    await _load();
    final draft = DonationsData.fromJson(_data!.toJson());
    final result = f(draft);
    await storage.write(jsonEncode(draft.toJson()));
    _data = draft;
    if (!_disposed) notifyListeners();
    return result;
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
