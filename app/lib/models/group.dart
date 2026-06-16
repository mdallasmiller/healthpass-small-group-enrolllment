import 'package:cloud_firestore/cloud_firestore.dart';

/// Cooperative levels (deductible) offered to a group. Mirrors the rate
/// spreadsheet. Stored as string keys for Firestore-friendly maps.
const List<String> kCoopLevels = ['1000', '2500', '4000'];

String coopLevelLabel(String level) {
  switch (level) {
    case '1000':
      return '\$1K';
    case '2500':
      return '\$2.5K';
    case '4000':
      return '\$4K';
    default:
      return '\$$level';
  }
}

/// The three employee-facing tiers used at enrollment.
enum Tier { employeeOnly, spouseChild, family }

extension TierLabel on Tier {
  String get label => switch (this) {
        Tier.employeeOnly => 'Employee Only',
        Tier.spouseChild => 'Employee + Spouse/Child(ren)',
        Tier.family => 'Employee + Family',
      };
  String get key => name;
}

/// Three rates for one cooperative level.
class TierRates {
  final num employeeOnly;
  final num spouseChild;
  final num family;

  const TierRates({
    this.employeeOnly = 0,
    this.spouseChild = 0,
    this.family = 0,
  });

  num forTier(Tier t) => switch (t) {
        Tier.employeeOnly => employeeOnly,
        Tier.spouseChild => spouseChild,
        Tier.family => family,
      };

  bool get isEmpty => employeeOnly == 0 && spouseChild == 0 && family == 0;

  Map<String, dynamic> toMap() => {
        'employeeOnly': employeeOnly,
        'spouseChild': spouseChild,
        'family': family,
      };

  factory TierRates.fromMap(Map<String, dynamic>? m) => TierRates(
        employeeOnly: (m?['employeeOnly'] ?? 0) as num,
        spouseChild: (m?['spouseChild'] ?? 0) as num,
        family: (m?['family'] ?? 0) as num,
      );

  TierRates copyWith({num? employeeOnly, num? spouseChild, num? family}) =>
      TierRates(
        employeeOnly: employeeOnly ?? this.employeeOnly,
        spouseChild: spouseChild ?? this.spouseChild,
        family: family ?? this.family,
      );
}

/// The four carrier tiers used by dental and by age-banded (defined
/// contribution) rates. Medical "employee-facing" pricing still uses the
/// 3-tier [Tier] above.
enum Tier4 { employeeOnly, spouse, child, family }

extension Tier4Label on Tier4 {
  String get label => switch (this) {
        Tier4.employeeOnly => 'Employee Only',
        Tier4.spouse => 'Employee + Spouse',
        Tier4.child => 'Employee + Child(ren)',
        Tier4.family => 'Employee + Family',
      };
  String get key => name;
}

/// Four rates for one context (a dental config, or one age-band/level cell).
class Tier4Rates {
  final num employeeOnly;
  final num spouse;
  final num child;
  final num family;
  const Tier4Rates({
    this.employeeOnly = 0,
    this.spouse = 0,
    this.child = 0,
    this.family = 0,
  });

  num forTier(Tier4 t) => switch (t) {
        Tier4.employeeOnly => employeeOnly,
        Tier4.spouse => spouse,
        Tier4.child => child,
        Tier4.family => family,
      };

  bool get isEmpty =>
      employeeOnly == 0 && spouse == 0 && child == 0 && family == 0;

  Map<String, dynamic> toMap() => {
        'employeeOnly': employeeOnly,
        'spouse': spouse,
        'child': child,
        'family': family,
      };

  factory Tier4Rates.fromMap(Map<String, dynamic>? m) => Tier4Rates(
        employeeOnly: (m?['employeeOnly'] ?? 0) as num,
        spouse: (m?['spouse'] ?? 0) as num,
        child: (m?['child'] ?? 0) as num,
        family: (m?['family'] ?? 0) as num,
      );
}

/// Age bands used by the defined-contribution (age-banded) rate table.
const List<String> kAgeBands = ['18-29', '30-39', '40-49', '50-59', '60-64'];

