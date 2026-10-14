import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Generated CLDR tables are loaded synchronously before the returned future is
// completed, so these sync formatters can safely use explicit locales.
bool _dateSymbolsLoaded = false;

void _ensureDateSymbols() {
  if (_dateSymbolsLoaded) return;
  initializeDateFormatting();
  _dateSymbolsLoaded = true;
}

/// Resolves user-entered formatting locale without changing Intl's process-wide
/// default. Date and number formats use the same available locale.
String formattingLocale(String? requested) {
  _ensureDateSymbols();
  final value = requested?.trim();
  if (value == null || value.isEmpty) return 'en';
  try {
    final canonical = Intl.canonicalizedLocale(value);
    if (NumberFormat.localeExists(canonical) &&
        DateFormat.localeExists(canonical)) {
      return canonical;
    }
    final language = canonical.split('_').first;
    if (NumberFormat.localeExists(language) &&
        DateFormat.localeExists(language)) {
      return language;
    }
  } on ArgumentError {
    return 'en';
  }
  return 'en';
}

String formatCount(int? value, {String? locale}) {
  if (value == null || value < 0) return '—';
  return NumberFormat.decimalPattern(formattingLocale(locale)).format(value);
}

String formatBytes(int? value, {String? locale}) {
  if (value == null || value < 0) return '—';
  final resolvedLocale = formattingLocale(locale);
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var amount = value.toDouble();
  var unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  if (unit == 0) {
    return '${NumberFormat.decimalPattern(resolvedLocale).format(value)} B';
  }
  final number = NumberFormat.decimalPatternDigits(
    locale: resolvedLocale,
    decimalDigits: 1,
  ).format(amount);
  return '$number ${units[unit]}';
}

String formatRate(int bytesPerSecond, {String? locale}) =>
    '${formatBytes(bytesPerSecond, locale: locale)}/s';

String formatDate(DateTime value, {String? locale}) =>
    DateFormat.yMMMd(formattingLocale(locale)).format(value.toLocal());

String formatDateTime(DateTime value, {String? locale}) =>
    DateFormat.yMMMd(formattingLocale(locale)).add_jm().format(value.toLocal());
