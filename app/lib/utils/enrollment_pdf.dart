import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/employee.dart';
import '../models/group.dart';
import 'pricing.dart';

final _navy = PdfColor.fromInt(0xFF0E2A47);
final _coral = PdfColor.fromInt(0xFFFF736A);
final _muted = PdfColor.fromInt(0xFF5B6675);
final _line = PdfColor.fromInt(0xFFE4E7EC);

String _planLabel(String? p) => switch (p) {
      'preventiveOnly' => 'Preventive Only',
      'preventiveCooperative' => 'Preventive + Cooperative',
      _ => p ?? '-',
    };

String _tierLabel(String? t) => switch (t) {
      'employeeOnly' => 'Employee Only',
      'spouse' => 'Employee + Spouse',
      'child' => 'Employee + Child(ren)',
      'spouseChild' => 'Employee + Spouse/Child(ren)',
      'family' => 'Employee + Family',
      _ => t ?? '-',
    };

String _name(Map m) =>
    '${m['firstName'] ?? ''} ${m['middleName'] ?? ''} ${m['lastName'] ?? ''}'
        .replaceAll('  ', ' ')
        .trim();

String _yn(dynamic v) => v == true ? 'Yes' : 'No';

/// Builds a one-document enrollment confirmation PDF.
Future<Uint8List> buildEnrollmentPdf({
  required String groupName,
  required Employee employee,
  required Map<String, dynamic> data,
  required String submittedText,
}) async {
  final personal = (data['personal'] as Map?) ?? {};
  final dependents = (data['dependents'] as Map?) ?? {};
  final medical = (data['medical'] as Map?) ?? {};
  final dental = (data['dental'] as Map?) ?? {};
  final ichra = (data['ichra'] as Map?) ?? {};
  final acks = (data['acknowledgements'] as Map?) ?? {};
  final audit = (data['audit'] as Map?) ?? {};
  final totals = (data['totals'] as Map?) ?? {};
  final sigB64 = data['signature'] as String?;
  final pw.MemoryImage? sig =
      sigB64 != null ? pw.MemoryImage(base64Decode(sigB64)) : null;

  final doc = pw.Document();

  doc.addPage(pw.MultiPage(
    margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
    build: (ctx) => [
      // Header
      pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('HealthPass + Health Access',
                  style: pw.TextStyle(color: _coral, fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Enrollment Confirmation',
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('TOTAL / MONTH',
                  style: pw.TextStyle(color: PdfColor.fromInt(0xFF9DB2CC), fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Text(money((totals['monthly'] ?? 0) as num),
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text('$groupName  -  ${employee.fullName}  -  $submittedText',
          style: pw.TextStyle(color: _muted, fontSize: 10)),
      pw.SizedBox(height: 18),

      _section('Personal', [
        ['Name', _name(personal)],
        ['Date of birth', '${personal['dob'] ?? '-'}'],
        ['SSN', '${personal['ssn'] ?? '-'}'],
        ['Address', '${personal['address'] ?? '-'}'],
        ['Tobacco user', _yn(personal['tobaccoUser'])],
      ]),
      _dependentsSection(dependents),
      _section('Coverage', [
        ['Coverage tier', _tierLabel(medical['tier'] as String?)],
        ['Medical plan', _planLabel(medical['plan'] as String?)],
        if (medical['level'] != null) ['Deductible level', coopLevelLabel('${medical['level']}')],
        ['Medical cost', '${money((medical['monthly'] ?? 0) as num)}/mo'],
        [
          'Dental',
          dental['enrolled'] == true ? '${money((dental['monthly'] ?? 0) as num)}/mo' : 'Not enrolled'
        ],
        ['ICHRA interest', _yn(ichra['interested'])],
      ]),
      _section('Acknowledgements', [
        ['Tobacco', _yn(acks['tobacco'])],
        ['Pre-existing condition', _yn(acks['preEx'])],
        ['Payroll deduction', _yn(acks['deduction'])],
        ['E-signature consent', _yn(audit['consentToEsign'])],
      ]),
      pw.SizedBox(height: 12),
      pw.Text('SIGNATURE',
          style: pw.TextStyle(color: _muted, fontSize: 9, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Container(
        height: 110,
        width: double.infinity,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
        child: sig != null
            ? pw.Image(sig, fit: pw.BoxFit.contain)
            : pw.Center(child: pw.Text('No signature', style: pw.TextStyle(color: _muted))),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Document ${audit['documentVersion'] ?? '-'} · Signed $submittedText · '
        'Electronic signature consented.',
        style: pw.TextStyle(color: _muted, fontSize: 8),
      ),
    ],
  ));

  return doc.save();
}

pw.Widget _section(String title, List<List<String>> rows) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title.toUpperCase(),
          style: pw.TextStyle(color: _navy, fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Divider(color: _line, thickness: 1),
      ...rows.map((r) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 160,
                  child: pw.Text(r[0], style: pw.TextStyle(color: _muted, fontSize: 10))),
              pw.Expanded(
                  child: pw.Text(r[1].isEmpty ? '-' : r[1],
                      style: pw.TextStyle(
                          color: _navy, fontSize: 10, fontWeight: pw.FontWeight.bold))),
            ]),
          )),
    ]),
  );
}

pw.Widget _dependentsSection(Map dependents) {
  final spouse = dependents['spouse'];
  final children = dependents['children'];
  final rows = <List<String>>[];
  if (spouse is Map) {
    rows.add(['Spouse name', _name(spouse)]);
    rows.add(['Spouse SSN', '${spouse['ssn'] ?? '-'}']);
  } else {
    rows.add(['Spouse / partner', _yn(spouse)]);
  }
  if (children is List) {
    if (children.isEmpty) rows.add(['Children', 'None']);
    for (var i = 0; i < children.length; i++) {
      final c = children[i];
      if (c is! Map) continue;
      rows.add(['Child ${i + 1}', '${_name(c)}  (SSN ${c['ssn'] ?? '-'})']);
    }
  } else {
    rows.add(['Children (26 and under)', '${children ?? 0}']);
  }
  return _section('Dependents', rows);
}