/// Maps a concrete age to its band key. Ages under 18 fall in the lowest band,
/// 65+ in the highest.
String ageBandFor(int age) {
  if (age <= 29) return '18-29';
  if (age <= 39) return '30-39';
  if (age <= 49) return '40-49';
  if (age <= 59) return '50-59';
  return '60-64';
}

/// How the medical contribution strategy is defined.
enum ContributionMode { employeeFacing, definedContribution }

/// Who pays the tobacco surcharge.
enum TobaccoSurchargePayer { company, employee }

extension TobaccoSurchargePayerLabel on TobaccoSurchargePayer {
  String get label =>
      this == TobaccoSurchargePayer.company ? 'Company' : 'Employee';
}

/// Payroll pay-period frequency (drives the per-pay-period deduction display).
enum PayFrequency { weekly, biWeekly, semiMonthly, monthly }

extension PayFrequencyInfo on PayFrequency {
  /// Pay periods per year.
  int get periodsPerYear => switch (this) {
        PayFrequency.weekly => 52,
        PayFrequency.biWeekly => 26,
        PayFrequency.semiMonthly => 24,
        PayFrequency.monthly => 12,
      };
  String get label => switch (this) {
        PayFrequency.weekly => 'Weekly (52/yr)',
        PayFrequency.biWeekly => 'Bi-weekly (26/yr)',
        PayFrequency.semiMonthly => 'Semi-monthly (24/yr)',
        PayFrequency.monthly => 'Monthly (12/yr)',
      };
  String get short => switch (this) {
        PayFrequency.weekly => 'per week',
        PayFrequency.biWeekly => 'bi-weekly',
        PayFrequency.semiMonthly => 'semi-monthly',
        PayFrequency.monthly => 'per month',
      };

  /// A monthly amount converted to one pay period.
  num fromMonthly(num monthly) => monthly * 12 / periodsPerYear;
}

/// Defined-contribution config: an employer monthly contribution plus the
/// age-banded rate table (band -> cooperative level -> 4 tier rates).
class DefinedContribution {
  final num employerContribution; // per employee per month
  final Map<String, Map<String, Tier4Rates>> rates;

  const DefinedContribution({
    this.employerContribution = 159,
    this.rates = const {},
  });

  Tier4Rates ratesFor(String band, String level) =>
      rates[band]?[level] ?? const Tier4Rates();

  Map<String, dynamic> toMap() => {
        'employerContribution': employerContribution,
        'rates': {
          for (final band in rates.entries)
            band.key: {
              for (final lvl in band.value.entries) lvl.key: lvl.value.toMap()
            }
        },
      };

  factory DefinedContribution.fromMap(Map<String, dynamic>? m) {
    if (m == null || m.isEmpty) return DefinedContribution.standard();
    final raw = (m['rates'] as Map<String, dynamic>?) ?? {};
    final rates = <String, Map<String, Tier4Rates>>{};
    for (final band in kAgeBands) {
      final bandMap = (raw[band] as Map<String, dynamic>?) ?? {};
      rates[band] = {
        for (final lvl in kCoopLevels)
          lvl: Tier4Rates.fromMap(bandMap[lvl] as Map<String, dynamic>?)
      };
    }
    return DefinedContribution(
      employerContribution: (m['employerContribution'] ?? 159) as num,
      rates: rates,
    );
  }

  /// The standard Health Access Bundle group rate table.
  factory DefinedContribution.standard() => const DefinedContribution(
        employerContribution: 159,
        rates: _standardRates,
      );
}

