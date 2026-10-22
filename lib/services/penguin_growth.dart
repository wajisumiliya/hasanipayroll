/// Completed days since hatching. Matches adulthood at adoption day 45:
/// three days in the egg, then 42 days of gradual growth.
double penguinGrowthScale(int daysSinceHatch) {
  final days = daysSinceHatch.clamp(0, 42);
  return .30 + .70 * days / 42;
}
