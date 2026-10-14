import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:briani_player/core/formatting/locale_formatters.dart';

void main() {
  group('locale-aware display formatting', () {
    test('formats counts and byte values using an explicit locale', () {
      expect(formatCount(1234567, locale: 'de-DE'), '1.234.567');
      expect(formatBytes(1536, locale: 'de-DE'), '1,5 KiB');
      expect(formatBytes(1536), '1.5 KiB');
      expect(formatRate(1536, locale: 'fr-FR'), '1,5 KiB/s');
    });

    test('formats dates with explicit regional patterns', () {
      final date = DateTime.utc(2025, 2, 3, 16, 5);
      expect(formatDate(date, locale: 'en-US'), 'Feb 3, 2025');
      expect(formatDate(date, locale: 'de-DE'), '3. Feb. 2025');
      expect(
        formatDateTime(date, locale: 'en-US'),
        DateFormat.yMMMd('en_US').add_jm().format(date.toLocal()),
      );
    });

    test(
      'invalid and unsupported locales fall back without global mutation',
      () {
        final previousDefault = Intl.defaultLocale;
        expect(formatCount(1234567, locale: 'xx_YY'), '1,234,567');
        expect(
          formatDate(DateTime.utc(2025, 2, 3), locale: 'not a locale'),
          'Feb 3, 2025',
        );
        expect(Intl.defaultLocale, previousDefault);
      },
    );

    test('unknown and negative values retain the unknown marker', () {
      expect(formatCount(null, locale: 'de-DE'), '—');
      expect(formatCount(-1, locale: 'de-DE'), '—');
      expect(formatBytes(null, locale: 'de-DE'), '—');
      expect(formatBytes(-1, locale: 'de-DE'), '—');
    });
  });
}