// Health Access Bundle (EAP + Healthcare Co-op) group rates, by age band and
// deductible level. Source: Agency Network Estimate Tool.
const Map<String, Map<String, Tier4Rates>> _standardRates = {
  '18-29': {
    '1000': Tier4Rates(employeeOnly: 299, spouse: 582, child: 582, family: 886),
    '2500': Tier4Rates(employeeOnly: 249, spouse: 482, child: 482, family: 786),
    '4000': Tier4Rates(employeeOnly: 234, spouse: 452, child: 452, family: 756),
  },
  '30-39': {
    '1000': Tier4Rates(employeeOnly: 328, spouse: 640, child: 640, family: 944),
    '2500': Tier4Rates(employeeOnly: 268, spouse: 520, child: 520, family: 824),
    '4000': Tier4Rates(employeeOnly: 250, spouse: 484, child: 484, family: 788),
  },
  '40-49': {
    '1000': Tier4Rates(employeeOnly: 362, spouse: 708, child: 708, family: 1012),
    '2500': Tier4Rates(employeeOnly: 290, spouse: 564, child: 564, family: 868),
    '4000': Tier4Rates(employeeOnly: 268, spouse: 520, child: 520, family: 824),
  },
  '50-59': {
    '1000': Tier4Rates(employeeOnly: 466, spouse: 916, child: 916, family: 1220),
    '2500': Tier4Rates(employeeOnly: 356, spouse: 696, child: 696, family: 1000),
    '4000': Tier4Rates(employeeOnly: 323, spouse: 630, child: 630, family: 934),
  },
  '60-64': {
    '1000': Tier4Rates(employeeOnly: 561, spouse: 1106, child: 1106, family: 1410),
    '2500': Tier4Rates(employeeOnly: 374, spouse: 818, child: 818, family: 1122),
    '4000': Tier4Rates(employeeOnly: 417, spouse: 732, child: 732, family: 1036),
  },
};

enum DentalOption { coop1500, coop2500, bentoSelfFunded }

extension DentalOptionLabel on DentalOption {
  String get label => switch (this) {
        DentalOption.coop1500 => 'Coop 1500',
        DentalOption.coop2500 => 'Coop 2500',
        DentalOption.bentoSelfFunded => 'Bento Self-Funded',
      };
  String get key => name;
}

/// Dental contribution: Voluntary (employee pays the tier rate) or Company
/// Contribution (the company amount is subtracted from the tier rate).
enum DentalContributionMode { voluntary, companyContribution }

extension DentalContributionModeLabel on DentalContributionMode {
  String get label => this == DentalContributionMode.voluntary
      ? 'Voluntary'
      : 'Company Contribution';
}

class DentalConfig {
  final bool enabled;
  final DentalOption option;
  final Tier4Rates rates;
  final DentalContributionMode contributionMode;
  final num companyContribution; // monthly, subtracted from each tier rate

  const DentalConfig({
    this.enabled = false,
    this.option = DentalOption.coop2500,
    this.rates = const Tier4Rates(),
    this.contributionMode = DentalContributionMode.voluntary,
    this.companyContribution = 0,
  });

  /// The plan name used on exports, e.g. "Coop Dental 2500".
  String get planName => switch (option) {
        DentalOption.coop1500 => 'Coop Dental 1500',
        DentalOption.coop2500 => 'Coop Dental 2500',
        DentalOption.bentoSelfFunded => 'Bento Self-Funded Dental',
      };

  /// Employee's monthly dental cost for a tier, honoring the contribution mode.
  num employeeCost(Tier4 t) {
    final base = rates.forTier(t);
    if (contributionMode == DentalContributionMode.companyContribution) {
      final net = base - companyContribution;
      return net < 0 ? 0 : net;
    }
    return base;
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'option': option.key,
        'rates': rates.toMap(),
        'contributionMode': contributionMode.name,
        'companyContribution': companyContribution,
      };

  factory DentalConfig.fromMap(Map<String, dynamic>? m) => DentalConfig(
        enabled: (m?['enabled'] ?? false) as bool,
        option: DentalOption.values.firstWhere(
          (o) => o.key == m?['option'],
          orElse: () => DentalOption.coop2500,
        ),
        rates: Tier4Rates.fromMap(m?['rates'] as Map<String, dynamic>?),
        contributionMode: DentalContributionMode.values.firstWhere(
          (c) => c.name == m?['contributionMode'],
          orElse: () => DentalContributionMode.voluntary,
        ),
        companyContribution: (m?['companyContribution'] ?? 0) as num,
      );

