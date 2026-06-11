import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import '../models/employee.dart';
import '../models/group.dart';
import '../services/enrollment_service.dart';
import '../theme.dart';
import '../utils/pricing.dart';
import '../widgets/ui.dart';
import 'enroll_entry_screen.dart';

/// The employee enrollment portal: personal info, health coverage (medical +
/// ICHRA), optional dental, and a review summary, all with a live monthly cost.
/// Acknowledgements + signing are M7.
class EnrollPortal extends StatefulWidget {
  final Group group;
  final Employee employee;
  const EnrollPortal({super.key, required this.group, required this.employee});

  @override
  State<EnrollPortal> createState() => _EnrollPortalState();
}

enum MedicalPlan { preventiveOnly, preventiveCooperative }

class _EnrollPortalState extends State<EnrollPortal> {
  int _step = 0;
  final _personalKey = GlobalKey<FormState>();

  late final TextEditingController _first =
      TextEditingController(text: widget.employee.firstName);
  final _middle = TextEditingController();
  late final TextEditingController _last =
      TextEditingController(text: widget.employee.lastName);
  final _dob = TextEditingController();
  final _ssn = TextEditingController();
  final _address = TextEditingController();
  bool _tobacco = false;

  // medical
  bool _hasSpouse = false;
  int _children = 0;
  MedicalPlan _plan = MedicalPlan.preventiveCooperative;
  String _level = '2500';
  bool _ichraInterested = false;

  // dental
  bool _dentalEnrolled = false;
  bool _dentalSpouse = false;
  int _dentalChildren = 0;

  Group get _g => widget.group;

  List<String> get _steps => [
        'Your details',
        'Coverage',
        if (_g.dental.enabled) 'Dental',
        'Review',
      ];

  Tier get _tier => determineTier(_hasSpouse, _children);
  num get _medical =>
      _plan == MedicalPlan.preventiveOnly ? 0 : medicalMonthly(_g, _level, _tier);

  Tier get _dentalTier => determineTier(_dentalSpouse, _dentalChildren);
  num get _dental => _dentalEnrolled ? dentalMonthly(_g, _dentalTier) : 0;

