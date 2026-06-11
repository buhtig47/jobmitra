// lib/services/cheatsheet_pdf.dart
//
// Pre-fill cheat-sheet PDF generator. Combines a user's PersonalInfo
// (locally stored — never sent to backend) with a specific Job's metadata
// into a printable A4 sheet that aspirants can take to a cyber cafe and
// hand the operator while applying through the official portal.
//
// Layout: header with job title + dept, two-column field table with all
// PersonalInfo fields (including the CAPS variant of father's/mother's
// name which most govt forms still require), then the document checklist
// from job.documentsNeeded, and a small footer note that the cheat-sheet
// is just a reference (we never submit on behalf of the user).
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/job_model.dart';

class CheatsheetPdf {
  static Future<void> shareForJob({
    required Job job,
    required PersonalInfo info,
  }) async {
    final pdf = pw.Document(
      title: 'JobMitra Cheat-Sheet — ${job.cleanTitle}',
      author: 'JobMitra',
    );

    final theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.notoSansRegular(),
      bold: await PdfGoogleFonts.notoSansBold(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        theme: theme,
        header: (_) => _buildHeader(job),
        footer: (ctx) => _buildFooter(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _buildJobBlock(job),
          pw.SizedBox(height: 14),
          _buildDatesBlock(job),
          pw.SizedBox(height: 14),
          _buildPersonalBlock(info),
          pw.SizedBox(height: 14),
          _buildDocsBlock(job),
          pw.SizedBox(height: 14),
          _buildStepsBlock(job),
          pw.SizedBox(height: 14),
          _buildOfficialLinkBlock(job),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'JobMitra-${_safeName(job.cleanTitle)}.pdf',
    );
  }

  // ── Sections ───────────────────────────────────────────────

  static pw.Widget _buildHeader(Job job) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.green800, width: 2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('JobMitra Cheat-Sheet',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800)),
              pw.Text('Form-fill helper (not an application)',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.Text(_formattedDate(),
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _buildJobBlock(Job job) {
    return _sectionCard(
      title: 'JOB',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _row('Title', job.cleanTitle),
          _row('Department', job.cleanDepartment),
          _row('Category', job.categoryLabel),
          _row('Vacancies', job.vacanciesText),
          _row('Last date', job.lastDate),
          _row('Fee', job.feeText),
          if ((job.payScale ?? '').isNotEmpty)
            _row('Pay scale', job.payScale!),
        ],
      ),
    );
  }

  static pw.Widget _buildDatesBlock(Job job) {
    return _sectionCard(
      title: 'IMPORTANT DATES',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _row('Last Date to Apply', job.lastDate.isEmpty ? 'As per notification' : job.lastDate),
          _row('Days Remaining', job.daysLeft >= 0 ? '${job.daysLeft} days' : 'Deadline passed'),
          _row('Generated On', _formattedDate()),
          pw.SizedBox(height: 4),
          pw.Text(
            'Note: Always verify dates on the official website before applying.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStepsBlock(Job job) {
    const steps = [
      ('1', 'Official website kholein aur "Apply Online" link dhundhein'),
      ('2', 'New Registration karein ya login karein (email + mobile chahiye)'),
      ('3', 'Personal details bharen — name, DOB, category (neeche se copy karein)'),
      ('4', 'Documents upload karein — photo (JPG <100KB), signature (JPG <30KB)'),
      ('5', 'Fee payment karein (debit/credit card / net banking / UPI)'),
      ('6', 'Application submit karein aur confirmation number save karein'),
      ('7', 'Final submitted application ka printout lein (evidence ke liye)'),
    ];
    return _sectionCard(
      title: 'STEPS TO APPLY',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: steps.map(((String step, String text) e) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 18, height: 18,
                margin: const pw.EdgeInsets.only(right: 8, top: 1),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.green800,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(e.$1,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(e.$2, style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  static pw.Widget _buildPersonalBlock(PersonalInfo info) {
    final entries = <(String, String)>[
      ('Name',               info.name),
      ('Name (CAPS)',        info.name.toUpperCase()),
      ("Father's Name",      info.fatherName),
      ("Father's (CAPS)",    info.fatherName.toUpperCase()),
      ("Mother's Name",      info.motherName),
      ("Mother's (CAPS)",    info.motherName.toUpperCase()),
      ('Date of Birth',      info.dob),
      ('Gender',             info.gender),
      ('Category',           info.category),
      ('Mobile',             info.phone),
      ('Email',              info.email),
      ('Address',            info.address),
      ('District',           info.district),
      ('State',              info.state),
      ('Pincode',            info.pincode),
      if (info.aadharLast4.isNotEmpty)
        ('Aadhaar (last 4)',  info.aadharLast4),
    ].where((e) => e.$2.trim().isNotEmpty).toList();

    return _sectionCard(
      title: 'PERSONAL DETAILS',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: entries.map((e) => _row(e.$1, e.$2)).toList(),
      ),
    );
  }

  static pw.Widget _buildDocsBlock(Job job) {
    final docs = job.documentsNeeded ?? const <String>[];
    if (docs.isEmpty) {
      return _sectionCard(
        title: 'DOCUMENTS',
        child: pw.Text(
          'Specific document list not extracted for this notification. '
          'Common requirements: 10th + 12th marksheets, graduation degree, '
          'caste certificate (if applicable), Aadhaar, recent photo + signature, '
          'income certificate (for fee waiver).',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }
    return _sectionCard(
      title: 'DOCUMENTS REQUIRED',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: docs
            .map((d) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 9,
                        height: 9,
                        margin: const pw.EdgeInsets.only(top: 3, right: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey800),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(d,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  static pw.Widget _buildOfficialLinkBlock(Job job) {
    return _sectionCard(
      title: 'OFFICIAL LINK',
      child: pw.Text(
        job.sourceUrl,
        style: const pw.TextStyle(
            fontSize: 9, color: PdfColors.blue800),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Generated by JobMitra · Page ${ctx.pageNumber}/${ctx.pagesCount} · '
        'This sheet is for reference only — apply on the official portal.',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
    );
  }

  // ── Primitives ─────────────────────────────────────────────

  static pw.Widget _sectionCard({required String title, required pw.Widget child}) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                  letterSpacing: 0.5)),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey800)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _formattedDate() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, "0")}/'
        '${n.month.toString().padLeft(2, "0")}/${n.year}';
  }

  static String _safeName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-');
    return cleaned.substring(0, cleaned.length.clamp(0, 40));
  }
}