  DentalConfig copyWith({
    bool? enabled,
    DentalOption? option,
    Tier4Rates? rates,
    DentalContributionMode? contributionMode,
    num? companyContribution,
  }) =>
      DentalConfig(
        enabled: enabled ?? this.enabled,
        option: option ?? this.option,
        rates: rates ?? this.rates,
        contributionMode: contributionMode ?? this.contributionMode,
        companyContribution: companyContribution ?? this.companyContribution,
      );
}

enum GroupStatus { draft, active, closed }

/// Enrollment campaign schedule (dates kept as 'dd.mm.yyyy' strings; time free text).
class EnrollmentSchedule {
  final String sendDate;
  final String sendTime;
  final String warningDate;
  final String endDate;
  const EnrollmentSchedule({
    this.sendDate = '',
    this.sendTime = '',
    this.warningDate = '',
    this.endDate = '',
  });

  bool get isSet => sendDate.isNotEmpty || endDate.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'sendDate': sendDate,
        'sendTime': sendTime,
        'warningDate': warningDate,
        'endDate': endDate,
      };

  factory EnrollmentSchedule.fromMap(Map<String, dynamic>? m) => EnrollmentSchedule(
        sendDate: (m?['sendDate'] ?? '') as String,
        sendTime: (m?['sendTime'] ?? '') as String,
        warningDate: (m?['warningDate'] ?? '') as String,
        endDate: (m?['endDate'] ?? '') as String,
      );

  EnrollmentSchedule copyWith({
    String? sendDate,
    String? sendTime,
    String? warningDate,
    String? endDate,
  }) =>
      EnrollmentSchedule(
        sendDate: sendDate ?? this.sendDate,
        sendTime: sendTime ?? this.sendTime,
        warningDate: warningDate ?? this.warningDate,
        endDate: endDate ?? this.endDate,
      );
}

/// Editable email/SMS message templates for the enrollment campaign.
class MessageTemplates {
  final String emailSubject;
  final String emailBody;
  final String smsBody;
  const MessageTemplates({
    this.emailSubject = '',
    this.emailBody = '',
    this.smsBody = '',
  });

  Map<String, dynamic> toMap() => {
        'emailSubject': emailSubject,
        'emailBody': emailBody,
        'smsBody': smsBody,
      };

  factory MessageTemplates.fromMap(Map<String, dynamic>? m) => MessageTemplates(
        emailSubject: (m?['emailSubject'] ?? '') as String,
        emailBody: (m?['emailBody'] ?? '') as String,
        smsBody: (m?['smsBody'] ?? '') as String,
      );
}

/// New-hire benefit waiting period.
enum WaitingPeriod { firstFollowingHire, first30, first60, other }

extension WaitingPeriodLabel on WaitingPeriod {
  String get label => switch (this) {
        WaitingPeriod.firstFollowingHire => '1st following hire',
        WaitingPeriod.first30 => '1st following 30 days',
        WaitingPeriod.first60 => '1st following 60 days',
        WaitingPeriod.other => 'Other',
      };
}

/// All the additional HAS Group Enrollment Form intake fields captured per
/// group (everything beyond name/contact/rates). Stored as a nested map.
class GroupDetails {
  // Group details
  final String dba;
  final String effectiveDate;
  final String startDate;
  // Affiliate + referer
  final String affiliateCompany;
  final String affiliateEmail;
  final String producer;
  final String referralPartner;
  final String referer;
  final String refererName;
  // Eligibility
  final String eligibilityDefinition;
  final WaitingPeriod waitingPeriod;
  final String waitingPeriodOther;
  // Business
  final String taxId;
  final String businessPhone;
  final String website;
  final String fullTimeEmployees;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String zip;
  // Education / enrollment
  final String educationDate;
  final String educationTime;
  final String enrollmentStrategy;
  // Admin contact (email is Group.contactEmail)
  final String adminFirstName;
  final String adminLastName;
  final String adminPhone;
  // Billing contact
  final String billingFirstName;
  final String billingLastName;
  final String billingPhone;
  final String billingEmail;
  // Rate modifiers
  final bool domesticPartners;
  final bool stacking;
  // ICHRA targets
  final num ichraEoTarget;
  final num ichraSpouseTarget;
  final num ichraChildTarget;
  // Explainer video URLs (shown in the portal). "health" = the Bundle section.
  final String preventiveVideoUrl;
  final String healthVideoUrl;
  final String ichraVideoUrl;
  final String dentalVideoUrl;
  // Product descriptions (Markdown) shown in the portal.
  final String preventiveDescription;
  final String healthDescription;
  final String ichraDescription;
  final String dentalDescription;
  final String notes;

