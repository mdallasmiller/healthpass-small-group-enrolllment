import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/employee.dart';
import '../models/group.dart';
import '../services/enrollment_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../utils/pricing.dart';
import '../utils/web_video.dart';
import '../widgets/ui.dart';
import 'enroll_entry_screen.dart';

/// The employee enrollment portal: personal info, health coverage (medical +
/// ICHRA), optional dental, and a review summary, all with a live monthly cost.
/// Acknowledgements + signing are M7.
class EnrollPortal extends StatefulWidget {
  final Group group;
  final Employee employee;

  /// True when launched from the admin app ("Enroll now"); shows an exit button.
  final bool adminMode;
  const EnrollPortal({
    super.key,
    required this.group,
    required this.employee,
    this.adminMode = false,
  });

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
  // address (separate fields per client request)
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  String _sex = '';
  bool _tobacco = false;

  // medical
  bool _hasSpouse = false;
  bool _spouseTobacco = false;
  int _children = 0;
  MedicalPlan _plan = MedicalPlan.preventiveCooperative;

  // dependent details
  final _spFirst = TextEditingController();
  final _spMiddle = TextEditingController();
  final _spLast = TextEditingController();
  final _spSsn = TextEditingController();
  final _spPhone = TextEditingController();
  final _spEmail = TextEditingController();
  final List<_ChildCtrls> _childCtrls = [];

  void _setChildren(int n) {
    setState(() {
      _children = n.clamp(0, 12);
      while (_childCtrls.length < _children) {
        _childCtrls.add(_ChildCtrls());
      }
      while (_childCtrls.length > _children) {
        _childCtrls.removeLast().dispose();
      }
    });
  }
  String _level = '2500';
  bool _ichraInterested = false;

  // dental
  bool _dentalEnrolled = false;
  bool _dentalSpouse = false;
  int _dentalChildren = 0;

  Group get _g => widget.group;

  List<String> get _steps => [
        'Demographics',
        'Coverage',
        if (_g.dental.enabled) 'Dental',
        'Review',
      ];

  Tier get _tier => determineTier(_hasSpouse, _children); // employee-facing 3-tier
  Tier4 get _tier4 => determineTier4(_hasSpouse, _children);
  int? get _age => ageFromDob(_dob.text);

  /// Monthly medical figure for a given deductible level, honoring the group's
  /// contribution mode (employee-facing price vs defined-contribution deduction).
  num medicalForLevel(String level) {
    if (_g.contributionMode == ContributionMode.definedContribution) {
      final a = _age;
      return a == null ? 0 : definedContributionDeduction(_g, a, _tier4, level);
    }
    return medicalMonthly(_g, level, _tier);
  }

  num get _medicalBase =>
      _plan == MedicalPlan.preventiveOnly ? 0 : medicalForLevel(_level);

  /// Number of $surcharge units: employee (if tobacco) + spouse (if added and
  /// tobacco). Only under a Cooperative plan.
  int get _tobaccoUnits {
    if (_plan != MedicalPlan.preventiveCooperative) return 0;
    var n = _tobacco ? 1 : 0;
    if (_hasSpouse && _spouseTobacco) n += 1;
    return n;
  }

  num get _tobaccoSurchargeTotal => _tobaccoUnits * _g.tobaccoSurcharge;

  /// The portion the EMPLOYEE actually pays (added to their deduction). When the
  /// company pays, it's $0 to the employee but still recorded for the report.
  num get _tobaccoSurchargeApplied =>
      _g.tobaccoSurchargePayer == TobaccoSurchargePayer.employee
          ? _tobaccoSurchargeTotal
          : 0;
  num get _medical => _medicalBase + _tobaccoSurchargeApplied;

  Tier4 get _dentalTier4 => determineTier4(_dentalSpouse, _dentalChildren);
  num get _dental => _dentalEnrolled ? dentalMonthly(_g, _dentalTier4) : 0;

  num get _total => _medical + _dental;

  /// First offered deductible level (falls back to all levels).
  List<String> get _levels =>
      _g.offeredLevels.isEmpty ? kCoopLevels : _g.offeredLevels;

