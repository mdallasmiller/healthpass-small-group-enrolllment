import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../utils/group_pdf.dart';
import '../utils/web_download.dart';
import '../widgets/ui.dart';

const _tier4Short = {
  Tier4.employeeOnly: 'Employee Only',
  Tier4.spouse: '+ Spouse',
  Tier4.child: '+ Child(ren)',
  Tier4.family: '+ Family',
};

/// Embeddable group plan + rates form. Used by the create screen and by the
/// group detail "Plan" tab. Handles its own save.
class GroupPlanForm extends StatefulWidget {
  final Group? group;
  final VoidCallback? onSaved;
  const GroupPlanForm({super.key, this.group, this.onSaved});

  bool get isEdit => group != null;

  @override
  State<GroupPlanForm> createState() => _GroupPlanFormState();
}

class _GroupPlanFormState extends State<GroupPlanForm> {
  final _service = GroupService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _ichra = false;

  // HAS form extra fields (string/num kept as text controllers, parsed on save).
  final Map<String, TextEditingController> _d = {};
  bool _domesticPartners = false;
  bool _stacking = false;
  TobaccoSurchargePayer _tobaccoPayer = TobaccoSurchargePayer.company;

  late final Map<String, Map<String, TextEditingController>> _medical;

  bool _dentalEnabled = false;
  DentalOption _dentalOption = DentalOption.coop2500;
  DentalContributionMode _dentalContribMode = DentalContributionMode.voluntary;
  late final TextEditingController _dentalCompanyContribution;

  // Eligibility
  WaitingPeriod _waitingPeriod = WaitingPeriod.firstFollowingHire;

  // Contribution strategy mode + defined contribution
  ContributionMode _mode = ContributionMode.employeeFacing;
  late Set<String> _offered;
  PayFrequency _payFrequency = PayFrequency.monthly;
  late final TextEditingController _employerContribution;
  // band -> level -> tierKey -> controller
  late final Map<String, Map<String, Map<String, TextEditingController>>> _dc;

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

    final det = g?.details ?? const GroupDetails();
    void put(String k, String v) => _d[k] = TextEditingController(text: v);
    put('dba', det.dba);
    put('effectiveDate', det.effectiveDate);
    put('startDate', det.startDate);
    put('affiliateCompany', det.affiliateCompany);
    put('affiliateEmail', det.affiliateEmail);
    put('refererName', det.refererName);
    put('eligibilityDefinition', det.eligibilityDefinition);
    put('waitingPeriodOther', det.waitingPeriodOther);
    put('producer', det.producer);
    put('referralPartner', det.referralPartner);
    put('referer', det.referer);
    put('taxId', det.taxId);
    put('businessPhone', det.businessPhone);
    put('website', det.website);
    put('fullTimeEmployees', det.fullTimeEmployees);
    put('addressLine1', det.addressLine1);
    put('addressLine2', det.addressLine2);
    put('city', det.city);
    put('state', det.state);
    put('zip', det.zip);
    put('educationDate', det.educationDate);
    put('educationTime', det.educationTime);
    put('enrollmentStrategy', det.enrollmentStrategy);
    put('adminFirstName', det.adminFirstName);
    put('adminLastName', det.adminLastName);
    put('adminPhone', det.adminPhone);
    put('billingFirstName', det.billingFirstName);
    put('billingLastName', det.billingLastName);
    put('billingPhone', det.billingPhone);
    put('billingEmail', det.billingEmail);
    put('ichraEoTarget', _fmt(det.ichraEoTarget));
    put('ichraSpouseTarget', _fmt(det.ichraSpouseTarget));
    put('ichraChildTarget', _fmt(det.ichraChildTarget));
    put('preventiveVideoUrl', det.preventiveVideoUrl);
    put('healthVideoUrl', det.healthVideoUrl);
    put('ichraVideoUrl', det.ichraVideoUrl);
    put('dentalVideoUrl', det.dentalVideoUrl);
    put('preventiveDescription', det.preventiveDescription);
    put('healthDescription', det.healthDescription);
    put('ichraDescription', det.ichraDescription);
    put('dentalDescription', det.dentalDescription);
    put('notes', det.notes);
    _domesticPartners = det.domesticPartners;
    _stacking = det.stacking;
    _tobaccoPayer = g?.tobaccoSurchargePayer ?? TobaccoSurchargePayer.company;

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
    _dentalContribMode = d.contributionMode;
    _dentalCompanyContribution =
        TextEditingController(text: _fmt(d.companyContribution));
    _waitingPeriod = (g?.details ?? const GroupDetails()).waitingPeriod;

