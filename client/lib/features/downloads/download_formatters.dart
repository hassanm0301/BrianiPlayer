import 'package:intl/intl.dart';

import '../../core/formatting/locale_formatters.dart' as locale_formatters;

String formatCount(int? value, {String? locale}) =>
    locale_formatters.formatCount(value, locale: locale);

String formatBytes(int? value, {String? locale}) =>
    locale_formatters.formatBytes(value, locale: locale);

String formatRate(int bytesPerSecond, {String? locale}) =>
    locale_formatters.formatRate(bytesPerSecond, locale: locale);

String formatEta(int? seconds, {String? locale}) {
  if (seconds == null || seconds < 0) return '—';
  if (seconds < 60) return '${formatCount(seconds, locale: locale)}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '${formatCount(minutes, locale: locale)}m';
  final hours = minutes ~/ 60;
  if (hours < 24) {
    return '${formatCount(hours, locale: locale)}h ${minutes % 60}m';
  }
  return '${formatCount(hours ~/ 24, locale: locale)}d ${hours % 24}h';
}

/// A whole-number percentage such as "42%" for a fraction from 0 to 1.
String formatPercent(double fraction, {String? locale}) =>
    NumberFormat.percentPattern(locale_formatters.formattingLocale(locale))
        .format(fraction.clamp(0.0, 1.0));

/// "3.9 GiB of 9.8 GiB", or only the size once everything has arrived.
/// Unknown sizes stay "—".
String formatProgressBytes(int received, int? total, {String? locale}) {
  if (total != null && total > 0 && received >= total) {
    return formatBytes(total, locale: locale);
  }
  return '${formatBytes(received, locale: locale)} of ${formatBytes(total, locale: locale)}';
}

/// A short relative age ("5m ago", "3h ago", "12d ago") that falls back to a
/// localized date for anything older than a month. Future timestamps from a
/// skewed indexer clock read as "Just now".
String formatAge(DateTime value, {String? locale, DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(value);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) {
    return '${formatCount(elapsed.inMinutes, locale: locale)}m ago';
  }
  if (elapsed.inDays < 1) {
    return '${formatCount(elapsed.inHours, locale: locale)}h ago';
  }
  if (elapsed.inDays < 31) {
    return '${formatCount(elapsed.inDays, locale: locale)}d ago';
  }
  return locale_formatters.formatDate(value, locale: locale);
}

String stateLabel(String value) => switch (value) {
  'metadataPending' => 'Waiting for metadata',
  'awaitingSelection' => 'Choose files',
  'completeSelected' => 'Selected files complete',
  'notReady' => 'Not ready',
  'eligible' => 'Ready to play',
  _ =>
    value.isEmpty
        ? 'Unknown'
        : '${value[0].toUpperCase()}${value.substring(1)}'
              .replaceAllMapped(
                RegExp(r'([a-z])([A-Z])'),
                (m) => '${m[1]} ${m[2]!.toLowerCase()}',
              )
              .replaceAll('_', ' '),
};
