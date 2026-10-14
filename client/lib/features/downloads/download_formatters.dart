import '../../core/formatting/locale_formatters.dart' as locale_formatters;

String formatCount(int? value, {String? locale}) =>
    locale_formatters.formatCount(value, locale: locale);

String formatBytes(int? value, {String? locale}) =>
    locale_formatters.formatBytes(value, locale: locale);

String formatRate(int bytesPerSecond, {String? locale}) =>
    locale_formatters.formatRate(bytesPerSecond, locale: locale);
