import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/employee.dart';
import '../models/group.dart';
import '../services/enrollment_service.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../utils/enrollment_pdf.dart';
import '../utils/pricing.dart';
import '../widgets/ui.dart';

/// Admin view of a single employee's submitted enrollment.
class EnrollmentDetailScreen extends StatelessWidget {
  final String groupId;
  final Employee employee;
  const EnrollmentDetailScreen({
    super.key,
    required this.groupId,
    required this.employee,
  });

  String _planLabel(String? p) => switch (p) {
        'preventiveOnly' => 'Preventive Only',
        'preventiveCooperative' => 'Preventive + Cooperative',
        _ => p ?? '-',
      };

  String _tierLabel(String? t) => switch (t) {
        'employeeOnly' => 'Employee Only',
        'spouseChild' => 'Employee + Spouse/Child(ren)',
        'family' => 'Employee + Family',
        _ => t ?? '-',
      };

  String _yn(dynamic v) => (v == true) ? 'Yes' : 'No';

  Future<void> _downloadPdf(BuildContext context, Map<String, dynamic> data) async {
    final group = await GroupService().getGroup(groupId);
    final submitted = (data['submittedAt'] as Timestamp?)?.toDate();
    final submittedText =
        submitted != null ? DateFormat.yMMMd().add_jm().format(submitted) : '';
    final bytes = await buildEnrollmentPdf(
      groupName: group?.name ?? '',
      employee: employee,
      data: data,
      submittedText: submittedText,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${employee.fullName.isEmpty ? 'enrollment' : employee.fullName} enrollment.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(employee.fullName.isEmpty ? 'Enrollment' : employee.fullName),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: EnrollmentService().getEnrollment(groupId, employee.id!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.coral));
          }
          final data = snap.data;
          if (data == null) {
            return const Center(
              child: Text('No submitted enrollment for this employee yet.',
                  style: TextStyle(color: AppColors.muted)),
            );
          }
          return _body(context, data);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> data) {
    final personal = (data['personal'] as Map?) ?? {};
    final dependents = (data['dependents'] as Map?) ?? {};
    final medical = (data['medical'] as Map?) ?? {};
    final dental = (data['dental'] as Map?) ?? {};
    final ichra = (data['ichra'] as Map?) ?? {};
    final acks = (data['acknowledgements'] as Map?) ?? {};
    final totals = (data['totals'] as Map?) ?? {};
    final audit = (data['audit'] as Map?) ?? {};
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final sig = data['signature'] as String?;

    return PageBody(
      maxWidth: 820,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Submitted enrollment'),
                  const SizedBox(height: 6),
                  Text(employee.fullName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  if (submittedAt != null) ...[
                    const SizedBox(height: 4),
                    Text('Submitted ${DateFormat.yMMMd().add_jm().format(submittedAt)}',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('TOTAL / MONTH',
                      style: TextStyle(
                          color: Color(0xFF9DB2CC),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(money((totals['monthly'] ?? 0) as num),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _downloadPdf(context, data),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Download PDF'),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Personal',
          child: Column(children: [
            _row('Name',
                '${personal['firstName'] ?? ''} ${personal['middleName'] ?? ''} ${personal['lastName'] ?? ''}'
                    .replaceAll('  ', ' ')
                    .trim()),
            _row('Date of birth', '${personal['dob'] ?? '-'}'),
            _row('SSN', '${personal['ssn'] ?? '-'}'),
            _row('Address', '${personal['address'] ?? '-'}'),
            _row('Tobacco user', _yn(personal['tobaccoUser'])),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Dependents',
          child: _dependents(dependents),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Coverage',
          child: Column(children: [
            _row('Coverage tier', _tierLabel(medical['tier'] as String?)),
            _row('Medical plan', _planLabel(medical['plan'] as String?)),
            if (medical['level'] != null)
              _row('Deductible level', coopLevelLabel('${medical['level']}')),
            _row('Medical cost', '${money((medical['monthly'] ?? 0) as num)}/mo'),
            _row('Dental',
                (dental['enrolled'] == true) ? '${money((dental['monthly'] ?? 0) as num)}/mo' : 'Not enrolled'),
            _row('ICHRA interest', _yn(ichra['interested'])),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Acknowledgements',
          child: Column(children: [
            _ack('Tobacco acknowledgement', acks['tobacco'] == true),
            _ack('Pre-existing condition acknowledgement', acks['preEx'] == true),
            _ack('Payroll deduction authorization', acks['deduction'] == true),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Signature & record',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sig == null)
                const Text('No signature on file.', style: TextStyle(color: AppColors.muted))
              else
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(base64Decode(sig), fit: BoxFit.contain),
                ),
              const SizedBox(height: 14),
              _row('Signed at',
                  submittedAt != null ? DateFormat.yMMMd().add_jms().format(submittedAt) : '-'),
              _row('E-signature consent', _yn(audit['consentToEsign'])),
              _row('Document version', '${audit['documentVersion'] ?? '-'}'),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  String _name(Map m) =>
      '${m['firstName'] ?? ''} ${m['middleName'] ?? ''} ${m['lastName'] ?? ''}'
          .replaceAll('  ', ' ')
          .trim();

  Widget _subhead(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 13)),
      );

  Widget _dependents(Map dependents) {
    final spouse = dependents['spouse'];
    final children = dependents['children'];
    final rows = <Widget>[];

    if (spouse is Map) {
      rows.add(_subhead('Spouse / partner'));
      rows.add(_row('Name', _name(spouse)));
      rows.add(_row('SSN', '${spouse['ssn'] ?? '-'}'));
      if ('${spouse['phone'] ?? ''}'.isNotEmpty) rows.add(_row('Phone', '${spouse['phone']}'));
      if ('${spouse['email'] ?? ''}'.isNotEmpty) rows.add(_row('Email', '${spouse['email']}'));
    } else {
      rows.add(_row('Spouse / partner', _yn(spouse)));
    }

    if (children is List) {
      if (children.isEmpty) {
        rows.add(_row('Children', 'None'));
      }
      for (var i = 0; i < children.length; i++) {
        final c = children[i];
        if (c is! Map) continue;
        rows.add(_subhead('Child ${i + 1}'));
        rows.add(_row('Name', _name(c)));
        rows.add(_row('SSN', '${c['ssn'] ?? '-'}'));
      }
    } else {
      rows.add(_row('Children (26 and under)', '${children ?? 0}'));
    }

    return Column(children: rows);
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: Text(k, style: const TextStyle(color: AppColors.muted)),
            ),
            Expanded(
              child: Text(v.isEmpty ? '-' : v,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy)),
            ),
          ],
        ),
      );

  Widget _ack(String label, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18, color: ok ? const Color(0xFF0A7D4F) : AppColors.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.ink))),
          ],
        ),
      );
}
