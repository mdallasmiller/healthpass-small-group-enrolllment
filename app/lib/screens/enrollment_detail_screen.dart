import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../models/group.dart';
import '../services/enrollment_service.dart';
import '../theme.dart';
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
        const SizedBox(height: 20),
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
          child: Column(children: [
            _row('Spouse / partner', _yn(dependents['spouse'])),
            _row('Children (26 and under)', '${dependents['children'] ?? 0}'),
          ]),
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
          title: 'Signature',
          child: sig == null
              ? const Text('No signature on file.', style: TextStyle(color: AppColors.muted))
              : Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(base64Decode(sig), fit: BoxFit.contain),
                ),
        ),
        const SizedBox(height: 40),
      ],
    );
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
