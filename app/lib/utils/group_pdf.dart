import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/group.dart';
import 'pricing.dart';

/// Builds a one-document "group setup" PDF summarizing everything configured
/// for a group (employer info, plan & rates, dental, ICHRA, product content).
/// Sent along to the partner organization.

final _navy = PdfColor.fromInt(0xFF0E2A47);
final _coral = PdfColor.fromInt(0xFFFF736A);
final _muted = PdfColor.fromInt(0xFF5B6675);
final _line = PdfColor.fromInt(0xFFE4E7EC);

String _dash(String s) => s.trim().isEmpty ? '-' : s.trim();
String _yn(bool v) => v ? 'Yes' : 'No';

Future<Uint8List> buildGroupInfoPdf(Group group) async {
  final d = group.details;
  final doc = pw.Document();

  final cityLine = [d.city, d.state, d.zip].where((s) => s.trim().isNotEmpty).join(', ');
  final address = [d.addressLine1, d.addressLine2, cityLine]
      .where((s) => s.trim().isNotEmpty)
      .join(' · ');

  doc.addPage(pw.MultiPage(
    margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('HealthPass + Health Access',
              style: pw.TextStyle(color: _coral, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Group Setup Summary',
              style: pw.TextStyle(
                  color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      pw.SizedBox(height: 8),
      pw.Text(group.name.isEmpty ? 'Untitled group' : group.name,
          style: pw.TextStyle(color: _muted, fontSize: 11)),
      pw.SizedBox(height: 18),

      _section('Group / Employer', [
        ['Group / employer name', _dash(group.name)],
        ['DBA', _dash(d.dba)],
        ['Admin email', _dash(group.contactEmail)],
        ['Tax ID', _dash(d.taxId)],
        ['Full-time employees', _dash(d.fullTimeEmployees)],
        ['Website', _dash(d.website)],
        ['Phone', _dash(d.businessPhone)],
        ['Address', _dash(address)],
        ['Effective date', _dash(d.effectiveDate)],
      ]),

      _section('Affiliate & Referer', [
        ['Affiliate company', _dash(d.affiliateCompany)],
        ['Affiliate email', _dash(d.affiliateEmail)],
        ['Referral partner', _dash(d.referralPartner)],
        ['Referer name', _dash(d.refererName)],
      ]),

      _section('Contacts', [
        ['Admin contact', _dash('${d.adminFirstName} ${d.adminLastName}'.trim())],
        ['Admin phone', _dash(d.adminPhone)],
        ['Billing contact', _dash('${d.billingFirstName} ${d.billingLastName}'.trim())],
        ['Billing email', _dash(d.billingEmail)],
        ['Billing phone', _dash(d.billingPhone)],
      ]),

      _section('Eligibility', [
        ['Eligibility definition', _dash(d.eligibilityDefinition)],
        [
          'New-hire waiting period',
          d.waitingPeriod == WaitingPeriod.other
              ? _dash(d.waitingPeriodOther)
              : d.waitingPeriod.label
        ],
      ]),

      _medicalSection(group),

      _section('Tobacco surcharge', [
        ['Surcharge', '\$${group.tobaccoSurcharge.toInt()} per tobacco user, per month'],
        ['Paid by', group.tobaccoSurchargePayer.label],
      ]),

      _dentalSection(group),
      _ichraSection(group),

      _section('Product content', [
        ['Preventive video', _dash(d.preventiveVideoUrl)],
        ['Bundle video', _dash(d.healthVideoUrl)],
        ['ICHRA video', _dash(d.ichraVideoUrl)],
        ['Dental video', _dash(d.dentalVideoUrl)],
      ]),

      if (d.notes.trim().isNotEmpty) _section('Notes', [['Notes', d.notes.trim()]]),
    ],
  ));

  return doc.save();
}

pw.Widget _medicalSection(Group group) {
  final rows = <List<String>>[
    [
      'Contribution strategy',
      group.contributionMode == ContributionMode.definedContribution
          ? 'Defined contribution'
          : 'Employee-facing price'
    ],
    [
      'Offered deductible levels',
      group.offeredLevels.isEmpty
          ? '-'
          : group.offeredLevels.map(coopLevelLabel).join(', ')
    ],
    ['Payroll frequency', group.payFrequency.label],
  ];
  if (group.contributionMode == ContributionMode.definedContribution) {
    rows.add([
      'Employer contribution',
      '\$${group.definedContribution.employerContribution.toInt()} / mo per employee'
    ]);
    rows.add(['Rate table', 'Age-banded (see Agency Network Estimate Tool)']);
  } else {
    for (final level in group.offeredLevels) {
      final r = group.medicalRates[level];
      if (r == null) continue;
      rows.add([
        '${coopLevelLabel(level)} rates',
        'EO ${money(r.employeeOnly)} / +Spouse/Child ${money(r.spouseChild)} / '
            '+Family ${money(r.family)}'
      ]);
    }
  }
  return _section('Medical', rows);
}

pw.Widget _dentalSection(Group group) {
  final dn = group.dental;
  final rows = <List<String>>[['Offered', _yn(dn.enabled)]];
  if (dn.enabled) {
    rows.add(['Plan', dn.planName]);
    rows.add([
      'Tier rates (fixed)',
      'EO ${money(dn.rates.employeeOnly)} / +Spouse ${money(dn.rates.spouse)} / '
          '+Child ${money(dn.rates.child)} / +Family ${money(dn.rates.family)}'
    ]);
    rows.add(['Contribution', dn.contributionMode.label]);
    if (dn.contributionMode == DentalContributionMode.companyContribution) {
      rows.add(['Company contribution', '${money(dn.companyContribution)} / mo (subtracted per tier)']);
    }
  }
  return _section('Dental', rows);
}

pw.Widget _ichraSection(Group group) {
  final d = group.details;
  final rows = <List<String>>[['Offered', _yn(group.ichraEnabled)]];
  if (group.ichraEnabled) {
    rows.add(['Employee target', '${money(d.ichraEoTarget)} / mo']);
    rows.add(['Spouse target', '${money(d.ichraSpouseTarget)} / mo']);
    rows.add(['Child target', '${money(d.ichraChildTarget)} / mo']);
  }
  return _section('ICHRA', rows);
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
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(
                  width: 170,
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
