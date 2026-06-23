import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// HR Manager form for editing group details (company info, eligibility, etc).
/// Opened via `?hr=<groupId>` link. Excludes contribution strategy/rates.
class HrFormScreen extends StatefulWidget {
  final String groupId;
  const HrFormScreen({super.key, required this.groupId});

  @override
  State<HrFormScreen> createState() => _HrFormScreenState();
}

class _HrFormScreenState extends State<HrFormScreen> {
  final _service = GroupService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _dba;
  late final TextEditingController _taxId;
  late final TextEditingController _fullTimeEmployees;
  late final TextEditingController _website;
  late final TextEditingController _businessPhone;
  late final TextEditingController _addressLine1;
  late final TextEditingController _addressLine2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;

  late final TextEditingController _adminFirstName;
  late final TextEditingController _adminLastName;
  late final TextEditingController _adminPhone;

  late final TextEditingController _billingFirstName;
  late final TextEditingController _billingLastName;
  late final TextEditingController _billingPhone;
  late final TextEditingController _billingEmail;

  late final TextEditingController _eligibilityDefinition;
  late WaitingPeriod _waitingPeriod;
  late final TextEditingController _waitingPeriodOther;
  late bool _domesticPartners;

  bool _busy = false;
  bool _controllersReady = false;
  Group? _group;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final g = await _service.getGroup(widget.groupId);
      if (g == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group not found')),
        );
        return;
      }
      final det = g.details;
      setState(() {
        _group = g;
        _dba = TextEditingController(text: det.dba);
        _taxId = TextEditingController(text: det.taxId);
        _fullTimeEmployees = TextEditingController(text: det.fullTimeEmployees);
        _website = TextEditingController(text: det.website);
        _businessPhone = TextEditingController(text: det.businessPhone);
        _addressLine1 = TextEditingController(text: det.addressLine1);
        _addressLine2 = TextEditingController(text: det.addressLine2);
        _city = TextEditingController(text: det.city);
        _state = TextEditingController(text: det.state);
        _zip = TextEditingController(text: det.zip);
        _adminFirstName = TextEditingController(text: det.adminFirstName);
        _adminLastName = TextEditingController(text: det.adminLastName);
        _adminPhone = TextEditingController(text: det.adminPhone);
        _billingFirstName = TextEditingController(text: det.billingFirstName);
        _billingLastName = TextEditingController(text: det.billingLastName);
        _billingPhone = TextEditingController(text: det.billingPhone);
        _billingEmail = TextEditingController(text: det.billingEmail);
        _eligibilityDefinition = TextEditingController(text: det.eligibilityDefinition);
        _waitingPeriod = det.waitingPeriod;
        _waitingPeriodOther = TextEditingController(text: det.waitingPeriodOther);
        _domesticPartners = det.domesticPartners;
        _controllersReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading group: $e')),
      );
    }
  }

  @override
  void dispose() {
    if (!_controllersReady) {
      super.dispose();
      return;
    }
    _dba.dispose();
    _taxId.dispose();
    _fullTimeEmployees.dispose();
    _website.dispose();
    _businessPhone.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _adminFirstName.dispose();
    _adminLastName.dispose();
    _adminPhone.dispose();
    _billingFirstName.dispose();
    _billingLastName.dispose();
    _billingPhone.dispose();
    _billingEmail.dispose();
    _eligibilityDefinition.dispose();
    _waitingPeriodOther.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _group == null) return;
    setState(() => _busy = true);
    try {
      // HR managers (anonymous, link-based) can't write `groups` directly under
      // the locked-down security rules, so the save goes through a Cloud
      // Function that whitelists just these HR fields under `details.*`.
      await FirebaseFunctions.instance.httpsCallable('updateHrDetails').call({
        'groupId': widget.groupId,
        'details': {
          'dba': _dba.text.trim(),
          'taxId': _taxId.text.trim(),
          'fullTimeEmployees': _fullTimeEmployees.text.trim(),
          'website': _website.text.trim(),
          'businessPhone': _businessPhone.text.trim(),
          'addressLine1': _addressLine1.text.trim(),
          'addressLine2': _addressLine2.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'zip': _zip.text.trim(),
          'adminFirstName': _adminFirstName.text.trim(),
          'adminLastName': _adminLastName.text.trim(),
          'adminPhone': _adminPhone.text.trim(),
          'billingFirstName': _billingFirstName.text.trim(),
          'billingLastName': _billingLastName.text.trim(),
          'billingPhone': _billingPhone.text.trim(),
          'billingEmail': _billingEmail.text.trim(),
          'eligibilityDefinition': _eligibilityDefinition.text.trim(),
          'waitingPeriod': _waitingPeriod.name,
          'waitingPeriodOther': _waitingPeriodOther.text.trim(),
          'domesticPartners': _domesticPartners,
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group details saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Details')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.coral)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Group Details'),
      ),
      body: Form(
        key: _formKey,
        child: PageBody(
          maxWidth: 1100,
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_group!.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Fill in or update your group details below.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Company Info
            SectionCard(
              title: 'Company Information',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldRow([
                    LabeledField(
                      label: 'DBA',
                      child: TextFormField(
                        controller: _dba,
                        decoration: const InputDecoration(hintText: 'Doing Business As'),
                      ),
                    ),
                    LabeledField(
                      label: 'Tax ID',
                      child: TextFormField(
                        controller: _taxId,
                        decoration: const InputDecoration(hintText: 'XX-XXXXXXX'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Full-Time Employees',
                    child: TextFormField(
                      controller: _fullTimeEmployees,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: 'Number'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fieldRow([
                    LabeledField(
                      label: 'Website',
                      child: TextFormField(
                        controller: _website,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(hintText: 'https://...'),
                      ),
                    ),
                    LabeledField(
                      label: 'Phone',
                      child: TextFormField(
                        controller: _businessPhone,
                        decoration: const InputDecoration(hintText: '(555) 123-4567'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Address Line 1',
                    child: TextFormField(
                      controller: _addressLine1,
                      decoration: const InputDecoration(hintText: 'Street address'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Address Line 2',
                    child: TextFormField(
                      controller: _addressLine2,
                      decoration: const InputDecoration(hintText: 'Apt, suite, etc.'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fieldRow([
                    LabeledField(
                      label: 'City',
                      child: TextFormField(
                        controller: _city,
                        decoration: const InputDecoration(hintText: 'City'),
                      ),
                    ),
                    LabeledField(
                      label: 'State',
                      child: TextFormField(
                        controller: _state,
                        decoration: const InputDecoration(hintText: 'CA'),
                      ),
                    ),
                    LabeledField(
                      label: 'ZIP',
                      child: TextFormField(
                        controller: _zip,
                        decoration: const InputDecoration(hintText: '90210'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Admin Contact
            SectionCard(
              title: 'Admin Contact',
              child: _fieldRow([
                LabeledField(
                  label: 'First Name',
                  child: TextFormField(
                    controller: _adminFirstName,
                    decoration: const InputDecoration(hintText: 'First name'),
                  ),
                ),
                LabeledField(
                  label: 'Last Name',
                  child: TextFormField(
                    controller: _adminLastName,
                    decoration: const InputDecoration(hintText: 'Last name'),
                  ),
                ),
                LabeledField(
                  label: 'Phone',
                  child: TextFormField(
                    controller: _adminPhone,
                    decoration: const InputDecoration(hintText: 'Phone'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Billing Contact
            SectionCard(
              title: 'Billing Contact',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldRow([
                    LabeledField(
                      label: 'First Name',
                      child: TextFormField(
                        controller: _billingFirstName,
                        decoration: const InputDecoration(hintText: 'First name'),
                      ),
                    ),
                    LabeledField(
                      label: 'Last Name',
                      child: TextFormField(
                        controller: _billingLastName,
                        decoration: const InputDecoration(hintText: 'Last name'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _fieldRow([
                    LabeledField(
                      label: 'Phone',
                      child: TextFormField(
                        controller: _billingPhone,
                        decoration: const InputDecoration(hintText: 'Phone'),
                      ),
                    ),
                    LabeledField(
                      label: 'Email',
                      child: TextFormField(
                        controller: _billingEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(hintText: 'Email'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Eligibility
            SectionCard(
              title: 'Eligibility Requirements',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledField(
                    label: 'Eligibility Definition',
                    hint: 'Description of who is eligible (e.g., "Full-time employees")',
                    child: TextFormField(
                      controller: _eligibilityDefinition,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Who is eligible for coverage?',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'New-Hire Waiting Period',
                    child: _WaitingPeriodSegmented(
                      selected: _waitingPeriod,
                      onChanged: (p) => setState(() => _waitingPeriod = p),
                    ),
                  ),
                  if (_waitingPeriod == WaitingPeriod.other) ...[
                    const SizedBox(height: 12),
                    LabeledField(
                      label: 'Other Waiting Period',
                      child: TextFormField(
                        controller: _waitingPeriodOther,
                        decoration: const InputDecoration(hintText: 'Describe'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SwitchRow(
                    title: 'Allow Domestic Partners',
                    subtitle: 'Domestic partners will be treated as eligible dependents.',
                    value: _domesticPartners,
                    onChanged: (v) => setState(() => _domesticPartners = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(List<Widget> fields) {
    return Row(
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: fields[i]),
        ],
      ],
    );
  }
}

class _WaitingPeriodSegmented extends StatelessWidget {
  final WaitingPeriod selected;
  final ValueChanged<WaitingPeriod> onChanged;
  const _WaitingPeriodSegmented({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<WaitingPeriod>(
      segments: const [
        ButtonSegment(
          value: WaitingPeriod.firstFollowingHire,
          label: Text('1st Following Hire'),
        ),
        ButtonSegment(
          value: WaitingPeriod.first30,
          label: Text('First 30 Days'),
        ),
        ButtonSegment(
          value: WaitingPeriod.first60,
          label: Text('First 60 Days'),
        ),
        ButtonSegment(
          value: WaitingPeriod.other,
          label: Text('Other'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.title,
    this.subtitle,
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.3)),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.coral,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
