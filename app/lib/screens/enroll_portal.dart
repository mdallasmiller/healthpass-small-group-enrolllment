import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee.dart';
import '../models/group.dart';
import '../theme.dart';
import '../utils/pricing.dart';
import '../widgets/ui.dart';
import 'enroll_entry_screen.dart';

/// The employee enrollment portal (M5): personal info + health coverage with a
/// live monthly cost. Dental/ICHRA (M6) and review/sign (M7) follow.
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

  bool _hasSpouse = false;
  int _children = 0;

  MedicalPlan _plan = MedicalPlan.preventiveCooperative;
  String _level = '2500';

  List<String> get _steps => ['Your details', 'Coverage', 'Review'];

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _dob, _ssn, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Tier get _tier => determineTier(_hasSpouse, _children);

  num get _monthly => _plan == MedicalPlan.preventiveOnly
      ? 0
      : medicalMonthly(widget.group, _level, _tier);

  void _next() {
    if (_step == 0 && !_personalKey.currentState!.validate()) return;
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
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
    switch (_step) {
      case 0:
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
      case 1:
        return _CoverageStep(
          group: widget.group,
          hasSpouse: _hasSpouse,
          children: _children,
          plan: _plan,
          level: _level,
          tier: _tier,
          monthly: _monthly,
          onSpouse: (v) => setState(() => _hasSpouse = v),
          onChildren: (v) => setState(() => _children = v),
          onPlan: (p) => setState(() => _plan = p),
          onLevel: (l) => setState(() => _level = l),
        );
      default:
        return _ReviewStub(
          tier: _tier,
          monthly: _monthly,
          plan: _plan,
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
        if (isLast)
          FilledButton(
            onPressed: null,
            child: const Text('Submit (available soon)'),
          )
        else
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
                    validator: (v) =>
                        (v == null || v.length < 10) ? 'dd.mm.yyyy' : null,
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
                    validator: (v) =>
                        (v == null || v.length < 11) ? 'Enter a valid SSN' : null,
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
  final num monthly;
  final ValueChanged<bool> onSpouse;
  final ValueChanged<int> onChildren;
  final ValueChanged<MedicalPlan> onPlan;
  final ValueChanged<String> onLevel;

  const _CoverageStep({
    required this.group,
    required this.hasSpouse,
    required this.children,
    required this.plan,
    required this.level,
    required this.tier,
    required this.monthly,
    required this.onSpouse,
    required this.onChildren,
    required this.onPlan,
    required this.onLevel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coopFrom = medicalMonthly(group, level, tier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Health coverage', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Add who is covered, then choose your plan.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 22),
        // Dependents
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
        const SizedBox(height: 10),
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
              Text('Your tier: ', style: TextStyle(color: AppColors.muted)),
              Text(tier.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
            ],
          ),
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
          trailingNote: 'per month',
          onTap: () => onPlan(MedicalPlan.preventiveOnly),
        ),
        const SizedBox(height: 10),
        _PlanCard(
          selected: plan == MedicalPlan.preventiveCooperative,
          title: 'Preventive + Cooperative',
          desc: 'Adds Healthcare Co-op coverage. Choose your deductible level below.',
          trailing: money(coopFrom),
          trailingNote: 'per month',
          onTap: () => onPlan(MedicalPlan.preventiveCooperative),
        ),
        if (plan == MedicalPlan.preventiveCooperative) ...[
          const SizedBox(height: 18),
          const Text('DEDUCTIBLE LEVEL',
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
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
        const SizedBox(height: 24),
        _CostSummary(monthly: monthly),
      ],
    );
  }
}

class _CostSummary extends StatelessWidget {
  final num monthly;
  const _CostSummary({required this.monthly});

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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR ESTIMATED COST',
                    style: TextStyle(
                        color: Color(0xFF9DB2CC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                SizedBox(height: 4),
                Text('Updates as you choose',
                    style: TextStyle(color: Color(0xFF9DB2CC), fontSize: 12.5)),
              ],
            ),
          ),
          Text(money(monthly),
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

class _ReviewStub extends StatelessWidget {
  final Tier tier;
  final num monthly;
  final MedicalPlan plan;
  const _ReviewStub({required this.tier, required this.monthly, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & sign', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('A quick summary of your selections.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 20),
        _row('Coverage tier', tier.label),
        _row('Plan',
            plan == MedicalPlan.preventiveOnly ? 'Preventive Only' : 'Preventive + Cooperative'),
        _row('Estimated monthly cost', '${money(monthly)}/mo'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.coralSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.coralLine),
          ),
          child: const Text(
            'Acknowledgements and e-signature are the next milestone (M7).',
            style: TextStyle(color: Color(0xFF8A3A33), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted))),
            Text(v,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Small shared controls

class _PlanCard extends StatelessWidget {
  final bool selected;
  final String title, desc, trailing, trailingNote;
  final VoidCallback onTap;
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.desc,
    required this.trailing,
    required this.trailingNote,
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(trailing,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.navy)),
                Text(trailingNote,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
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
