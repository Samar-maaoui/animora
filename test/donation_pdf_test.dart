import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:animora/core/enums/donation_type.dart';
import 'package:animora/features/donations/models/donation_receipt.dart';
import 'package:animora/features/donations/services/donation_receipt_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  DonationReceipt receipt({String? material}) => DonationReceipt(
    id: 12,
    donationId: 10,
    issueDate: DateTime(2026, 11, 9, 15),
    reference: 'DEMO-RECU-000012',
    donationReference: 'DEMO-DON-000010',
    donorName: 'Amine Ben Ali - compte fictif',
    campaignTitle:
        'Soins et nourriture pour les animaux - campagne de démonstration',
    type: material == null ? DonationType.FINANCIAL : DonationType.MATERIAL,
    amount: material == null ? 25.125 : null,
    materialDescription: material,
  );
  test(
    'Financial receipt PDF uses bundled logo fonts and explicit demo document',
    () async {
      final bytes = await DonationReceiptPdf.build(receipt());
      expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));
      expect(bytes.length, greaterThan(10000));
      final file = File('output/pdf/animora-recu-demo.pdf');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    },
  );
  test('Long material receipt paginates without overflow', () async {
    final text = List.filled(
      80,
      'Matériel fictif réceptionné pour les animaux. Description détaillée de la contribution locale, sans paiement réel ni document fiscal officiel.',
    ).join(' ');
    final bytes = await DonationReceiptPdf.build(receipt(material: text));
    expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));
    final file = File('../../work/step6-material-long.pdf');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  });
}