  const GroupDetails({
    this.dba = '',
    this.effectiveDate = '',
    this.startDate = '',
    this.affiliateCompany = '',
    this.affiliateEmail = '',
    this.producer = '',
    this.referralPartner = '',
    this.referer = '',
    this.refererName = '',
    this.eligibilityDefinition = '',
    this.waitingPeriod = WaitingPeriod.firstFollowingHire,
    this.waitingPeriodOther = '',
    this.taxId = '',
    this.businessPhone = '',
    this.website = '',
    this.fullTimeEmployees = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.educationDate = '',
    this.educationTime = '',
    this.enrollmentStrategy = '',
    this.adminFirstName = '',
    this.adminLastName = '',
    this.adminPhone = '',
    this.billingFirstName = '',
    this.billingLastName = '',
    this.billingPhone = '',
    this.billingEmail = '',
    this.domesticPartners = false,
    this.stacking = false,
    this.ichraEoTarget = 0,
    this.ichraSpouseTarget = 0,
    this.ichraChildTarget = 0,
    this.preventiveVideoUrl = '',
    this.healthVideoUrl = '',
    this.ichraVideoUrl = '',
    this.dentalVideoUrl = '',
    this.preventiveDescription = '',
    this.healthDescription = '',
    this.ichraDescription = '',
    this.dentalDescription = '',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'dba': dba,
        'effectiveDate': effectiveDate,
        'startDate': startDate,
        'affiliateCompany': affiliateCompany,
        'affiliateEmail': affiliateEmail,
        'producer': producer,
        'referralPartner': referralPartner,
        'referer': referer,
        'refererName': refererName,
        'eligibilityDefinition': eligibilityDefinition,
        'waitingPeriod': waitingPeriod.name,
        'waitingPeriodOther': waitingPeriodOther,
        'taxId': taxId,
        'businessPhone': businessPhone,
        'website': website,
        'fullTimeEmployees': fullTimeEmployees,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'city': city,
        'state': state,
        'zip': zip,
        'educationDate': educationDate,
        'educationTime': educationTime,
        'enrollmentStrategy': enrollmentStrategy,
        'adminFirstName': adminFirstName,
        'adminLastName': adminLastName,
        'adminPhone': adminPhone,
        'billingFirstName': billingFirstName,
        'billingLastName': billingLastName,
        'billingPhone': billingPhone,
        'billingEmail': billingEmail,
        'domesticPartners': domesticPartners,
        'stacking': stacking,
        'ichraEoTarget': ichraEoTarget,
        'ichraSpouseTarget': ichraSpouseTarget,
        'ichraChildTarget': ichraChildTarget,
        'preventiveVideoUrl': preventiveVideoUrl,
        'healthVideoUrl': healthVideoUrl,
        'ichraVideoUrl': ichraVideoUrl,
        'dentalVideoUrl': dentalVideoUrl,
        'preventiveDescription': preventiveDescription,
        'healthDescription': healthDescription,
        'ichraDescription': ichraDescription,
        'dentalDescription': dentalDescription,
        'notes': notes,
      };

  factory GroupDetails.fromMap(Map<String, dynamic>? m) {
    m ??= {};
    String s(String k) => (m![k] ?? '') as String;
    num n(String k) => (m![k] ?? 0) as num;
    bool b(String k) => (m![k] ?? false) as bool;
    return GroupDetails(
      dba: s('dba'),
      effectiveDate: s('effectiveDate'),
      startDate: s('startDate'),
      affiliateCompany: s('affiliateCompany'),
      affiliateEmail: s('affiliateEmail'),
      producer: s('producer'),
      referralPartner: s('referralPartner'),
      referer: s('referer'),
      refererName: s('refererName'),
      eligibilityDefinition: s('eligibilityDefinition'),
      waitingPeriod: WaitingPeriod.values.firstWhere(
        (w) => w.name == m!['waitingPeriod'],
        orElse: () => WaitingPeriod.firstFollowingHire,
      ),
      waitingPeriodOther: s('waitingPeriodOther'),
      taxId: s('taxId'),
      businessPhone: s('businessPhone'),
      website: s('website'),
      fullTimeEmployees: s('fullTimeEmployees'),
      addressLine1: s('addressLine1'),
      addressLine2: s('addressLine2'),
      city: s('city'),
      state: s('state'),
      zip: s('zip'),
      educationDate: s('educationDate'),
      educationTime: s('educationTime'),
      enrollmentStrategy: s('enrollmentStrategy'),
      adminFirstName: s('adminFirstName'),
      adminLastName: s('adminLastName'),
      adminPhone: s('adminPhone'),
      billingFirstName: s('billingFirstName'),
      billingLastName: s('billingLastName'),
      billingPhone: s('billingPhone'),
      billingEmail: s('billingEmail'),
      domesticPartners: b('domesticPartners'),
      stacking: b('stacking'),
      ichraEoTarget: n('ichraEoTarget'),
      ichraSpouseTarget: n('ichraSpouseTarget'),
      ichraChildTarget: n('ichraChildTarget'),
      preventiveVideoUrl: s('preventiveVideoUrl'),
      healthVideoUrl: s('healthVideoUrl'),
      ichraVideoUrl: s('ichraVideoUrl'),
      dentalVideoUrl: s('dentalVideoUrl'),
      preventiveDescription: s('preventiveDescription'),
      healthDescription: s('healthDescription'),
      ichraDescription: s('ichraDescription'),
      dentalDescription: s('dentalDescription'),
      notes: s('notes'),
    );
  }
}

class Group {
  final String? id;
  final String name; // employer / group name
  final String contactEmail; // admin "from" email (HAS form)
  final bool ichraEnabled;

