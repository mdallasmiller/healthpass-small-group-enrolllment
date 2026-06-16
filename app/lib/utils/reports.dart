import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Enrollment Census (with elections) + Payroll Deduction Report builders,
/// matching the client's CSV templates.
///
/// Input is the list returned by EnrollmentService.getGroupEnrollments:
/// each item is {employeeId, employee: {...}, data: {...}}.

final _navy = PdfColor.fromInt(0xFF0E2A47);
final _coral = PdfColor.fromInt(0xFFFF736A);
final _muted = PdfColor.fromInt(0xFF5B6675);
final _line = PdfColor.fromInt(0xFFE4E7EC);

String _s(dynamic v) => (v ?? '').toString().trim();

/// Money with two decimals, e.g. $300.00. Empty/zero -> '-' when [dashIfZero].
String _money2(num v, {bool dashIfZero = false}) {
  if (dashIfZero && v == 0) return '-';
  final neg = v < 0;
  final cents = (v.abs() * 100).round();
  final dollars = cents ~/ 100;
  final frac = cents % 100;
  final s = dollars.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}\$$buf.${frac.toString().padLeft(2, '0')}';
}

String _planLabel(String? p) => switch (p) {
      'preventiveOnly' => 'Preventive',
      'preventiveCooperative' => 'Bundle (Preventive + Co-op)',
      _ => p ?? '',
    };

String _tierLabel(String? t) => switch (t) {
      'employeeOnly' => 'Employee Only',
      'spouse' => 'Employee + Spouse',
      'child' => 'Employee + Child(ren)',
      'family' => 'Employee + Family',
      'spouseChild' => 'Employee + Spouse/Child(ren)',
      _ => '',
    };

String _payFreq(String? f) => switch (f) {
      'weekly' => 'Weekly (52)',
      'biWeekly' => 'Bi-weekly (26)',
      'semiMonthly' => 'Semi-monthly (24)',
      'monthly' => 'Monthly (12)',
      _ => 'Monthly (12)',
    };

/// "Medical: 2500 Cooperative" / "Medical: Preventive".
String _medicalSummary(Map medical) {
  final plan = medical['plan'] as String?;
  if (plan == 'preventiveCooperative') {
    final lvl = medical['level'] != null ? coopLevelLabelPlain('${medical['level']}') : '';
    return 'Medical: $lvl Cooperative'.replaceAll('  ', ' ').trim();
  }
  if (plan == 'preventiveOnly') return 'Medical: Preventive';
  return '';
}

/// Plain level (1000 -> 1000) for the census summary string.
String coopLevelLabelPlain(String level) => level;

// ---------------------------------------------------------------------------
// ENROLLMENT CENSUS (with elections): matches the elections template.

const _censusHeader = [
  'Group Name', 'First Name', 'Middle Name', 'Last Name', 'Relationship',
  'Hours', 'Status', 'SSN', 'DOB', 'Sex', 'Tobacco',
  'Address', 'Second', 'City', 'State', 'Zip', 'Phone', 'Email',
  'Medical', 'Medical Tier', 'Dental Enrollment', 'Dental Tier',
  'ICHRA', 'ICHRA Note', 'Tobacco Acknowledgement', 'Pre-ex Acknowledgement',
];

List<List<String>> censusRows(String groupName, List<Map<String, dynamic>> enrollments) {
  final rows = <List<String>>[];
  for (final e in enrollments) {
    final emp = (e['employee'] as Map?) ?? {};
    final data = (e['data'] as Map).cast<String, dynamic>();
    final personal = (data['personal'] as Map?) ?? {};
    final dependents = (data['dependents'] as Map?) ?? {};
    final medical = (data['medical'] as Map?) ?? {};
    final dental = (data['dental'] as Map?) ?? {};
    final acks = (data['acknowledgements'] as Map?) ?? {};
    final ichra = (data['ichra'] as Map?) ?? {};

    final dentalYn = dental['enrolled'] == true ? 'Yes' : 'No';
    final dentalTier = dental['enrolled'] == true ? _tierLabel(dental['tier'] as String?) : '';
    final ichraYn = ichra['interested'] == true ? 'Yes' : 'No';
    final tobaccoYn = personal['tobaccoUser'] == true ? 'Yes' : 'No';

    // Employee row (full demographics from imported data + portal elections).
    rows.add([
      groupName,
      _s(personal['firstName']), _s(personal['middleName']), _s(personal['lastName']),
      'Employee',
      _s(emp['employmentStatus']),
      emp['eligible'] == false ? 'Not Eligible' : 'Active',
      _s(personal['ssn']), _s(personal['dob']), _s(personal['sex']), tobaccoYn,
      _s(personal['addressLine1']), _s(personal['addressLine2']),
      _s(personal['city']), _s(personal['state']), _s(personal['zip']),
      _s(emp['mobilePhone']).isNotEmpty ? _s(emp['mobilePhone']) : _s(emp['phone']),
      _s(emp['email']),
      _medicalSummary(medical), _tierLabel(medical['tier'] as String?),
      dentalYn, dentalTier,
      ichraYn, _s(ichra['note']),
      acks['tobacco'] == true ? 'Agreed' : '',
      acks['preEx'] == true ? 'Agreed' : '',
    ]);

    final spouse = dependents['spouse'];
    if (spouse is Map) {
      rows.add([
        groupName,
        _s(spouse['firstName']), _s(spouse['middleName']), _s(spouse['lastName']),
        'Spouse', '', '', _s(spouse['ssn']), '',
        '', spouse['tobaccoUser'] == true ? 'Yes' : 'No',
        '', '', '', '', '', _s(spouse['phone']), _s(spouse['email']),
        '', '', dentalYn, dentalTier, '', '', '', '',
      ]);
    }
    final children = dependents['children'];
    if (children is List) {
      for (final c in children) {
        if (c is! Map) continue;
        rows.add([
          groupName,
          _s(c['firstName']), _s(c['middleName']), _s(c['lastName']),
          'Child', '', '', _s(c['ssn']), '', '', '',
          '', '', '', '', '', '', '',
          '', '', dentalYn, dentalTier, '', '', '', '',
        ]);
      }
    }
  }
  return rows;
}

