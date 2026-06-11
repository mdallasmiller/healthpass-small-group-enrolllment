import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Short tier labels for the compact rates grid header.
const _tierShort = {
  Tier.employeeOnly: 'Employee Only',
  Tier.spouseChild: '+ Spouse/Child(ren)',
  Tier.family: '+ Family',
};

class GroupFormScreen extends StatefulWidget {
  final Group? group;
  const GroupFormScreen({super.key, this.group});

  bool get isEdit => group != null;

  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  final _service = GroupService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _ichra = false;

  // medical[level][tierKey] -> controller
  late final Map<String, Map<String, TextEditingController>> _medical;

  bool _dentalEnabled = false;
  DentalOption _dentalOption = DentalOption.cooperative;
  String _dentalLevel = '2500';
  late final Map<String, TextEditingController> _dental;

  GroupStatus _status = GroupStatus.draft;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _name = TextEditingController(text: g?.name ?? '');
    _email = TextEditingController(text: g?.contactEmail ?? '');
    _ichra = g?.ichraEnabled ?? false;
    _status = g?.status ?? GroupStatus.draft;

    _medical = {
      for (final level in kCoopLevels)
        level: {
          for (final t in Tier.values)
            t.key: TextEditingController(
                text: _fmt(g?.medicalRates[level]?.forTier(t) ?? 0)),
        }
    };