  /// Monthly surcharge added per tobacco user (default $75).
  final num tobaccoSurcharge;

  /// Who pays the tobacco surcharge (company = hidden from the employee but
  /// still recorded for the deduction report).
  final TobaccoSurchargePayer tobaccoSurchargePayer;

  /// Extra HAS Group Enrollment Form fields.
  final GroupDetails details;

  /// How medical pricing is defined for this group.
  final ContributionMode contributionMode;

  /// Which deductible levels are offered (OPTION 1 per-level toggles).
  final List<String> offeredLevels;

  /// Defined-contribution (age-banded) config (OPTION 2).
  final DefinedContribution definedContribution;

  /// Payroll frequency, drives the per-pay-period deduction shown to employees.
  final PayFrequency payFrequency;

  /// Employee-facing medical rates by cooperative level (the contribution
  /// strategy result). Keys are kCoopLevels.
  final Map<String, TierRates> medicalRates;
  final DentalConfig dental;
  final EnrollmentSchedule schedule;
  final MessageTemplates templates;
  final GroupStatus status;
  final DateTime? createdAt;
  final String? createdBy;

  Group({
    this.id,
    required this.name,
    required this.contactEmail,
    this.ichraEnabled = false,
    this.tobaccoSurcharge = 75,
    this.tobaccoSurchargePayer = TobaccoSurchargePayer.company,
    this.details = const GroupDetails(),
    this.contributionMode = ContributionMode.employeeFacing,
    this.offeredLevels = kCoopLevels,
    this.definedContribution = const DefinedContribution(rates: _standardRates),
    this.payFrequency = PayFrequency.monthly,
    required this.medicalRates,
    this.dental = const DentalConfig(),
    this.schedule = const EnrollmentSchedule(),
    this.templates = const MessageTemplates(),
    this.status = GroupStatus.draft,
    this.createdAt,
    this.createdBy,
  });

