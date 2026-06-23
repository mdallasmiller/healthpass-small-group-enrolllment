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

class EnrollmentDetailScreen extends StatefulWidget {
  final String groupId;
  final Employee employee;
  const EnrollmentDetailScreen({
    super.key,
    required this.groupId,
    required this.employee,
  });

  @override
  State<EnrollmentDetailScreen> createState() => _EnrollmentDetailScreenState();
}

class _EnrollmentDetailScreenState extends State<EnrollmentDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  Group? _group;

  // Edit state — coverage
  String _eTier = 'employeeOnly';
  String _ePlan = 'preventiveOnly';
  String _eLevel = '';
  bool _eDental = false;

  // Edit state — dependents
  bool _eHasSpouse = false;
  final _spFirst = TextEditingController();
  final _spLast = TextEditingController();
  final _spSsn = TextEditingController();
  final List<List<TextEditingController>> _eChildren = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _spFirst.dispose();
    _spLast.dispose();
    _spSsn.dispose();
    for (final c in _eChildren) {
      for (final ctrl in c) ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final data = await EnrollmentService().getEnrollment(widget.groupId, widget.employee.id!);
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  Future<void> _startEdit() async {
    _group ??= await GroupService().getGroup(widget.groupId);
    final d = _data!;
    final medical = (d['medical'] as Map?) ?? {};
    final dental = (d['dental'] as Map?) ?? {};
    final dependents = (d['dependents'] as Map?) ?? {};

    _eTier = (medical['tier'] as String?) ?? 'employeeOnly';
    _ePlan = (medical['plan'] as String?) ?? 'preventiveOnly';
    _eLevel = (medical['level'] as String?) ?? '';
    _eDental = dental['enrolled'] == true;

    final spouse = dependents['spouse'];
    _eHasSpouse = spouse is Map || spouse == true;
    _spFirst.text = spouse is Map ? (spouse['firstName'] ?? '') : '';
    _spLast.text = spouse is Map ? (spouse['lastName'] ?? '') : '';
    _spSsn.text = spouse is Map ? (spouse['ssn'] ?? '') : '';

    for (final c in _eChildren) for (final ctrl in c) ctrl.dispose();
    _eChildren.clear();
    final children = dependents['children'];
    if (children is List) {
      for (final c in children) {
        _eChildren.add([
          TextEditingController(text: c is Map ? (c['firstName'] ?? '') : ''),
          TextEditingController(text: c is Map ? (c['lastName'] ?? '') : ''),
          TextEditingController(text: c is Map ? (c['ssn'] ?? '') : ''),
        ]);
      }
    } else if (children is num && children > 0) {
      for (var i = 0; i < children.toInt(); i++) {
        _eChildren.add([TextEditingController(), TextEditingController(), TextEditingController()]);
      }
    }

    setState(() => _editing = true);
  }

  void _cancelEdit() => setState(() => _editing = false);

  void _addChild() => setState(() {
    _eChildren.add([TextEditingController(), TextEditingController(), TextEditingController()]);
  });

  void _removeChild(int i) {
    for (final ctrl in _eChildren[i]) ctrl.dispose();
    setState(() => _eChildren.removeAt(i));
  }

  Tier _toTier3(String t) => switch (t) {
    'family' => Tier.family,
    'employeeOnly' => Tier.employeeOnly,
    _ => Tier.spouseChild,
  };

  Tier4 _toTier4(String t) => switch (t) {
    'spouse' => Tier4.spouse,
    'child' => Tier4.child,
    'family' || 'spouseChild' => Tier4.family,
    _ => Tier4.employeeOnly,
  };

  Future<void> _saveEdits() async {
    setState(() => _saving = true);
    try {
      final personal = (_data!['personal'] as Map?) ?? {};
      final dob = personal['dob'] as String? ?? '';
      final tobaccoUser = personal['tobaccoUser'] == true;

      final newDependents = <String, dynamic>{
        'spouse': _eHasSpouse
            ? {
                'firstName': _spFirst.text.trim(),
                'lastName': _spLast.text.trim(),
                'ssn': _spSsn.text.trim(),
              }
            : false,
        'children': _eChildren
            .map((c) => {
                  'firstName': c[0].text.trim(),
                  'lastName': c[1].text.trim(),
                  'ssn': c[2].text.trim(),
                })
            .toList(),
      };

      num medMonthly = 0;
      if (_group != null && _ePlan == 'preventiveCooperative' && _eLevel.isNotEmpty) {
        if (_group!.contributionMode == ContributionMode.employeeFacing) {
          medMonthly = medicalMonthly(_group!, _eLevel, _toTier3(_eTier));
        } else {
          final age = ageFromDob(dob) ?? 30;
          medMonthly = definedContributionDeduction(_group!, age, _toTier4(_eTier), _eLevel);
        }
      }
      if (tobaccoUser && _group?.tobaccoSurchargePayer == TobaccoSurchargePayer.employee) {
        medMonthly += (_group?.tobaccoSurcharge ?? 0);
      }

      num dentMonthly = 0;
      if (_eDental && _group != null) {
        dentMonthly = dentalMonthly(_group!, _toTier4(_eTier));
      }

      final updated = Map<String, dynamic>.from(_data!);
      updated['dependents'] = newDependents;
      updated['medical'] = {
        ...((updated['medical'] as Map?)?.cast<String, dynamic>() ?? {}),
        'tier': _eTier,
        'plan': _ePlan,
        if (_ePlan == 'preventiveCooperative') 'level': _eLevel,
        'monthly': medMonthly,
      };
      updated['dental'] = {
        ...((updated['dental'] as Map?)?.cast<String, dynamic>() ?? {}),
        'enrolled': _eDental,
        'monthly': dentMonthly,
      };
      updated['totals'] = {'monthly': medMonthly + dentMonthly};

      await EnrollmentService().patch(widget.groupId, widget.employee.id!, updated);

      setState(() { _data = updated; _editing = false; });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enrollment updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _downloadPdf(Map<String, dynamic> data) async {
    final group = _group ?? await GroupService().getGroup(widget.groupId);
    final submitted = (data['submittedAt'] as Timestamp?)?.toDate();
    final submittedText =
        submitted != null ? DateFormat.yMMMd().add_jm().format(submitted) : '';
    final bytes = await buildEnrollmentPdf(
      groupName: group?.name ?? '',
      employee: widget.employee,
      data: data,
      submittedText: submittedText,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${widget.employee.fullName.isEmpty ? 'enrollment' : widget.employee.fullName} enrollment.pdf',
    );
  }

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

  String _yn(dynamic v) => (v == true) ? 'Yes' : 'No';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.employee.fullName.isEmpty ? 'Enrollment' : widget.employee.fullName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : _data == null
              ? const Center(
                  child: Text('No submitted enrollment for this employee yet.',
                      style: TextStyle(color: AppColors.muted)),
                )
              : _body(context, _data!),
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
                  Text(widget.employee.fullName,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_editing) ...[
                OutlinedButton(
                  onPressed: _saving ? null : _cancelEdit,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveEdits,
                  icon: _saving
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save changes'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: () => _startEdit(),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit enrollment'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _downloadPdf(data),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Download PDF'),
                ),
              ],
            ],
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
          child: _editing ? _editDependents() : _viewDependents(dependents),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Coverage',
          child: _editing ? _editCoverage(medical, dental, ichra) : _viewCoverage(medical, dental, ichra),
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

  // ── View: Dependents ────────────────────────────────────────────────────────

  Widget _viewDependents(Map dependents) {
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
      if (children.isEmpty) rows.add(_row('Children', 'None'));
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

  // ── Edit: Dependents ────────────────────────────────────────────────────────

  Widget _editDependents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spouse / partner', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  SizedBox(height: 2),
                  Text('Add a spouse or domestic partner', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            Switch(
              value: _eHasSpouse,
              activeThumbColor: AppColors.coral,
              onChanged: (v) => setState(() => _eHasSpouse = v),
            ),
          ],
        ),
        if (_eHasSpouse) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LabeledField(label: 'First name', child: TextFormField(controller: _spFirst, decoration: const InputDecoration(isDense: true)))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Last name', child: TextFormField(controller: _spLast, decoration: const InputDecoration(isDense: true)))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'SSN', child: TextFormField(controller: _spSsn, decoration: const InputDecoration(isDense: true, hintText: 'XXX-XX-XXXX')))),
          ]),
        ],
        const Divider(height: 28),
        Row(
          children: [
            const Text('Children', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addChild,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add child'),
              style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            ),
          ],
        ),
        if (_eChildren.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No children added.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        for (var i = 0; i < _eChildren.length; i++) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Child ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13)),
              const Spacer(),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.muted),
                onPressed: () => _removeChild(i),
              ),
            ],
          ),
          Row(children: [
            Expanded(child: LabeledField(label: 'First name', child: TextFormField(controller: _eChildren[i][0], decoration: const InputDecoration(isDense: true)))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Last name', child: TextFormField(controller: _eChildren[i][1], decoration: const InputDecoration(isDense: true)))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'SSN', child: TextFormField(controller: _eChildren[i][2], decoration: const InputDecoration(isDense: true, hintText: 'XXX-XX-XXXX')))),
          ]),
        ],
      ],
    );
  }

  // ── View: Coverage ──────────────────────────────────────────────────────────

  Widget _viewCoverage(Map medical, Map dental, Map ichra) {
    return Column(children: [
      _row('Coverage tier', _tierLabel(medical['tier'] as String?)),
      _row('Medical plan', _planLabel(medical['plan'] as String?)),
      if (medical['level'] != null)
        _row('Deductible level', coopLevelLabel('${medical['level']}')),
      _row('Medical cost', '${money((medical['monthly'] ?? 0) as num)}/mo'),
      if (((medical['tobaccoSurcharge'] ?? 0) as num) > 0)
        _row('Incl. tobacco surcharge',
            '${money((medical['tobaccoSurcharge'] ?? 0) as num)}/mo'),
      _row('Dental',
          (dental['enrolled'] == true) ? '${money((dental['monthly'] ?? 0) as num)}/mo' : 'Not enrolled'),
      _row('ICHRA interest', _yn(ichra['interested'])),
    ]);
  }

  // ── Edit: Coverage ──────────────────────────────────────────────────────────

  static const _tierOptions = [
    ('employeeOnly', 'Employee Only'),
    ('spouse', '+ Spouse'),
    ('child', '+ Child(ren)'),
    ('family', '+ Family'),
  ];

  Widget _editCoverage(Map medical, Map dental, Map ichra) {
    final offeredLevels = _group?.offeredLevels ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          label: 'Coverage tier',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tierOptions.map(((String key, String label) opt) {
              final sel = _eTier == opt.$1;
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => setState(() => _eTier = opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.coral : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: sel ? AppColors.coral : const Color(0xFFCBD4DE), width: 1.5),
                  ),
                  child: Text(opt.$2,
                      style: TextStyle(
                          color: sel ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Medical plan',
          child: Wrap(
            spacing: 8,
            children: [
              ('preventiveOnly', 'Preventive Only'),
              ('preventiveCooperative', 'Preventive + Cooperative'),
            ].map(((String key, String label) opt) {
              final sel = _ePlan == opt.$1;
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => setState(() => _ePlan = opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.coral : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: sel ? AppColors.coral : const Color(0xFFCBD4DE), width: 1.5),
                  ),
                  child: Text(opt.$2,
                      style: TextStyle(
                          color: sel ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                ),
              );
            }).toList(),
          ),
        ),
        if (_ePlan == 'preventiveCooperative' && offeredLevels.isNotEmpty) ...[
          const SizedBox(height: 16),
          LabeledField(
            label: 'Deductible level',
            child: Wrap(
              spacing: 8,
              children: offeredLevels.map((level) {
                final sel = _eLevel == level;
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => _eLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.coral : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: sel ? AppColors.coral : const Color(0xFFCBD4DE), width: 1.5),
                    ),
                    child: Text(coopLevelLabel(level),
                        style: TextStyle(
                            color: sel ? Colors.white : AppColors.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (_group?.dental.enabled == true) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dental', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    SizedBox(height: 2),
                    Text('Enroll in dental coverage', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Switch(
                value: _eDental,
                activeThumbColor: AppColors.coral,
                onChanged: (v) => setState(() => _eDental = v),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        _row('ICHRA interest', _yn(ichra['interested'])),
      ],
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

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
