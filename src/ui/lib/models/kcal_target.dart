import 'models.dart';

class KcalTarget {
  final int target;
  final int? recommended;
  final bool fromPlan;
  const KcalTarget({required this.target, this.recommended, required this.fromPlan});
}

KcalTarget kcalTargetOf(AppUser user, Plan? plan, int weekday) {
  final formula = user.targetKcal;
  final planKcal = plan != null && user.fitsPlan(plan) ? plan.kcalFor(weekday).round() : 0;
  if (planKcal > 0) {
    return KcalTarget(
      target: planKcal,
      recommended: formula > 0 && formula != planKcal ? formula : null,
      fromPlan: true,
    );
  }
  return KcalTarget(target: formula, fromPlan: false);
}
