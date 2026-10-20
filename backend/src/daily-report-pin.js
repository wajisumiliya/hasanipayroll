// Preserve leading zeroes: PINs are four ASCII digits, never numbers.
export function isDailyReportPin(value) {
  return typeof value === 'string' && /^[0-9]{4}$/.test(value);
}