  String _joinedAddress() {
    final cityLine = [_city.text.trim(), _state.text.trim(), _zip.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(', ');
    return [_addr1.text.trim(), _addr2.text.trim(), cityLine]
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  @override
  void initState() {
    super.initState();
    if (!_levels.contains(_level)) _level = _levels.first;
    // Auto-load demographics imported from the census.
    final e = widget.employee;
    if (e.middleName.isNotEmpty) _middle.text = e.middleName;
    if (e.dob.isNotEmpty) _dob.text = e.dob;
    if (e.ssn.isNotEmpty) _ssn.text = e.ssn;
    if (e.addressLine1.isNotEmpty) _addr1.text = e.addressLine1;
    if (e.addressLine2.isNotEmpty) _addr2.text = e.addressLine2;
    if (e.city.isNotEmpty) _city.text = e.city;
    if (e.state.isNotEmpty) _state.text = e.state;
    if (e.zip.isNotEmpty) _zip.text = e.zip;
    final g = e.gender.toLowerCase();
    if (g.startsWith('m')) {
      _sex = 'Male';
    } else if (g.startsWith('f')) {
      _sex = 'Female';
    }
    if (e.tobacco.toLowerCase() == 'yes') _tobacco = true;
  }

  @override
  void dispose() {
    for (final c in [
      _first, _middle, _last, _dob, _ssn,
      _addr1, _addr2, _city, _state, _zip,
      _spFirst, _spMiddle, _spLast, _spSsn, _spPhone, _spEmail,
    ]) {
      c.dispose();
    }
    for (final c in _childCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    final step = _steps[_step];
    if (step == 'Demographics' && !(_personalKey.currentState?.validate() ?? true)) {
      return;
    }
    if (_step < _steps.length - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit(
    Uint8List? signature,
    Map<String, bool> acks,
    Map<String, dynamic> audit,
  ) async {
    final data = <String, dynamic>{
      'personal': {
        'firstName': _first.text.trim(),
        'middleName': _middle.text.trim(),
        'lastName': _last.text.trim(),
        'dob': _dob.text.trim(),
        'ssn': _ssn.text.trim(),
        'sex': _sex,
        'addressLine1': _addr1.text.trim(),
        'addressLine2': _addr2.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'zip': _zip.text.trim(),
        'address': _joinedAddress(),
        'tobaccoUser': _tobacco,
      },
      'dependents': {
        'spouse': _hasSpouse
            ? {
                'firstName': _spFirst.text.trim(),
                'middleName': _spMiddle.text.trim(),
                'lastName': _spLast.text.trim(),
                'ssn': _spSsn.text.trim(),
                'phone': _spPhone.text.trim(),
                'email': _spEmail.text.trim(),
                'tobaccoUser': _spouseTobacco,
              }
            : null,
        'children': [
          for (final c in _childCtrls)
            {
              'firstName': c.first.text.trim(),
              'middleName': c.middle.text.trim(),
              'lastName': c.last.text.trim(),
              'ssn': c.ssn.text.trim(),
            }
        ],
      },
      'medical': {
        'plan': _plan.name,
        'level': _plan == MedicalPlan.preventiveCooperative ? _level : null,
        'tier': _tier4.name,
        'contributionMode': _g.contributionMode.name,
        'age': _age,
        'tobaccoSurcharge': _tobaccoSurchargeApplied,
        'monthly': _medical,
      },
      'tobaccoSurcharge': {
        'amountPer': _g.tobaccoSurcharge,
        'units': _tobaccoUnits,
        'total': _tobaccoSurchargeTotal,
        'payer': _g.tobaccoSurchargePayer.name,
        'employeePortion': _tobaccoSurchargeApplied,
        'employeeTobacco': _tobacco,
        'spouseTobacco': _hasSpouse && _spouseTobacco,
      },
      'dental': {
        'enrolled': _dentalEnrolled,
        'tier': _dentalTier4.name,
        'planName': _g.dental.enabled ? _g.dental.planName : '',
        'monthly': _dental,
      },
      'ichra': {'interested': _ichraInterested},
      'acknowledgements': acks,
      'audit': audit,
      'totals': {
        'monthly': _total,
        'perPayPeriod': perPayPeriod(_g, _total),
        'payFrequency': _g.payFrequency.name,
      },
      'signature': signature != null ? base64Encode(signature) : null,
    };
    await EnrollmentService().submit(_g.id!, widget.employee.id!, data);
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => EnrollComplete(
            group: _g, total: _total, adminMode: widget.adminMode),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnrollShell(
      maxWidth: 720,
      onClose: widget.adminMode ? () => Navigator.of(context).maybePop() : null,
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
      case 'Demographics':
        return _DemographicStep(
          formKey: _personalKey,
          first: _first,
          middle: _middle,
          last: _last,
          dob: _dob,
          ssn: _ssn,
          sex: _sex,
          onSex: (v) => setState(() => _sex = v),
          addr1: _addr1,
          addr2: _addr2,
          city: _city,
          state: _state,
          zip: _zip,
          tobacco: _tobacco,
          onTobacco: (v) => setState(() => _tobacco = v),
          hasSpouse: _hasSpouse,
          spouseTobacco: _spouseTobacco,
          children: _children,
          tier4: _tier4,
          onSpouse: (v) => setState(() => _hasSpouse = v),
          onSpouseTobacco: (v) => setState(() => _spouseTobacco = v),
          onChildren: _setChildren,
          spFirst: _spFirst,
          spMiddle: _spMiddle,
          spLast: _spLast,
          spSsn: _spSsn,
          spPhone: _spPhone,
          spEmail: _spEmail,
          childCtrls: _childCtrls,
        );
      case 'Coverage':
        return _CoverageStep(
          group: _g,
          levels: _levels,
          plan: _plan,
          level: _level,
          medicalForLevel: medicalForLevel,
          medical: _medical,
          tobaccoSurcharge: _tobaccoSurchargeApplied,
          ichraInterested: _ichraInterested,
          payFrequency: _g.payFrequency,
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
          tier: _dentalTier4,
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
          group: _g,
          tier: _tier4,
          dentalTier: _dentalTier4,
          plan: _plan,
          medical: _medical,
          tobaccoSurcharge: _tobaccoSurchargeApplied,
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

class _DemographicStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController first, middle, last, dob, ssn;
  final String sex;
  final ValueChanged<String> onSex;
  final TextEditingController addr1, addr2, city, state, zip;
  final bool tobacco;
  final ValueChanged<bool> onTobacco;
  final bool hasSpouse;
  final bool spouseTobacco;
  final int children;
  final Tier4 tier4;
  final ValueChanged<bool> onSpouse;
  final ValueChanged<bool> onSpouseTobacco;
  final ValueChanged<int> onChildren;
  final TextEditingController spFirst, spMiddle, spLast, spSsn, spPhone, spEmail;
  final List<_ChildCtrls> childCtrls;
  const _DemographicStep({
    required this.formKey,
    required this.first,
    required this.middle,
    required this.last,
    required this.dob,
    required this.ssn,
    required this.sex,
    required this.onSex,
    required this.addr1,
    required this.addr2,
    required this.city,
    required this.state,
    required this.zip,
    required this.tobacco,
    required this.onTobacco,
    required this.hasSpouse,
    required this.spouseTobacco,
    required this.children,
    required this.tier4,
    required this.onSpouse,
    required this.onSpouseTobacco,
    required this.onChildren,
    required this.spFirst,
    required this.spMiddle,
    required this.spLast,
    required this.spSsn,
    required this.spPhone,
    required this.spEmail,
    required this.childCtrls,
  });

  static String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demographic information', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Tell us about you and anyone you want to cover.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6F1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCDE7D8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, size: 18, color: Color(0xFF0A7D4F)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your information is private and secure. It is encrypted in transit '
                    '(TLS) and only visible to your benefits administrator.',
                    style: TextStyle(color: Color(0xFF0A5538), fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _MiniLabel('EMPLOYEE'),
          const SizedBox(height: 10),
          _nameRow(first, middle, last, required: true),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Date of birth',
                  child: TextFormField(
                    controller: dob,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_DobFormatter()],
                    decoration: const InputDecoration(hintText: 'MM/DD/YYYY'),
                    validator: _dobValidator,
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
                    decoration: const InputDecoration(
                      hintText: '###-##-####',
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                    validator: _ssnValidator,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Sex',
            child: Row(
              children: [
                for (final s in const ['Male', 'Female']) ...[
                  Expanded(
                    child: _SexChip(
                      label: s,
                      selected: sex == s,
                      onTap: () => onSex(s),
                    ),
                  ),
                  if (s == 'Male') const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Address',
            child: TextFormField(
              controller: addr1,
              decoration: const InputDecoration(hintText: '123 Main St'),
              validator: _req,
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Line two (optional)',
            child: TextFormField(
              controller: addr2,
              decoration: const InputDecoration(hintText: 'Apt, suite, unit'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: LabeledField(
                  label: 'City',
                  child: TextFormField(controller: city, validator: _req),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: LabeledField(
                  label: 'State',
                  child: TextFormField(controller: state, validator: _req),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: LabeledField(
                  label: 'Zip code',
                  child: TextFormField(
                    controller: zip,
                    keyboardType: TextInputType.number,
                    inputFormatters: [digitsOnly],
                    validator: _req,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SwitchTile(
            title: 'Do you use tobacco?',
            subtitle: 'Have you used tobacco products (including vapes, chew, and '
                'smoked marijuana) more than 10 times in the last 12 months?',
            value: tobacco,
            onChanged: onTobacco,
          ),
          const Divider(height: 36),
          const _MiniLabel('DEPENDENTS'),
          const SizedBox(height: 12),
          _DependentsControl(
            hasSpouse: hasSpouse,
            children: children,
            tier: tier4,
            onSpouse: onSpouse,
            onChildren: onChildren,
          ),
          if (hasSpouse) ...[
            const SizedBox(height: 18),
            const _MiniLabel('SPOUSE / PARTNER'),
            const SizedBox(height: 10),
            _spouseFields(),
            const SizedBox(height: 14),
            _SwitchTile(
              title: 'Spouse is a tobacco user',
              subtitle: 'Has your spouse used tobacco in the last 12 months?',
              value: spouseTobacco,
              onChanged: onSpouseTobacco,
            ),
          ],
          for (var i = 0; i < childCtrls.length; i++) ...[
            const SizedBox(height: 18),
            _MiniLabel('CHILD ${i + 1}'),
            const SizedBox(height: 10),
            _childFields(childCtrls[i]),
          ],
        ],
      ),
    );
  }

  Widget _nameRow(TextEditingController f, TextEditingController m, TextEditingController l,
      {bool required = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: LabeledField(
                label: 'First name',
                child: TextFormField(controller: f, validator: required ? _req : null))),
        const SizedBox(width: 10),
        Expanded(
            child: LabeledField(
                label: 'Middle', child: TextFormField(controller: m))),
        const SizedBox(width: 10),
        Expanded(
            child: LabeledField(
                label: 'Last name',
                child: TextFormField(controller: l, validator: required ? _req : null))),
      ],
    );
  }

  Widget _ssnField(TextEditingController c) => TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [_SsnFormatter()],
        decoration: const InputDecoration(hintText: '###-##-####'),
        validator: _ssnValidator,
      );

  Widget _spouseFields() {
    return Column(
      children: [
        _nameRow(spFirst, spMiddle, spLast, required: true),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: LabeledField(label: 'SSN', child: _ssnField(spSsn))),
            const SizedBox(width: 10),
            Expanded(
                child: LabeledField(
                    label: 'Phone',
                    child: TextFormField(
                        controller: spPhone, keyboardType: TextInputType.phone))),
            const SizedBox(width: 10),
            Expanded(
                child: LabeledField(
                    label: 'Email',
                    child: TextFormField(
                        controller: spEmail,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty || v.contains('@'))
                            ? null
                            : 'Enter a valid email'))),
          ],
        ),
      ],
    );
  }

  Widget _childFields(_ChildCtrls c) {
    return Column(
      children: [
        _nameRow(c.first, c.middle, c.last, required: true),
        const SizedBox(height: 12),
        LabeledField(label: 'SSN', child: _ssnField(c.ssn)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _CoverageStep extends StatelessWidget {
  final Group group;
  final List<String> levels;
  final MedicalPlan plan;
  final String level;
  final num Function(String level) medicalForLevel;
  final num medical;
  final num tobaccoSurcharge;
  final bool ichraInterested;
  final PayFrequency payFrequency;
  final ValueChanged<MedicalPlan> onPlan;
  final ValueChanged<String> onLevel;
  final ValueChanged<bool> onIchra;

  const _CoverageStep({
    required this.group,
    required this.levels,
    required this.plan,
    required this.level,
    required this.medicalForLevel,
    required this.medical,
    required this.tobaccoSurcharge,
    required this.ichraInterested,
    required this.payFrequency,
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
        const Text('Choose the plan that fits you.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 22),
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
        _PlanActions(
          description: group.details.preventiveDescription,
          videoUrl: group.details.preventiveVideoUrl,
        ),
        const SizedBox(height: 14),
        _PlanCard(
          selected: plan == MedicalPlan.preventiveCooperative,
          title: 'Preventive + Cooperative Bundle',
          desc: 'Adds Healthcare Co-op coverage. Choose your deductible level below.',
          trailing: money(medicalForLevel(level)),
          onTap: () => onPlan(MedicalPlan.preventiveCooperative),
        ),
        _PlanActions(
          description: group.details.healthDescription,
          videoUrl: group.details.healthVideoUrl,
        ),
        if (plan == MedicalPlan.preventiveCooperative) ...[
          const SizedBox(height: 18),
          const _MiniLabel('DEDUCTIBLE LEVEL'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final l in levels) ...[
                Expanded(
                  child: _LevelChip(
                    label: coopLevelLabel(l),
                    price: money(medicalForLevel(l)),
                    selected: l == level,
                    onTap: () => onLevel(l),
                  ),
                ),
                if (l != levels.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
        if (group.ichraEnabled) ...[
          const SizedBox(height: 26),
          _IchraSection(
            interested: ichraInterested,
            videoUrl: group.details.ichraVideoUrl,
            description: group.details.ichraDescription,
            eoTarget: group.details.ichraEoTarget,
            spouseTarget: group.details.ichraSpouseTarget,
            childTarget: group.details.ichraChildTarget,
            onChanged: onIchra,
          ),
        ],
        if (tobaccoSurcharge > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Includes a ${money(tobaccoSurcharge)}/mo tobacco surcharge.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _CostSummary(
          label: 'DEDUCTION PER PAY PERIOD',
          amount: medical,
          payFrequency: payFrequency,
        ),
      ],
    );
  }
}

/// Controllers for one child dependent.
class _ChildCtrls {
  final first = TextEditingController();
  final middle = TextEditingController();
  final last = TextEditingController();
  final ssn = TextEditingController();
  void dispose() {
    first.dispose();
    middle.dispose();
    last.dispose();
    ssn.dispose();
  }
}

class _IchraSection extends StatelessWidget {
  final bool interested;
  final String videoUrl;
  final String description;
  final num eoTarget, spouseTarget, childTarget;
  final ValueChanged<bool> onChanged;
  const _IchraSection({
    required this.interested,
    required this.videoUrl,
    required this.description,
    required this.eoTarget,
    required this.spouseTarget,
    required this.childTarget,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasTargets = eoTarget > 0 || spouseTarget > 0 || childTarget > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MiniLabel('ICHRA (INDIVIDUAL COVERAGE HRA)'),
        const SizedBox(height: 10),
        _PlanActions(description: description, videoUrl: videoUrl),
        const SizedBox(height: 12),
        if (hasTargets) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ESTIMATED COST',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _ichraRow('Employee', eoTarget),
                _ichraRow('Spouse', spouseTarget),
                _ichraRow('Child', childTarget),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
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

  Widget _ichraRow(String label, num amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
            Text('${money(amount)}/mo',
                style: const TextStyle(
                    color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------

class _DentalStep extends StatelessWidget {
  final Group group;
  final bool enrolled;
  final bool spouse;
  final int children;
  final Tier4 tier;
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
        const SizedBox(height: 14),
        _PlanActions(
          description: group.details.dentalDescription,
          videoUrl: group.details.dentalVideoUrl,
        ),
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
          label: 'DEDUCTION PER PAY PERIOD',
          amount: total,
          subtitle: 'Medical + dental',
          payFrequency: group.payFrequency,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

const _ackTobacco = 'I certify that the tobacco-use information I provided is accurate.';
const _ackPreEx = 'I understand that pre-existing condition terms may apply to my coverage.';
const _ackDeduction = 'I authorize payroll deduction of my share of the monthly premium.';
const _esignConsentText =
    'I agree that my electronic signature below is the legal equivalent of my handwritten '
    'signature, and I consent to transact electronically.';
const _enrollmentDocVersion = 'enrollment-v1';

class _ReviewSignStep extends StatefulWidget {
  final Group group;
  final Tier4 tier;
  final Tier4 dentalTier;
  final MedicalPlan plan;
  final num medical;
  final num tobaccoSurcharge;
  final bool dentalEnrolled;
  final num dental;
  final bool ichraInterested;
  final num total;
  final Future<void> Function(
    Uint8List? signature,
    Map<String, bool> acks,
    Map<String, dynamic> audit,
  ) onSubmit;
  const _ReviewSignStep({
    required this.group,
    required this.tier,
    required this.dentalTier,
    required this.plan,
    required this.medical,
    required this.tobaccoSurcharge,
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
  bool _esign = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _sig.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_tobacco || !_preEx || !_deduction || !_esign) {
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
      await widget.onSubmit(
        bytes,
        {'tobacco': _tobacco, 'preEx': _preEx, 'deduction': _deduction},
        {
          'documentVersion': _enrollmentDocVersion,
          'consentToEsign': true,
          'esignConsentText': _esignConsentText,
          'acknowledgementTexts': {
            'tobacco': _ackTobacco,
            'preEx': _ackPreEx,
            'deduction': _ackDeduction,
          },
        },
      );
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
              _row(
                  'Medical Plan',
                  widget.plan == MedicalPlan.preventiveOnly
                      ? 'Preventive'
                      : 'Preventive + Cooperative Bundle'),
              _row('Medical Tier', widget.tier.label),
              if (widget.group.dental.enabled && widget.dentalEnrolled) ...[
                _row('Dental Plan', widget.group.dental.planName),
                _row('Dental Tier', widget.dentalTier.label),
              ] else if (widget.group.dental.enabled)
                _row('Dental Plan', 'Not enrolled'),
              _row('Tobacco Surcharge',
                  widget.tobaccoSurcharge > 0 ? '${money(widget.tobaccoSurcharge)}/mo' : '-'),
              if (widget.ichraInterested) _row('ICHRA', 'Specialist will contact you'),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text('Monthly payroll deduction',
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
              if (widget.group.payFrequency != PayFrequency.monthly) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          'Per pay period (${widget.group.payFrequency.label})',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                    Text(
                      '${money(widget.group.payFrequency.fromMonthly(widget.total))} ${widget.group.payFrequency.short}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _MiniLabel('ACKNOWLEDGEMENTS'),
        const SizedBox(height: 8),
        _AckTile(
          value: _tobacco,
          text: _ackTobacco,
          onChanged: (v) => setState(() => _tobacco = v),
        ),
        _AckTile(
          value: _preEx,
          text: _ackPreEx,
          onChanged: (v) => setState(() => _preEx = v),
        ),
        _AckTile(
          value: _deduction,
          text: _ackDeduction,
          onChanged: (v) => setState(() => _deduction = v),
        ),
        _AckTile(
          value: _esign,
          text: _esignConsentText,
          onChanged: (v) => setState(() => _esign = v),
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
  final bool adminMode;
  const EnrollComplete({
    super.key,
    required this.group,
    required this.total,
    this.adminMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EnrollShell(
      maxWidth: 480,
      onClose: adminMode ? () => Navigator.of(context).maybePop() : null,
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
          if (adminMode)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to roster'),
              ),
            )
          else
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
  final Tier4 tier;
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
  final PayFrequency? payFrequency;
  const _CostSummary({
    required this.label,
    required this.amount,
    this.subtitle,
    this.payFrequency,
  });

  @override
  Widget build(BuildContext context) {
    final freq = payFrequency;
    final perPay = freq != null && freq != PayFrequency.monthly;
    // When a pay frequency is set, lead with the per-pay-period amount.
    final primary = perPay ? freq.fromMonthly(amount) : amount;
    final primarySuffix = perPay ? freq.short : '/mo';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
              Text(money(primary),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(primarySuffix,
                    style: const TextStyle(
                        color: Color(0xFF9DB2CC), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (perPay) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF9DB2CC)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${money(amount)} / month',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Text(freq.label,
                      style: const TextStyle(color: Color(0xFF9DB2CC), fontSize: 11.5)),
                ],
              ),
            ),
          ],
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

class _SexChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SexChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.coralSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.coral : const Color(0xFFCBD4DE),
              width: selected ? 2 : 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.navy : AppColors.muted)),
      ),
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

/// Validates a US SSN: 9 digits, excluding known-invalid area/group/serial.
String? _ssnValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  final digits = v.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 9) return 'Enter a 9-digit SSN';
  final area = int.parse(digits.substring(0, 3));
  final group = digits.substring(3, 5);
  final serial = digits.substring(5);
  if (area == 0 || area == 666 || area >= 900) return 'Invalid SSN';
  if (group == '00' || serial == '0000') return 'Invalid SSN';
  return null;
}

/// Validates a MM/DD/YYYY date of birth: real calendar date, not future,
/// age within a sane band.
String? _dobValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(v.trim());
  if (m == null) return 'Use MM/DD/YYYY';
  final mon = int.parse(m.group(1)!);
  final day = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  if (mon < 1 || mon > 12) return 'Invalid month';
  final date = DateTime(year, mon, day);
  if (date.year != year || date.month != mon || date.day != day) {
    return 'Invalid date';
  }
  final now = DateTime.now();
  if (date.isAfter(now)) return 'Date is in the future';
  var age = now.year - year;
  if (now.month < mon || (now.month == mon && now.day < day)) age--;
  if (age > 120) return 'Check the year';
  return null;
}

/// Renders an admin-authored product description (Markdown). Empty -> nothing.
/// "Read More" (description popup) + "Watch Video" (video popup) for a product
/// section. Buttons with no content are hidden.
class _PlanActions extends StatelessWidget {
  final String description;
  final String videoUrl;
  const _PlanActions({required this.description, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final hasDesc = description.trim().isNotEmpty;
    final hasVideo = videoUrl.trim().isNotEmpty;
    if (!hasDesc && !hasVideo) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (hasDesc)
            OutlinedButton.icon(
              onPressed: () => _showReadMore(context),
              icon: const Icon(Icons.article_outlined, size: 16),
              label: const Text('Read More'),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          if (hasVideo)
            FilledButton.icon(
              onPressed: () => _showVideo(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Watch Video'),
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
        ],
      ),
    );
  }

  void _showReadMore(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: MarkdownBody(
                    data: description,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: AppColors.ink, fontSize: 14, height: 1.55),
                      h1: const TextStyle(
                          color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w800),
                      h2: const TextStyle(
                          color: AppColors.navy, fontSize: 17, fontWeight: FontWeight.w800),
                      h3: const TextStyle(
                          color: AppColors.navy, fontSize: 15, fontWeight: FontWeight.w700),
                      a: const TextStyle(
                          color: AppColors.coralStrong, fontWeight: FontWeight.w600),
                    ),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              AspectRatio(aspectRatio: 16 / 9, child: webVideo(videoUrl)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DobFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
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