String censusCsv(String groupName, List<Map<String, dynamic>> enrollments) {
  return const ListToCsvConverter().convert([
    _censusHeader,
    ...censusRows(groupName, enrollments),
  ]);
}

// ---------------------------------------------------------------------------
// PAYROLL DEDUCTION REPORT: matches the deduction template.

const _deductionHeader = [
  'Employee', 'Medical Plan', 'Medical Plan - Tier',
  'Medical Plan - Monthly Employee Cost', 'Monthly Tobacco Surcharge',
  'Dental Plan', 'Dental Tier', 'Dental Plan - Monthly Employee Cost',
  'Monthly Payroll Total', 'Pay Frequency', 'Per Pay Period Deduction',
];

List<List<String>> deductionRows(List<Map<String, dynamic>> enrollments) {
  final rows = <List<String>>[];
  for (final e in enrollments) {
    final data = (e['data'] as Map).cast<String, dynamic>();
    final personal = (data['personal'] as Map?) ?? {};
    final medical = (data['medical'] as Map?) ?? {};
    final dental = (data['dental'] as Map?) ?? {};
    final tob = (data['tobaccoSurcharge'] as Map?) ?? {};
    final totals = (data['totals'] as Map?) ?? {};

    final name = '${_s(personal['firstName'])} ${_s(personal['lastName'])}'.trim();
    final medicalBase = ((medical['monthly'] ?? 0) as num) -
        ((medical['tobaccoSurcharge'] ?? 0) as num);
    final tobTotal = (tob['total'] ?? 0) as num;
    final dentalEnrolled = dental['enrolled'] == true;
    final dentalAmt = dentalEnrolled ? (dental['monthly'] ?? 0) as num : 0;
    final monthly = (totals['monthly'] ?? 0) as num;
    final perPay = (totals['perPayPeriod'] ?? monthly) as num;

    rows.add([
      name,
      _planLabel(medical['plan'] as String?),
      _tierLabel(medical['tier'] as String?),
      _money2(medicalBase),
      _money2(tobTotal, dashIfZero: true),
      dentalEnrolled ? _s(dental['planName']) : '',
      dentalEnrolled ? _tierLabel(dental['tier'] as String?) : '',
      dentalEnrolled ? _money2(dentalAmt) : '-',
      _money2(monthly),
      _payFreq(totals['payFrequency'] as String?),
      _money2(perPay),
    ]);
  }
  return rows;
}

String deductionCsv(List<Map<String, dynamic>> enrollments) {
  return const ListToCsvConverter().convert([
    _deductionHeader,
    ...deductionRows(enrollments),
  ]);
}

// ---------------------------------------------------------------------------
// PDF

Future<Uint8List> censusPdf(String groupName, List<Map<String, dynamic>> enr) =>
    _tablePdf('Enrollment Census', groupName, _censusHeader, censusRows(groupName, enr));

Future<Uint8List> deductionPdf(String groupName, List<Map<String, dynamic>> enr) =>
    _tablePdf('Payroll Deduction Report', groupName, _deductionHeader, deductionRows(enr));

Future<Uint8List> _tablePdf(
  String title,
  String groupName,
  List<String> header,
  List<List<String>> rows,
) async {
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(24),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
            color: _navy, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('HealthPass + Health Access',
                  style: pw.TextStyle(color: _coral, fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(title,
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Text(groupName, style: pw.TextStyle(color: PdfColors.white, fontSize: 11)),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
      if (rows.isEmpty)
        pw.Text('No submitted enrollments yet.',
            style: pw.TextStyle(color: _muted, fontSize: 11))
      else
        pw.TableHelper.fromTextArray(
          headers: header,
          data: rows,
          border: pw.TableBorder.all(color: _line, width: 0.5),
          headerStyle: pw.TextStyle(
              color: PdfColors.white, fontSize: 7, fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(color: _navy),
          cellStyle: pw.TextStyle(color: _navy, fontSize: 7),
          cellHeight: 16,
          oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F8FB)),
        ),
      pw.SizedBox(height: 10),
      pw.Text('${rows.length} row(s).',
          style: pw.TextStyle(color: _muted, fontSize: 9)),
    ],
  ));
  return doc.save();
}
