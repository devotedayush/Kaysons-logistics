/// Shared formatting and validation rules used by operational workflow forms.
///
/// The database column is still named `weight_kg` for compatibility, but the
/// product and all operational screens treat that value as metric tonnes.
String format12HourTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

String formatMetricTons(Object? value, {int maxDecimalPlaces = 3}) {
  final number = switch (value) {
    num v => v.toDouble(),
    _ => double.tryParse(value?.toString() ?? ''),
  };
  if (number == null || !number.isFinite) return '0';
  final normalized = number.abs() < 0.0000001 ? 0 : number;
  final decimals = maxDecimalPlaces < 0 ? 0 : maxDecimalPlaces;
  // Do not run the trailing-zero cleanup against an integer string.  For
  // example, `1000.toStringAsFixed(0)` is `1000`, where the old regex turned
  // it into `1`.
  if (decimals == 0) return normalized.toStringAsFixed(0);
  final fixed = normalized.toStringAsFixed(decimals);
  return fixed
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceFirst(RegExp(r'^-0$'), '0');
}

/// Returns the canonical database representation for an Indian mobile number.
///
/// Input may contain spaces, punctuation, or a +91/91 prefix. A local number
/// must start with 6–9, which excludes placeholders such as 0000000000 and
/// malformed numbers that happen to contain ten digits.
String? normalizeIndianPhone(String raw) {
  final trimmed = raw.trim();
  // Strip only display punctuation.  Silently dropping letters would turn
  // values such as `abc9876543210` into a valid number and hide input errors.
  if (trimmed.isEmpty || RegExp(r'[^0-9\s()+-]').hasMatch(trimmed)) {
    return null;
  }
  if (trimmed.contains('+') &&
      (!trimmed.startsWith('+') ||
          trimmed.indexOf('+') != trimmed.lastIndexOf('+'))) {
    return null;
  }
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('91') && digits.length == 12) {
    digits = digits.substring(2);
  }
  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return null;
  if (RegExp(r'^(\d)\1{9}$').hasMatch(digits)) return null;
  return '+91$digits';
}

bool isValidIndianPhone(String raw) => normalizeIndianPhone(raw) != null;

/// The report views aggregate only these charge kinds. Keep write paths on the
/// same vocabulary so operational charges appear in the ledger.
String canonicalChargeKind(String kind) {
  switch (kind.trim().toLowerCase()) {
    case 'toll':
    case 'toll tax':
    case 'toll_tax':
      return 'toll_tax';
    case 'club':
    case 'dalla':
    case 'point charge':
    case 'point_charge':
      return 'point_charge';
    case 'freight':
      return 'freight';
    case 'extra freight':
    case 'extra_freight':
      return 'extra_freight';
    case 'labour':
    case 'labor':
      return 'labour';
    case 'detention':
      return 'detention';
    case 'out route':
    case 'out_route':
      return 'out_route';
    case 'deduction':
      return 'deduction';
    default:
      return 'other';
  }
}
