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
