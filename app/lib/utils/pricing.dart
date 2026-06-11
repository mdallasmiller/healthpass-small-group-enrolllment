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

/// Monthly dental rate for a tier, from the group's dental config.
num dentalMonthly(Group group, Tier tier) {
  if (!group.dental.enabled) return 0;
  return group.dental.rates.forTier(tier);
}

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