  num get _total => _medical + _dental;

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _dob, _ssn, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_steps[_step] == 'Your details' && !_personalKey.currentState!.validate()) {
      return;
    }
    if (_step < _steps.length - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit(Uint8List? signature, Map<String, bool> acks) async {
    final data = <String, dynamic>{
      'personal': {
        'firstName': _first.text.trim(),
        'middleName': _middle.text.trim(),
        'lastName': _last.text.trim(),
        'dob': _dob.text.trim(),
        'ssn': _ssn.text.trim(),
        'address': _address.text.trim(),
        'tobaccoUser': _tobacco,
      },
      'dependents': {'spouse': _hasSpouse, 'children': _children},
      'medical': {
        'plan': _plan.name,
        'level': _plan == MedicalPlan.preventiveCooperative ? _level : null,
        'tier': _tier.name,
        'monthly': _medical,
      },
      'dental': {
        'enrolled': _dentalEnrolled,
        'tier': _dentalTier.name,
        'monthly': _dental,
      },
      'ichra': {'interested': _ichraInterested},
      'acknowledgements': acks,
      'totals': {'monthly': _total},
      'signature': signature != null ? base64Encode(signature) : null,
    };
    await EnrollmentService().submit(_g.id!, widget.employee.id!, data);
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => EnrollComplete(group: _g, total: _total),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnrollShell(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepProgress(steps: _steps, current: _step),
          const SizedBox(height: 26),
          _stepBody(),
          const SizedBox(height: 26),
          _navRow(),
          const SizedBox(height: 22),
          const HelpFooter(),
        ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_steps[_step]) {
      case 'Your details':
        return _PersonalStep(
          formKey: _personalKey,
          first: _first,
          middle: _middle,
          last: _last,
          dob: _dob,
          ssn: _ssn,
          address: _address,
          tobacco: _tobacco,
          onTobacco: (v) => setState(() => _tobacco = v),
        );
      case 'Coverage':
        return _CoverageStep(
          group: _g,
          hasSpouse: _hasSpouse,
          children: _children,
          plan: _plan,
          level: _level,
          tier: _tier,
          medical: _medical,
          ichraInterested: _ichraInterested,
          onSpouse: (v) => setState(() => _hasSpouse = v),
          onChildren: (v) => setState(() => _children = v),
          onPlan: (p) => setState(() => _plan = p),
          onLevel: (l) => setState(() => _level = l),
          onIchra: (v) => setState(() => _ichraInterested = v),
        );
      case 'Dental':
        return _DentalStep(
          group: _g,
          enrolled: _dentalEnrolled,
          spouse: _dentalSpouse,
          children: _dentalChildren,
          tier: _dentalTier,
          dental: _dental,
          total: _total,
          onEnrolled: (v) => setState(() {
            _dentalEnrolled = v;
            if (v) {
              // sensible default: mirror medical dependents
              _dentalSpouse = _hasSpouse;
              _dentalChildren = _children;
            }
          }),
          onSpouse: (v) => setState(() => _dentalSpouse = v),
          onChildrenChanged: (v) => setState(() => _dentalChildren = v),
        );
      default:
        return _ReviewSignStep(
          tier: _tier,
          plan: _plan,
          medical: _medical,
          dentalEnrolled: _dentalEnrolled,
          dental: _dental,
          ichraInterested: _ichraInterested,
          total: _total,
          onSubmit: _submit,
        );
    }
  }

  Widget _navRow() {
    final isLast = _step == _steps.length - 1;
    return Row(
      children: [
        if (_step > 0)
          OutlinedButton(onPressed: _back, child: const Text('Back')),
        const Spacer(),
        if (!isLast)
          FilledButton(onPressed: _next, child: const Text('Continue')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _StepProgress extends StatelessWidget {
  final List<String> steps;
  final int current;
  const _StepProgress({required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _node(i),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i < current ? AppColors.coral : AppColors.line,
              ),
            ),
        ],
      ],
    );
  }

  Widget _node(int i) {
    final done = i < current;
    final active = i == current;
    final fill = done || active ? AppColors.coral : Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
                color: done || active ? AppColors.coral : AppColors.line, width: 1.5),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text('${i + 1}',
                  style: TextStyle(
                      color: active ? Colors.white : AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Text(steps[i],
            style: TextStyle(
                color: active ? AppColors.navy : AppColors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13.5)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _PersonalStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController first, middle, last, dob, ssn, address;
  final bool tobacco;
  final ValueChanged<bool> onTobacco;
  const _PersonalStep({
    required this.formKey,
    required this.first,
    required this.middle,
    required this.last,
    required this.dob,
    required this.ssn,
    required this.address,
    required this.tobacco,
    required this.onTobacco,
  });

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal information', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Tell us a bit about yourself.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'First name',
                  child: TextFormField(controller: first, validator: _req),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Middle (optional)',
                  child: TextFormField(controller: middle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Last name',
                  child: TextFormField(controller: last, validator: _req),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Date of birth',
                  child: TextFormField(
                    controller: dob,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_DobFormatter()],
                    decoration: const InputDecoration(hintText: 'dd.mm.yyyy'),
                    validator: (v) => (v == null || v.length < 10) ? 'dd.mm.yyyy' : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Social Security Number',
                  child: TextFormField(
                    controller: ssn,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_SsnFormatter()],
                    decoration: const InputDecoration(hintText: '###-##-####'),
                    validator: (v) => (v == null || v.length < 11) ? 'Enter a valid SSN' : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Home address',
            child: TextFormField(
              controller: address,
              decoration: const InputDecoration(hintText: '123 Main St, City, ST 00000'),
              validator: _req,
            ),
          ),
          const SizedBox(height: 18),
          _SwitchTile(
            title: 'Tobacco user',
            subtitle: 'Have you used tobacco in the last 12 months?',
            value: tobacco,
            onChanged: onTobacco,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CoverageStep extends StatelessWidget {
  final Group group;
  final bool hasSpouse;
  final int children;
  final MedicalPlan plan;
  final String level;
  final Tier tier;
  final num medical;
  final bool ichraInterested;
  final ValueChanged<bool> onSpouse;
  final ValueChanged<int> onChildren;
  final ValueChanged<MedicalPlan> onPlan;
  final ValueChanged<String> onLevel;
  final ValueChanged<bool> onIchra;

  const _CoverageStep({
    required this.group,
    required this.hasSpouse,
    required this.children,
    required this.plan,
    required this.level,
    required this.tier,
    required this.medical,
    required this.ichraInterested,
    required this.onSpouse,
    required this.onChildren,
    required this.onPlan,
    required this.onLevel,
    required this.onIchra,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Health coverage', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Add who is covered, then choose your plan.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 22),
        _DependentsControl(
          hasSpouse: hasSpouse,
          children: children,
          tier: tier,
          onSpouse: onSpouse,
          onChildren: onChildren,
        ),
        const SizedBox(height: 24),
        Text('Choose your plan',
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15)),
        const SizedBox(height: 12),
        _PlanCard(
          selected: plan == MedicalPlan.preventiveOnly,
          title: 'Preventive Only',
          desc: 'Employee Assistance Program and preventive care, at no cost to you.',
          trailing: money(0),
          onTap: () => onPlan(MedicalPlan.preventiveOnly),
        ),
        const SizedBox(height: 10),
        _PlanCard(
          selected: plan == MedicalPlan.preventiveCooperative,
          title: 'Preventive + Cooperative',
          desc: 'Adds Healthcare Co-op coverage. Choose your deductible level below.',
          trailing: money(medicalMonthly(group, level, tier)),
          onTap: () => onPlan(MedicalPlan.preventiveCooperative),
        ),
        if (plan == MedicalPlan.preventiveCooperative) ...[
          const SizedBox(height: 18),
          const _MiniLabel('DEDUCTIBLE LEVEL'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final l in kCoopLevels) ...[
                Expanded(
                  child: _LevelChip(
                    label: coopLevelLabel(l),
                    price: money(medicalMonthly(group, l, tier)),
                    selected: l == level,
                    onTap: () => onLevel(l),
                  ),
                ),
                if (l != kCoopLevels.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
        if (group.ichraEnabled) ...[
          const SizedBox(height: 26),
          _IchraSection(interested: ichraInterested, onChanged: onIchra),
        ],
        const SizedBox(height: 24),
        _CostSummary(label: 'ESTIMATED MEDICAL COST', amount: medical),
      ],
    );
  }
}

class _IchraSection extends StatelessWidget {
  final bool interested;
  final ValueChanged<bool> onChanged;
  const _IchraSection({required this.interested, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MiniLabel('ICHRA (INDIVIDUAL COVERAGE HRA)'),
        const SizedBox(height: 10),
        _PlanCard(
          selected: interested,
          title: 'I\'m interested in ICHRA',
          desc: 'Use your employer contribution toward an individual health plan. '
              'An enrollment specialist will help you choose one.',
          trailing: '',
          onTap: () => onChanged(!interested),
        ),
        if (interested) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.coralSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.coralLine),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.coralStrong),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'An enrollment specialist will contact you soon to enroll in an '
                    'individual health insurance plan.',
                    style: TextStyle(color: Color(0xFF8A3A33), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DentalStep extends StatelessWidget {
  final Group group;
  final bool enrolled;
  final bool spouse;
  final int children;
  final Tier tier;
  final num dental;
  final num total;
  final ValueChanged<bool> onEnrolled;
  final ValueChanged<bool> onSpouse;
  final ValueChanged<int> onChildrenChanged;

  const _DentalStep({
    required this.group,
    required this.enrolled,
    required this.spouse,
    required this.children,
    required this.tier,
    required this.dental,
    required this.total,
    required this.onEnrolled,
    required this.onSpouse,
    required this.onChildrenChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dental coverage', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Optional dental for you and your family (${group.dental.option.label}).',
            style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 22),
        _SwitchTile(
          title: 'Add dental coverage',
          subtitle: enrolled
              ? '${money(dentalMonthly(group, tier))} per month'
              : 'Turned off',
          value: enrolled,
          onChanged: onEnrolled,
        ),
        if (enrolled) ...[
          const SizedBox(height: 18),
          const _MiniLabel('WHO IS COVERED'),
          const SizedBox(height: 12),
          _DependentsControl(
            hasSpouse: spouse,
            children: children,
            tier: tier,
            onSpouse: onSpouse,
            onChildren: onChildrenChanged,
          ),
        ],
        const SizedBox(height: 24),
        _CostSummary(
          label: 'ESTIMATED TOTAL COST',
          amount: total,
          subtitle: 'Medical + dental',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ReviewSignStep extends StatefulWidget {
  final Tier tier;
  final MedicalPlan plan;
  final num medical;
  final bool dentalEnrolled;
  final num dental;
  final bool ichraInterested;
  final num total;
  final Future<void> Function(Uint8List? signature, Map<String, bool> acks) onSubmit;
  const _ReviewSignStep({
    required this.tier,
    required this.plan,
    required this.medical,
    required this.dentalEnrolled,
    required this.dental,
    required this.ichraInterested,
    required this.total,
    required this.onSubmit,
  });

  @override
  State<_ReviewSignStep> createState() => _ReviewSignStepState();
}

class _ReviewSignStepState extends State<_ReviewSignStep> {
  final _sig = SignatureController(
    penStrokeWidth: 2.4,
    penColor: AppColors.navy,
    exportBackgroundColor: Colors.white,
  );
  bool _tobacco = false;
  bool _preEx = false;
  bool _deduction = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _sig.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_tobacco || !_preEx || !_deduction) {
      setState(() => _error = 'Please accept all acknowledgements to continue.');
      return;
    }
    if (_sig.isEmpty) {
      setState(() => _error = 'Please sign in the box.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _sig.toPngBytes();
      await widget.onSubmit(bytes, {
        'tobacco': _tobacco,
        'preEx': _preEx,
        'deduction': _deduction,
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not submit your enrollment. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & sign', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Confirm your selections, then sign to submit.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              _row('Coverage tier', widget.tier.label),
              _row(
                  'Medical plan',
                  widget.plan == MedicalPlan.preventiveOnly
                      ? 'Preventive Only'
                      : 'Preventive + Cooperative'),
              _row('Medical cost', '${money(widget.medical)}/mo'),
              _row('Dental',
                  widget.dentalEnrolled ? '${money(widget.dental)}/mo' : 'Not enrolled'),
              if (widget.ichraInterested) _row('ICHRA', 'Specialist will contact you'),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text('Total monthly cost',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 16)),
                  ),
                  Text('${money(widget.total)}/mo',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.coralStrong,
                          fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _MiniLabel('ACKNOWLEDGEMENTS'),
        const SizedBox(height: 8),
        _AckTile(
          value: _tobacco,
          text: 'I certify that the tobacco-use information I provided is accurate.',
          onChanged: (v) => setState(() => _tobacco = v),
        ),
        _AckTile(
          value: _preEx,
          text: 'I understand that pre-existing condition terms may apply to my coverage.',
          onChanged: (v) => setState(() => _preEx = v),
        ),
        _AckTile(
          value: _deduction,
          text: 'I authorize payroll deduction of my share of the monthly premium.',
          onChanged: (v) => setState(() => _deduction = v),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: _MiniLabel('SIGNATURE')),
            TextButton.icon(
              onPressed: () => setState(() => _sig.clear()),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD4DE), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Signature(controller: _sig, height: 150, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text('Sign with your mouse or finger.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.coralStrong),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.coralStrong, fontSize: 13.5)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Confirm & submit enrollment'),
          ),
        ),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted))),
            Text(v,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
          ],
        ),
      );
}

class _AckTile extends StatelessWidget {
  final bool value;
  final String text;
  final ValueChanged<bool> onChanged;
  const _AckTile({required this.value, required this.text, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: value ? AppColors.coral : AppColors.muted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(text,
                    style: const TextStyle(color: AppColors.ink, fontSize: 13.5, height: 1.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Success screen after a submitted enrollment.
class EnrollComplete extends StatelessWidget {
  final Group group;
  final num total;
  const EnrollComplete({super.key, required this.group, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EnrollShell(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6EE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF0A7D4F), size: 30),
          ),
          const SizedBox(height: 20),
          Text('Enrollment complete', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Thanks! Your benefits selections for ${group.name} have been submitted. '
            'Your estimated cost is ${money(total)}/mo.',
            style: const TextStyle(color: AppColors.muted, height: 1.55),
          ),
          const SizedBox(height: 18),
          const HelpFooter(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared controls

class _DependentsControl extends StatelessWidget {
  final bool hasSpouse;
  final int children;
  final Tier tier;
  final ValueChanged<bool> onSpouse;
  final ValueChanged<int> onChildren;
  const _DependentsControl({
    required this.hasSpouse,
    required this.children,
    required this.tier,
    required this.onSpouse,
    required this.onChildren,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SwitchTile(
          title: 'Cover my spouse / domestic partner',
          subtitle: 'Adds your spouse to coverage.',
          value: hasSpouse,
          onChanged: onSpouse,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text('Children (26 and under)',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            _Stepper(value: children, onChanged: onChildren),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 8),
              const Text('Your tier: ', style: TextStyle(color: AppColors.muted)),
              Text(tier.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CostSummary extends StatelessWidget {
  final String label;
  final num amount;
  final String? subtitle;
  const _CostSummary({required this.label, required this.amount, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF9DB2CC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(subtitle ?? 'Updates as you choose',
                    style: const TextStyle(color: Color(0xFF9DB2CC), fontSize: 12.5)),
              ],
            ),
          ),
          Text(money(amount),
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text('/mo',
                style: TextStyle(color: Color(0xFF9DB2CC), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final bool selected;
  final String title, desc, trailing;
  final VoidCallback onTap;
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.desc,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppColors.coralSoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.coral : const Color(0xFFCBD4DE),
              width: selected ? 2 : 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.coral : AppColors.muted, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.navy)),
                  const SizedBox(height: 3),
                  Text(desc,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(trailing,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy)),
                  const Text('per month',
                      style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label, price;
  final bool selected;
  final VoidCallback onTap;
  const _LevelChip({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.coral : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.coral : const Color(0xFFCBD4DE), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: selected ? Colors.white : AppColors.navy)),
            const SizedBox(height: 2),
            Text('$price/mo',
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white.withValues(alpha: 0.9) : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD4DE), width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, value > 0 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 34,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
          _btn(Icons.add_rounded, value < 12 ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: AppColors.navy,
        disabledColor: AppColors.line,
        visualDensity: VisualDensity.compact,
      );
}

class _SwitchTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
        Switch(value: value, activeThumbColor: AppColors.coral, onChanged: onChanged),
      ],
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String text;
  const _MiniLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8));
}

class _DobFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) buf.write('.');
      buf.write(d[i]);
    }
    final t = buf.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

class _SsnFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 9 ? digits.substring(0, 9) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 5) buf.write('-');
      buf.write(d[i]);
    }
    final t = buf.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
