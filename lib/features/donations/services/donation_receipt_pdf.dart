import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/enums/donation_type.dart';
import '../models/donation_receipt.dart';
import 'donation_rules.dart';

class DonationReceiptPdf {
  static List<String> _chunks(String text) {
    final chunks = <String>[];
    var remaining = text;
    while (remaining.length > 600) {
      var end = remaining.lastIndexOf(' ', 600);
      if (end < 300) end = 600;
      chunks.add(remaining.substring(0, end));
      remaining = remaining.substring(end).trimLeft();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  static Future<Uint8List> build(DonationReceipt receipt) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
    );
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/animora_logo.png')).buffer
          .asUint8List(),
    );
    final doc = pw.Document(
      title: receiptNotice,
      author: 'Animora - démonstration locale',
    );
    final violet = PdfColor.fromHex('#8B5CF6'),
        navy = PdfColor.fromHex('#172554');
    String date(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (c) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(
                logo,
                width: 190,
                height: 75,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'REÇU DE DÉMONSTRATION',
              style: pw.TextStyle(
                color: navy,
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              color: PdfColor.fromHex('#F3E8FF'),
              child: pw.Text(
                receiptNotice,
                style: pw.TextStyle(
                  color: navy,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (c) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Document non fiscal - aucune valeur de paiement',
              style: pw.TextStyle(fontSize: 8, color: navy),
            ),
            pw.Text(
              '${c.pageNumber}/${c.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (c) => [
          pw.Text(
            receipt.reference,
            style: pw.TextStyle(
              fontSize: 15,
              color: violet,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Référence du don : ${receipt.donationReference}'),
          pw.Text('Date d’émission : ${date(receipt.issueDate)}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Donateur',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: navy),
          ),
          pw.Text(receipt.donorName),
          pw.SizedBox(height: 16),
          pw.Text(
            'Campagne',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: navy),
          ),
          pw.Text(receipt.campaignTitle),
          pw.SizedBox(height: 16),
          pw.Text(
            'Type de contribution',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: navy),
          ),
          pw.Text(receipt.type.label),
          pw.SizedBox(height: 16),
          if (receipt.type == DonationType.FINANCIAL)
            pw.Text(
              'Montant simulé : ${DonationMoney.format(receipt.amount!)}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            )
          else ...[
            pw.Text(
              'Matériel réceptionné dans la démonstration',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: navy),
            ),
            ..._chunks(receipt.materialDescription ?? '').map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(line),
              ),
            ),
          ],
          pw.SizedBox(height: 28),
          pw.Divider(color: violet),
          pw.SizedBox(height: 12),
          pw.Text(
            'Ce document atteste uniquement d’un enregistrement dans la démonstration locale Animora. Il ne constitue ni une preuve de paiement, ni un reçu fiscal officiel, ni un justificatif ouvrant droit à un avantage fiscal.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