    _mode = g?.contributionMode ?? ContributionMode.employeeFacing;
    _offered = {...(g?.offeredLevels ?? kCoopLevels)};
    _payFrequency = g?.payFrequency ?? PayFrequency.monthly;
    final dc = g?.definedContribution ?? DefinedContribution.standard();
    _employerContribution =
        TextEditingController(text: _fmt(dc.employerContribution));
    _dc = {
      for (final band in kAgeBands)
        band: {
          for (final level in kCoopLevels)
            level: {
              for (final t in Tier4.values)
                t.key: TextEditingController(
                    text: _fmt(dc.ratesFor(band, level).forTier(t))),
            }
        }
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _dentalCompanyContribution.dispose();
    for (final c in _d.values) {
      c.dispose();
    }
    for (final m in _medical.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    _employerContribution.dispose();
    for (final band in _dc.values) {
      for (final level in band.values) {
        for (final c in level.values) {
          c.dispose();
        }
      }
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

  Tier4Rates _rates4From(Map<String, TextEditingController> m) => Tier4Rates(
        employeeOnly: _parse(m[Tier4.employeeOnly.key]!.text),
        spouse: _parse(m[Tier4.spouse.key]!.text),
        child: _parse(m[Tier4.child.key]!.text),
        family: _parse(m[Tier4.family.key]!.text),
      );

  /// Builds a Group from the current form state (shared by save and export).
  Group _composeGroup() {
    String t(String k) => _d[k]!.text.trim();
    final details = GroupDetails(
      dba: t('dba'),
      effectiveDate: t('effectiveDate'),
      startDate: t('startDate'),
      affiliateCompany: t('affiliateCompany'),
      affiliateEmail: t('affiliateEmail'),
      producer: t('producer'),
      referralPartner: t('referralPartner'),
      referer: t('referer'),
      refererName: t('refererName'),
      eligibilityDefinition: t('eligibilityDefinition'),
      waitingPeriod: _waitingPeriod,
      waitingPeriodOther: t('waitingPeriodOther'),
      taxId: t('taxId'),
      businessPhone: t('businessPhone'),
      website: t('website'),
      fullTimeEmployees: t('fullTimeEmployees'),
      addressLine1: t('addressLine1'),
      addressLine2: t('addressLine2'),
      city: t('city'),
      state: t('state'),
      zip: t('zip'),
      educationDate: t('educationDate'),
      educationTime: t('educationTime'),
      enrollmentStrategy: t('enrollmentStrategy'),
      adminFirstName: t('adminFirstName'),
      adminLastName: t('adminLastName'),
      adminPhone: t('adminPhone'),
      billingFirstName: t('billingFirstName'),
      billingLastName: t('billingLastName'),
      billingPhone: t('billingPhone'),
      billingEmail: t('billingEmail'),
      domesticPartners: _domesticPartners,
      stacking: _stacking,
      ichraEoTarget: _parse(t('ichraEoTarget')),
      ichraSpouseTarget: _parse(t('ichraSpouseTarget')),
      ichraChildTarget: _parse(t('ichraChildTarget')),
      healthVideoUrl: t('healthVideoUrl'),
      ichraVideoUrl: t('ichraVideoUrl'),
      dentalVideoUrl: t('dentalVideoUrl'),
      healthDescription: t('healthDescription'),
      ichraDescription: t('ichraDescription'),
      dentalDescription: t('dentalDescription'),
      notes: t('notes'),
    );

    final definedContribution = DefinedContribution(
      employerContribution: _parse(_employerContribution.text),
      rates: {
        for (final band in kAgeBands)
          band: {
            for (final level in kCoopLevels)
              level: _rates4From(_dc[band]![level]!)
          }
      },
    );

    return (widget.group ?? Group.empty()).copyWith(
      name: _name.text.trim(),
      contactEmail: _email.text.trim(),
      ichraEnabled: _ichra,
      tobaccoSurcharge: 75, // fixed
      tobaccoSurchargePayer: _tobaccoPayer,
      details: details,
      contributionMode: _mode,
      offeredLevels: kCoopLevels.where(_offered.contains).toList(),
      definedContribution: definedContribution,
      payFrequency: _payFrequency,
      status: _status,
      medicalRates: {
        for (final level in kCoopLevels) level: _ratesFrom(_medical[level]!)
      },
      dental: DentalConfig(
        enabled: _dentalEnabled,
        option: _dentalOption,
        rates: kStaticDentalRates,
        contributionMode: _dentalContribMode,
        companyContribution: _parse(_dentalCompanyContribution.text),
      ),
    );
  }

  /// Exports the group's current setup as a PDF to share with a partner org.
  Future<void> _exportInfo() async {
    setState(() => _busy = true);
    try {
      final group = _composeGroup();
      final safe = group.name.trim().isEmpty ? 'group' : group.name.trim();
      final bytes = await buildGroupInfoPdf(group);
      downloadBytes('$safe setup.pdf', bytes, mime: 'application/pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final group = _composeGroup();

      if (widget.isEdit) {
        await _service.update(widget.group!.id!, group);
      } else {
        await _service.create(group);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isEdit ? 'Group updated' : 'Group created')),
      );
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: PageBody(
        maxWidth: 1100,
        children: [
          _detailsCard(),
          const SizedBox(height: 16),
          _businessCard(),
          const SizedBox(height: 16),
          _contactsCard(),
          const SizedBox(height: 16),
          _eligibilityCard(),
          const SizedBox(height: 16),
          _medicalCard(),
          const SizedBox(height: 16),
          _rateOptionsCard(),
          const SizedBox(height: 16),
          _dentalCard(),
          const SizedBox(height: 16),
          _ichraCard(),
          const SizedBox(height: 16),
          _videosCard(),
          const SizedBox(height: 16),
          _notesCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              if (!widget.isEdit) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _exportInfo,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export info (PDF)'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// One text field bound to a _d[key] controller.
  Widget _text(
    String key,
    String label, {
    String? hint,
    TextInputType? type,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return LabeledField(
      label: label,
      child: TextFormField(
        controller: _d[key],
        keyboardType: type,
        inputFormatters: formatters,
        validator: validator,
        decoration: InputDecoration(hintText: hint, isDense: true),
      ),
    );
  }

  /// A MM/DD/YYYY date field.
  Widget _dateText(String key, String label) => _text(
        key,
        label,
        hint: 'MM/DD/YYYY',
        type: TextInputType.number,
        formatters: [DateSlashFormatter()],
        validator: optionalDateValidator,
      );

  /// A row of fields that wraps on narrow screens.
  Widget _fieldRow(List<Widget> fields) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          Expanded(child: fields[i]),
          if (i != fields.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _businessCard() {
    return SectionCard(
      title: 'Group details',
      subtitle: 'Employer, affiliate and company information.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupLabel('GROUP DETAILS'),
          const SizedBox(height: 10),
          _fieldRow([
            _text('dba', 'DBA'),
            _dateText('effectiveDate', 'Effective date'),
          ]),
          const SizedBox(height: 16),
          _fieldRow([
            _text('taxId', 'Tax ID',
                hint: '12-3456789',
                type: TextInputType.number,
                formatters: [taxIdChars]),
            _text('fullTimeEmployees', 'Total full-time employees',
                type: TextInputType.number, formatters: [digitsOnly]),
          ]),
          const Divider(height: 32),
          const _GroupLabel('AFFILIATE + REFERER'),
          const SizedBox(height: 10),
          _fieldRow([
            _text('affiliateCompany', 'Affiliate company'),
            _text('affiliateEmail', 'Affiliate contact email',
                type: TextInputType.emailAddress, validator: optionalEmailValidator),
          ]),
          const SizedBox(height: 16),
          _fieldRow([
            _text('referralPartner', 'Referral partner'),
            _text('refererName', 'Referer name'),
          ]),
          const Divider(height: 32),
          const _GroupLabel('COMPANY INFORMATION'),
          const SizedBox(height: 10),
          _fieldRow([
            _text('website', 'Company website', type: TextInputType.url),
            _text('businessPhone', 'Company phone',
                type: TextInputType.phone, formatters: [phoneChars]),
          ]),
          const SizedBox(height: 16),
          _text('addressLine1', 'Company address'),
          const SizedBox(height: 16),
          _text('addressLine2', 'Address line 2'),
          const SizedBox(height: 16),
          _fieldRow([
            _text('city', 'City'),
            _text('state', 'State'),
            _text('zip', 'Zip',
                type: TextInputType.number, formatters: [digitsOnly]),
          ]),
        ],
      ),
    );
  }

  Widget _eligibilityCard() {
    return SectionCard(
      title: 'Eligibility',
      subtitle: 'How the company defines benefit eligibility.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledField(
            label: 'How does the company define benefit eligibility?',
            child: TextFormField(
              controller: _d['eligibilityDefinition'],
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  hintText: 'e.g. Full-time employees working 30+ hours/week'),
            ),
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: 'New-hire waiting period',
            child: _Segmented<WaitingPeriod>(
              values: WaitingPeriod.values,
              selected: _waitingPeriod,
              labelOf: (w) => w.label,
              onChanged: (w) => setState(() => _waitingPeriod = w),
            ),
          ),
          if (_waitingPeriod == WaitingPeriod.other) ...[
            const SizedBox(height: 14),
            _text('waitingPeriodOther', 'Other (describe)'),
          ],
        ],
      ),
    );
  }

  Widget _contactsCard() {
    return SectionCard(
      title: 'Contacts',
      subtitle: 'Admin and billing contacts.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupLabel('ADMIN CONTACT'),
          const SizedBox(height: 10),
          _fieldRow([
            _text('adminFirstName', 'First name'),
            _text('adminLastName', 'Last name'),
          ]),
          const SizedBox(height: 16),
          _fieldRow([
            LabeledField(
              label: 'Email (sender for invitations)',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'hr@acme.com', isDense: true),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email.' : null,
              ),
            ),
            _text('adminPhone', 'Phone',
                type: TextInputType.phone, formatters: [phoneChars]),
          ]),
          const Divider(height: 32),
          const _GroupLabel('BILLING CONTACT'),
          const SizedBox(height: 10),
          _fieldRow([
            _text('billingFirstName', 'First name'),
            _text('billingLastName', 'Last name'),
          ]),
          const SizedBox(height: 16),
          _fieldRow([
            _text('billingEmail', 'Email',
                type: TextInputType.emailAddress, validator: optionalEmailValidator),
            _text('billingPhone', 'Phone',
                type: TextInputType.phone, formatters: [phoneChars]),
          ]),
        ],
      ),
    );
  }

  Widget _rateOptionsCard() {
    return SectionCard(
      title: 'Rate options',
      subtitle: 'Surcharge and rate rules from the HAS form.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tobacco surcharge is a fixed \$75 per tobacco user, per month '
                    'on a Cooperative plan.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Who will pay the tobacco surcharge?',
            hint: 'If Company, the charge is hidden from the employee but kept on the deduction report.',
            child: _Segmented<TobaccoSurchargePayer>(
              values: TobaccoSurchargePayer.values,
              selected: _tobaccoPayer,
              labelOf: (p) => p.label,
              onChanged: (p) => setState(() => _tobaccoPayer = p),
            ),
          ),
          const SizedBox(height: 18),
          _SwitchRow(
            title: 'Domestic partners',
            subtitle: 'Domestic partners are treated as eligible dependents.',
            value: _domesticPartners,
            onChanged: (v) => setState(() => _domesticPartners = v),
          ),
          const SizedBox(height: 16),
          _SwitchRow(
            title: 'Stacking',
            subtitle: 'Allow stacking of coverage.',
            value: _stacking,
            onChanged: (v) => setState(() => _stacking = v),
          ),
        ],
      ),
    );
  }

  Widget _ichraCard() {
    return SectionCard(
      title: 'ICHRA',
      subtitle: 'Individual Coverage HRA option shown in the enrollment portal.',
      trailing: Switch(
        value: _ichra,
        activeThumbColor: AppColors.coral,
        onChanged: (v) => setState(() => _ichra = v),
      ),
      child: !_ichra
          ? Text('ICHRA is turned off for this group.',
              style: TextStyle(color: AppColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GroupLabel('TARGET EMPLOYEE RATE'),
                const SizedBox(height: 4),
                Text(
                    'Estimated monthly cost shown to the employee at each tier.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 14),
                _fieldRow([
                  LabeledField(
                      label: 'Employee', child: _money(_d['ichraEoTarget']!)),
                  LabeledField(
                      label: 'Spouse', child: _money(_d['ichraSpouseTarget']!)),
                  LabeledField(
                      label: 'Child', child: _money(_d['ichraChildTarget']!)),
                ]),
              ],
            ),
    );
  }

  Widget _videosCard() {
    return SectionCard(
      title: 'Product content',
      subtitle:
          'Per step: a description (Markdown supported: # headings, **bold**, lists, '
          '[links](url), ![image](url)) and a video URL. Shown to employees in the portal.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GroupLabel('PREVENTIVE'),
          const SizedBox(height: 10),
          _markdownField('preventiveDescription'),
          const SizedBox(height: 12),
          _text('preventiveVideoUrl', 'Video URL', hint: 'https://...', type: TextInputType.url),
          const Divider(height: 32),
          const _GroupLabel('PREVENTIVE + COOPERATIVE BUNDLE'),
          const SizedBox(height: 10),
          _markdownField('healthDescription'),
          const SizedBox(height: 12),
          _text('healthVideoUrl', 'Video URL', hint: 'https://...', type: TextInputType.url),
          const Divider(height: 32),
          const _GroupLabel('ICHRA'),
          const SizedBox(height: 10),
          _markdownField('ichraDescription'),
          const SizedBox(height: 12),
          _text('ichraVideoUrl', 'Video URL', hint: 'https://...', type: TextInputType.url),
          const Divider(height: 32),
          const _GroupLabel('DENTAL'),
          const SizedBox(height: 10),
          _markdownField('dentalDescription'),
          const SizedBox(height: 12),
          _text('dentalVideoUrl', 'Video URL', hint: 'https://...', type: TextInputType.url),
        ],
      ),
    );
  }

  Widget _markdownField(String key) => LabeledField(
        label: 'Description',
        child: TextFormField(
          controller: _d[key],
          minLines: 3,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '## Heading\\n\\nYour description here. **Bold**, lists, links…',
          ),
        ),
      );

  Widget _notesCard() {
    return SectionCard(
      title: 'Notes',
      subtitle: 'Internal notes for this group.',
      child: TextFormField(
        controller: _d['notes'],
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(hintText: 'Anything worth recording…'),
      ),
    );
  }

  Widget _detailsCard() {
    return SectionCard(
      title: 'Group details',
      subtitle: 'Employer information and plan options.',
      child: LabeledField(
        label: 'Group / employer name',
        child: TextFormField(
          controller: _name,
          decoration: const InputDecoration(hintText: 'Acme Corp'),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Group name is required.' : null,
        ),
      ),
    );
  }

  Widget _medicalCard() {
    return SectionCard(
      title: 'Contribution strategy',
      subtitle: 'How medical pricing is presented to employees.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Segmented<ContributionMode>(
            values: ContributionMode.values,
            selected: _mode,
            labelOf: (m) => m == ContributionMode.employeeFacing
                ? 'Employee-facing price'
                : 'Defined contribution',
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 18),
          const _GroupLabel('OFFERED DEDUCTIBLE LEVELS'),
          const SizedBox(height: 10),
          _offeredToggles(),
          const SizedBox(height: 18),
          if (_mode == ContributionMode.employeeFacing)
            _RatesGrid(controllers: _medical, money: _money, offered: _offered)
          else ...[
            LabeledField(
              label: 'Employer contribution (monthly, per employee)',
              hint: 'Subtracted from the age-banded rate to get the employee deduction.',
              child: _money(_employerContribution),
            ),
            const SizedBox(height: 18),
            _DcGrid(controllers: _dc, money: _money),
          ],
          const Divider(height: 32),
          LabeledField(
            label: 'Payroll frequency',
            hint: 'Drives the per-pay-period deduction shown to employees.',
            child: _Segmented<PayFrequency>(
              values: PayFrequency.values,
              selected: _payFrequency,
              labelOf: (p) => p.label,
              onChanged: (p) => setState(() => _payFrequency = p),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offeredToggles() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kCoopLevels.map((l) {
        final on = _offered.contains(l);
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => on ? _offered.remove(l) : _offered.add(l)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: on ? AppColors.coral : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: on ? AppColors.coral : const Color(0xFFCBD4DE), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 16, color: on ? Colors.white : AppColors.muted),
                const SizedBox(width: 6),
                Text(coopLevelLabel(l),
                    style: TextStyle(
                        color: on ? Colors.white : AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5)),
              ],
            ),
          ),
        );
      }).toList(),
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
                  label: 'Plan',
                  child: _Segmented<DentalOption>(
                    values: DentalOption.values,
                    selected: _dentalOption,
                    labelOf: (o) => o.label,
                    onChanged: (o) => setState(() => _dentalOption = o),
                  ),
                ),
                const SizedBox(height: 20),
                LabeledField(
                  label: 'Contribution',
                  child: _Segmented<DentalContributionMode>(
                    values: DentalContributionMode.values,
                    selected: _dentalContribMode,
                    labelOf: (m) => m.label,
                    onChanged: (m) => setState(() => _dentalContribMode = m),
                  ),
                ),
                if (_dentalContribMode == DentalContributionMode.voluntary) ...[
                  const SizedBox(height: 10),
                  Text(
                      'Voluntary: the employee pays the full fixed tier rate.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ] else ...[
                  const SizedBox(height: 14),
                  LabeledField(
                    label: 'Company contribution (monthly)',
                    hint: 'Subtracted from each tier rate to get the employee cost.',
                    child: _money(_dentalCompanyContribution),
                  ),
                ],
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

class _RatesGrid extends StatelessWidget {
  final Map<String, Map<String, TextEditingController>> controllers;
  final Widget Function(TextEditingController) money;
  final Set<String> offered;
  const _RatesGrid({
    required this.controllers,
    required this.money,
    required this.offered,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _headerRow(),
        const SizedBox(height: 8),
        for (final level in kCoopLevels) ...[
          // Levels not offered are grayed out (and not collected from employees).
          Opacity(
            opacity: offered.contains(level) ? 1.0 : 0.4,
            child: _levelRow(level),
          ),
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

/// Age-banded rate grid for defined contribution: one block per age band, with
/// columns per deductible level and rows per tier.
class _DcGrid extends StatelessWidget {
  final Map<String, Map<String, Map<String, TextEditingController>>> controllers;
  final Widget Function(TextEditingController) money;
  const _DcGrid({required this.controllers, required this.money});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final band in kAgeBands) ...[
          _bandBlock(band),
          if (band != kAgeBands.last) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _bandBlock(String band) {
    final lvls = controllers[band]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Age $band',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 96),
              for (final l in kCoopLevels) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(coopLevelLabel(l),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          for (final t in Tier4.values)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(_tier4Short[t]!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600)),
                  ),
                  for (final l in kCoopLevels) ...[
                    const SizedBox(width: 8),
                    Expanded(child: money(lvls[l]![t.key]!)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );
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
          borderRadius: BorderRadius.circular(24),
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSel ? AppColors.coral : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: isSel ? AppColors.coral : const Color(0xFFCBD4DE), width: 1.5),
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
