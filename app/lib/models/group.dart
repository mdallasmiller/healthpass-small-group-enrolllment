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

enum DentalOption { cooperative, selfFundedBento }

extension DentalOptionLabel on DentalOption {
  String get label => switch (this) {
        DentalOption.cooperative => 'Cooperative',
        DentalOption.selfFundedBento => 'Self-Funded Bento',
      };
  String get key => name;
}

class DentalConfig {
  final bool enabled;
  final DentalOption option;
  final String level; // cooperative auto-fills '2500'
  final TierRates rates;

  const DentalConfig({
    this.enabled = false,
    this.option = DentalOption.cooperative,
    this.level = '2500',
    this.rates = const TierRates(),
  });

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'option': option.key,
        'level': level,
        'rates': rates.toMap(),
      };

  factory DentalConfig.fromMap(Map<String, dynamic>? m) => DentalConfig(
        enabled: (m?['enabled'] ?? false) as bool,
        option: DentalOption.values.firstWhere(
          (o) => o.key == m?['option'],
          orElse: () => DentalOption.cooperative,
        ),
        level: (m?['level'] ?? '2500') as String,
        rates: TierRates.fromMap(m?['rates'] as Map<String, dynamic>?),
      );

  DentalConfig copyWith({
    bool? enabled,
    DentalOption? option,
    String? level,
    TierRates? rates,
  }) =>
      DentalConfig(
        enabled: enabled ?? this.enabled,
        option: option ?? this.option,
        level: level ?? this.level,
        rates: rates ?? this.rates,
      );
}

enum GroupStatus { draft, active, closed }

class Group {
  final String? id;
  final String name; // employer / group name
  final String contactEmail; // admin "from" email (HAS form)
  final bool ichraEnabled;

  /// Employee-facing medical rates by cooperative level (the contribution
  /// strategy result). Keys are kCoopLevels.
  final Map<String, TierRates> medicalRates;
  final DentalConfig dental;
  final GroupStatus status;
  final DateTime? createdAt;
  final String? createdBy;

  Group({
    this.id,
    required this.name,
    required this.contactEmail,
    this.ichraEnabled = false,
    required this.medicalRates,
    this.dental = const DentalConfig(),
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
        'medicalRates': {
          for (final entry in medicalRates.entries) entry.key: entry.value.toMap()
        },
        'dental': dental.toMap(),
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
      medicalRates: {
        for (final l in kCoopLevels)
          l: TierRates.fromMap(rawRates[l] as Map<String, dynamic>?)
      },
      dental: DentalConfig.fromMap(m['dental'] as Map<String, dynamic>?),
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
    Map<String, TierRates>? medicalRates,
    DentalConfig? dental,
    GroupStatus? status,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        contactEmail: contactEmail ?? this.contactEmail,
        ichraEnabled: ichraEnabled ?? this.ichraEnabled,
        medicalRates: medicalRates ?? this.medicalRates,
        dental: dental ?? this.dental,
        status: status ?? this.status,
        createdAt: createdAt,
        createdBy: createdBy,
      );
}
