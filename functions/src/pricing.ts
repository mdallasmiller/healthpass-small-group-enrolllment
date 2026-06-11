/**
 * Pricing engine — ported from the HealthPass rate spreadsheet.
 *
 * Enrollment uses 3 employee-facing tiers (per the enrollment outline):
 *   - employeeOnly
 *   - spouseChild   (Employee + Spouse/Child(ren))
 *   - family        (Employee + Family)
 *
 * Rates are entered per group by the admin, keyed by cooperative level
 * (deductible: 1000 / 2500 / 4000). The engine just selects + sums; the
 * numbers always come from the group's configuration, never hardcoded.
 */

export type Tier = "employeeOnly" | "spouseChild" | "family";
export type CooperativeLevel = "1000" | "2500" | "4000";

export interface TierRates {
  employeeOnly: number;
  spouseChild: number;
  family: number;
}

/** medicalRates[level] -> TierRates */
export type RateTable = Record<CooperativeLevel, TierRates>;

/**
 * Determine the tier from the dependents the employee added.
 *   none                  -> employeeOnly
 *   spouse OR children    -> spouseChild
 *   spouse AND children   -> family
 */
export function determineTier(hasSpouse: boolean, childrenCount: number): Tier {
  const hasChildren = childrenCount > 0;
  if (hasSpouse && hasChildren) return "family";
  if (hasSpouse || hasChildren) return "spouseChild";
  return "employeeOnly";
}

/** Look up a single monthly rate for a tier at a cooperative level. */
export function monthlyRate(rates: RateTable, level: CooperativeLevel, tier: Tier): number {
  const row = rates[level];
  if (!row) throw new Error(`No rates for cooperative level ${level}`);
  return row[tier];
}

export interface QuoteInput {
  medicalRates: RateTable;
  medicalLevel: CooperativeLevel;
  hasSpouse: boolean;
  childrenCount: number;
  medicalPlan: "preventiveOnly" | "preventiveCooperative";
  dental?: {
    enrolled: boolean;
    level: CooperativeLevel;
    rates: RateTable;
    // dental can cover a different dependent set than medical
    hasSpouse?: boolean;
    childrenCount?: number;
  };
}

export interface QuoteResult {
  tier: Tier;
  medicalMonthly: number;
  dentalMonthly: number;
  employeeMonthlyCost: number;
}

/**
 * Compute the live employee-facing monthly cost.
 * Preventive-only has no cooperative medical premium (EAP/preventive is provided);
 * Preventive + Cooperative adds the medical rate for the tier.
 */
export function computeQuote(input: QuoteInput): QuoteResult {
  const tier = determineTier(input.hasSpouse, input.childrenCount);

  const medicalMonthly =
    input.medicalPlan === "preventiveCooperative"
      ? monthlyRate(input.medicalRates, input.medicalLevel, tier)
      : 0;

  let dentalMonthly = 0;
  if (input.dental?.enrolled) {
    const dTier = determineTier(
      input.dental.hasSpouse ?? input.hasSpouse,
      input.dental.childrenCount ?? input.childrenCount
    );
    dentalMonthly = monthlyRate(input.dental.rates, input.dental.level, dTier);
  }

  return {
    tier,
    medicalMonthly,
    dentalMonthly,
    employeeMonthlyCost: medicalMonthly + dentalMonthly,
  };
}