    final d = g?.dental ?? const DentalConfig();
    _dentalEnabled = d.enabled;
    _dentalOption = d.option;
    _dentalLevel = d.level;
    _dental = {
      for (final t in Tier.values)
        t.key: TextEditingController(text: _fmt(d.rates.forTier(t))),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    for (final m in _medical.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    for (final c in _dental.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(num v) =>
      v == 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  num _parse(String s) =>
      num.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  TierRates _ratesFrom(Map<String, TextEditingController> m) => TierRates(
        employeeOnly: _parse(m[Tier.employeeOnly.key]!.text),
        spouseChild: _parse(m[Tier.spouseChild.key]!.text),
        family: _parse(m[Tier.family.key]!.text),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final group = (widget.group ?? Group.empty()).copyWith(
        name: _name.text.trim(),
        contactEmail: _email.text.trim(),
        ichraEnabled: _ichra,
        status: _status,
        medicalRates: {
          for (final level in kCoopLevels) level: _ratesFrom(_medical[level]!)
        },
        dental: DentalConfig(
          enabled: _dentalEnabled,
          option: _dentalOption,
          level: _dentalOption == DentalOption.cooperative ? '2500' : _dentalLevel,
          rates: _ratesFrom(_dental),
        ),
      );

      if (widget.isEdit) {
        await _service.update(widget.group!.id!, group);
      } else {
        await _service.create(group);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isEdit ? 'Group updated' : 'Group created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('This permanently removes "${widget.group!.name}".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.delete(widget.group!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.isEdit ? 'Edit group' : 'New group'),
        actions: [
          if (widget.isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: CenteredColumn(
          maxWidth: 760,
          children: [
            _detailsCard(),
            const SizedBox(height: 16),
            _medicalCard(),
            const SizedBox(height: 16),
            _dentalCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(widget.isEdit ? 'Save changes' : 'Create group'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() {
    return SectionCard(
      title: 'Group details',
      subtitle: 'Employer information and plan options.',
      child: Column(
        children: [
          LabeledField(
            label: 'Group / employer name',
            child: TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Acme Corp'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Group name is required.' : null,
            ),
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'Contact email',
            hint: 'Used as the sender for enrollment invitations.',
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'hr@acme.com'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email.' : null,
            ),
          ),
          const SizedBox(height: 20),
          _SwitchRow(
            title: 'Offer ICHRA',
            subtitle: 'Shows the ICHRA option in the employee enrollment portal.',
            value: _ichra,
            onChanged: (v) => setState(() => _ichra = v),
          ),
          if (widget.isEdit) ...[
            const SizedBox(height: 20),
            LabeledField(
              label: 'Status',
              child: _StatusSelector(
                value: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _medicalCard() {
    return SectionCard(
      title: 'Contribution strategy — medical rates',
      subtitle: 'Employee-facing monthly rates per cooperative level and tier.',
      child: _RatesGrid(controllers: _medical, money: _money),
    );
  }

  Widget _dentalCard() {
    return SectionCard(
      title: 'Dental',
      subtitle: 'Optional dental coverage and rates.',
      trailing: Switch(
        value: _dentalEnabled,
        activeThumbColor: AppColors.coral,
        onChanged: (v) => setState(() => _dentalEnabled = v),
      ),
      child: !_dentalEnabled
          ? Text('Dental coverage is turned off for this group.',
              style: TextStyle(color: AppColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: 'Option',
                  child: _Segmented<DentalOption>(
                    values: DentalOption.values,
                    selected: _dentalOption,
                    labelOf: (o) => o.label,
                    onChanged: (o) => setState(() {
                      _dentalOption = o;
                      if (o == DentalOption.cooperative) _dentalLevel = '2500';
                    }),
                  ),
                ),
                if (_dentalOption == DentalOption.cooperative) ...[
                  const SizedBox(height: 10),
                  Text('Cooperative auto-fills level \$2.5K.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
                const SizedBox(height: 20),
                _TierRow(controllers: _dental, money: _money),
              ],
            ),
    );
  }

  Widget _money(TextEditingController c) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: const InputDecoration(
        prefixText: '\$ ',
        hintText: '0',
        isDense: true,
      ),
    );
  }
}

/// Medical rates grid: a row per cooperative level, a money field per tier.
class _RatesGrid extends StatelessWidget {
  final Map<String, Map<String, TextEditingController>> controllers;
  final Widget Function(TextEditingController) money;
  const _RatesGrid({required this.controllers, required this.money});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _headerRow(),
        const SizedBox(height: 8),
        for (final level in kCoopLevels) ...[
          _levelRow(level),
          if (level != kCoopLevels.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _headerRow() {
    Widget h(String t) => Expanded(
          child: Text(t,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        );
    return Row(
      children: [
        const SizedBox(width: 84),
        const SizedBox(width: 12),
        h('EMPLOYEE ONLY'),
        const SizedBox(width: 10),
        h('+ SPOUSE/CHILD'),
        const SizedBox(width: 10),
        h('+ FAMILY'),
      ],
    );
  }

  Widget _levelRow(String level) {
    final m = controllers[level]!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 84,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(coopLevelLabel(level),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: money(m[Tier.employeeOnly.key]!)),
        const SizedBox(width: 10),
        Expanded(child: money(m[Tier.spouseChild.key]!)),
        const SizedBox(width: 10),
        Expanded(child: money(m[Tier.family.key]!)),
      ],
    );
  }
}

/// One row of tier money fields (used for dental).
class _TierRow extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final Widget Function(TextEditingController) money;
  const _TierRow({required this.controllers, required this.money});

  @override
  Widget build(BuildContext context) {
    Widget field(Tier t) => Expanded(
          child: LabeledField(
            label: _tierShort[t]!,
            child: money(controllers[t.key]!),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field(Tier.employeeOnly),
        const SizedBox(width: 12),
        field(Tier.spouseChild),
        const SizedBox(width: 12),
        field(Tier.family),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
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

class _StatusSelector extends StatelessWidget {
  final GroupStatus value;
  final ValueChanged<GroupStatus> onChanged;
  const _StatusSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Segmented<GroupStatus>(
      values: GroupStatus.values,
      selected: value,
      labelOf: (s) => s.name[0].toUpperCase() + s.name.substring(1),
      onChanged: onChanged,
    );
  }
}

/// Generic segmented selector (coral fill on the selected item).
class _Segmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  const _Segmented({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSel = v == selected;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSel ? AppColors.coral : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSel ? AppColors.coral : AppColors.line, width: 1.5),
            ),
            child: Text(
              labelOf(v),
              style: TextStyle(
                color: isSel ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
