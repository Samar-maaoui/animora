import '../repositories/sqlite_donation_repository.dart';
import '../../../core/database/sqlite_runtime_scope.dart';
import '../database/sqlite_donations_database.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/state/auth_session.dart';
import '../../reports/repositories/reports_storage.dart';
import '../repositories/donations_database.dart';
import '../repositories/local_donation_repository.dart';
import '../repositories/donation_campaign_repository.dart';
import '../repositories/donation_repository.dart';
import '../repositories/material_donation_repository.dart';
import '../repositories/recurring_donation_repository.dart';
import '../repositories/donation_receipt_repository.dart';
import '../repositories/material_need_repository.dart';
import '../repositories/transparency_report_repository.dart';

class DonationsStore extends ChangeNotifier {
  DonationsStore(this.repository, this.database, this.session) {
    database.addListener(refresh);
    session.addListener(refresh);
  }
  final LocalDonationRepository repository;
  final DonationsDatabase database;
  final AuthSession session;
  int revision = 0;
  void refresh() {
    revision++;
    notifyListeners();
  }

  DonationCampaignRepository get campaigns => repository;
  DonationRepository get donations => repository;
  MaterialDonationRepository get materials => repository;
  RecurringDonationRepository get recurring => repository;
  DonationReceiptRepository get receipts => repository;
  MaterialNeedRepository get needs => repository;
  TransparencyReportRepository get reports => repository;
  DateTime get now => repository.clock();
  @override
  void dispose() {
    database.removeListener(refresh);
    session.removeListener(refresh);
    super.dispose();
  }
}

class DonationsScope extends StatefulWidget {
  const DonationsScope({
    super.key,
    required this.child,
    this.storage,
    this.clock,
  });
  final Widget child;
  final ReportsStorage? storage;
  final DateTime Function()? clock;
  @override
  State<DonationsScope> createState() => _DonationsScopeState();
}

class _DonationsScopeState extends State<DonationsScope> {
  late final DonationsDatabase database;
  late final DonationsStore store;
  @override
  void initState() {
    super.initState();
    final session = context.read<AuthSession>();
    final runtime = context.read<SqliteRuntime?>()?.context;
    final legacy =
        widget.storage ?? SembastReportsStorage(namespace: 'donations');
    database = runtime == null
        ? DonationsDatabase(legacy)
        : SqliteDonationsDatabase(runtime, legacy);
    store = DonationsStore(
      runtime == null
          ? LocalDonationRepository(
              database,
              () => session.currentUser,
              clock: widget.clock,
            )
          : SqliteDonationRepository(
              database,
              () => session.currentUser,
              clock: widget.clock,
            ),
      database,
      session,
    );
  }

  @override
  void dispose() {
    store.dispose();
    database.dispose();
    unawaited(database.storage.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext c) =>
      ChangeNotifierProvider.value(value: store, child: widget.child);
}
