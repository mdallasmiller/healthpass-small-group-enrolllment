import '../models/group.dart';

/// Employee-facing pricing, mirroring functions/src/pricing.ts.
///
/// Determine the tier from the dependents the employee added:
///   none                -> employeeOnly
///   spouse OR children  -> spouseChild
///   spouse AND children -> family
Tier determineTier(bool hasSpouse, int childrenCount) {
  final hasChildren = childrenCount > 0;
  if (hasSpouse && hasChildren) return Tier.family;
  if (hasSpouse || hasChildren) return Tier.spouseChild;
  return Tier.employeeOnly;
}

/// Monthly medical rate for a tier at a cooperative level, from the group's
/// configured employee-facing rates. Returns 0 if not configured.
num medicalMonthly(Group group, String level, Tier tier) {
  final rates = group.medicalRates[level];
  if (rates == null) return 0;
  return rates.forTier(tier);
}

/// Four-tier mapping used by dental and defined-contribution rates.
///   none                -> employeeOnly
///   spouse only         -> spouse
///   children only       -> child
///   spouse AND children -> family
Tier4 determineTier4(bool hasSpouse, int childrenCount) {
  final hasChildren = childrenCount > 0;
  if (hasSpouse && hasChildren) return Tier4.family;
  if (hasSpouse) return Tier4.spouse;
  if (hasChildren) return Tier4.child;
  return Tier4.employeeOnly;
}

/// Parses a MM/DD/YYYY date of birth and returns the age in whole years, or
/// null if it can't be parsed.
int? ageFromDob(String dob, {DateTime? asOf}) {
  final now = asOf ?? DateTime.now();
  final m = RegExp(r'^(\d{1,2})[/.](\d{1,2})[/.](\d{4})$').firstMatch(dob.trim());
  if (m == null) return null;
  final month = int.parse(m.group(1)!);
  final day = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  var age = now.year - year;
  if (now.month < month || (now.month == month && now.day < day)) age--;
  return age < 0 ? null : age;
}

/// Defined-contribution gross monthly rate for an age + tier + deductible level.
num definedContributionGross(Group g, int age, Tier4 tier, String level) =>
    g.definedContribution.ratesFor(ageBandFor(age), level).forTier(tier);

/// The employee's monthly payroll deduction under defined contribution: the
/// age-banded gross minus the employer contribution, floored at 0.
num definedContributionDeduction(Group g, int age, Tier4 tier, String level) {
  final gross = definedContributionGross(g, age, tier, level);
  if (gross <= 0) return 0;
  final net = gross - g.definedContribution.employerContribution;
  return net < 0 ? 0 : net;
}

/// Employee's monthly dental cost for a tier (honors Voluntary vs Company
/// Contribution).
num dentalMonthly(Group group, Tier4 tier) {
  if (!group.dental.enabled) return 0;
  return group.dental.employeeCost(tier);
}

/// Converts a monthly amount to one pay period for the group's frequency.
num perPayPeriod(Group g, num monthly) => g.payFrequency.fromMonthly(monthly);

String money(num n) {
  final v = n.round();
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '\$$buf';
}