  factory Group.empty() => Group(
        name: '',
        contactEmail: '',
        medicalRates: {for (final l in kCoopLevels) l: const TierRates()},
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'contactEmail': contactEmail,
        'ichraEnabled': ichraEnabled,
        'tobaccoSurcharge': tobaccoSurcharge,
        'tobaccoSurchargePayer': tobaccoSurchargePayer.name,
        'details': details.toMap(),
        'contributionMode': contributionMode.name,
        'offeredLevels': offeredLevels,
        'definedContribution': definedContribution.toMap(),
        'payFrequency': payFrequency.name,
        'medicalRates': {
          for (final entry in medicalRates.entries) entry.key: entry.value.toMap()
        },
        'dental': dental.toMap(),
        'enrollment': schedule.toMap(),
        'templates': templates.toMap(),
        'status': status.name,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    final rawRates = (m['medicalRates'] as Map<String, dynamic>?) ?? {};
    return Group(
      id: doc.id,
      name: (m['name'] ?? '') as String,
      contactEmail: (m['contactEmail'] ?? '') as String,
      ichraEnabled: (m['ichraEnabled'] ?? false) as bool,
      tobaccoSurcharge: (m['tobaccoSurcharge'] ?? 75) as num,
      tobaccoSurchargePayer: TobaccoSurchargePayer.values.firstWhere(
        (p) => p.name == m['tobaccoSurchargePayer'],
        orElse: () => TobaccoSurchargePayer.company,
      ),
      details: GroupDetails.fromMap(m['details'] as Map<String, dynamic>?),
      contributionMode: ContributionMode.values.firstWhere(
        (c) => c.name == m['contributionMode'],
        orElse: () => ContributionMode.employeeFacing,
      ),
      offeredLevels: (m['offeredLevels'] as List?)?.cast<String>() ?? kCoopLevels,
      definedContribution:
          DefinedContribution.fromMap(m['definedContribution'] as Map<String, dynamic>?),
      payFrequency: PayFrequency.values.firstWhere(
        (p) => p.name == m['payFrequency'],
        orElse: () => PayFrequency.monthly,
      ),
      medicalRates: {
        for (final l in kCoopLevels)
          l: TierRates.fromMap(rawRates[l] as Map<String, dynamic>?)
      },
      dental: DentalConfig.fromMap(m['dental'] as Map<String, dynamic>?),
      schedule: EnrollmentSchedule.fromMap(m['enrollment'] as Map<String, dynamic>?),
      templates: MessageTemplates.fromMap(m['templates'] as Map<String, dynamic>?),
      status: GroupStatus.values.firstWhere(
        (s) => s.name == m['status'],
        orElse: () => GroupStatus.draft,
      ),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      createdBy: m['createdBy'] as String?,
    );
  }

  Group copyWith({
    String? name,
    String? contactEmail,
    bool? ichraEnabled,
    num? tobaccoSurcharge,
    TobaccoSurchargePayer? tobaccoSurchargePayer,
    GroupDetails? details,
    ContributionMode? contributionMode,
    List<String>? offeredLevels,
    DefinedContribution? definedContribution,
    PayFrequency? payFrequency,
    Map<String, TierRates>? medicalRates,
    DentalConfig? dental,
    EnrollmentSchedule? schedule,
    MessageTemplates? templates,
    GroupStatus? status,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        contactEmail: contactEmail ?? this.contactEmail,
        ichraEnabled: ichraEnabled ?? this.ichraEnabled,
        tobaccoSurcharge: tobaccoSurcharge ?? this.tobaccoSurcharge,
        tobaccoSurchargePayer: tobaccoSurchargePayer ?? this.tobaccoSurchargePayer,
        details: details ?? this.details,
        contributionMode: contributionMode ?? this.contributionMode,
        offeredLevels: offeredLevels ?? this.offeredLevels,
        definedContribution: definedContribution ?? this.definedContribution,
        payFrequency: payFrequency ?? this.payFrequency,
        medicalRates: medicalRates ?? this.medicalRates,
        dental: dental ?? this.dental,
        schedule: schedule ?? this.schedule,
        templates: templates ?? this.templates,
        status: status ?? this.status,
        createdAt: createdAt,
        createdBy: createdBy,
      );
}
