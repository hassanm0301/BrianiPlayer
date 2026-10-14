import 'package:briani_api/briani_api.dart';
import 'package:built_value/serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'discovery stats remain null and media sizes retain 64-bit byte counts',
    () {
      final serializers = standardSerializers;
      final result =
          serializers.deserialize({
                'id': 'result-1',
                'title': 'Example release',
                'providerId': 'provider-1',
                'providerName': 'Example',
                'fetchedAt': '2026-10-12T00:00:00Z',
                'stale': false,
                'downloadable': true,
                'seeders': null,
                'leechers': null,
              }, specifiedType: const FullType(DiscoveryResult))!
              as DiscoveryResult;
      final media =
          serializers.deserialize({
                'id': 'media-1',
                'libraryId': 'library-1',
                'entryId': 'entry-1',
                'name': 'large-video.mkv',
                'kind': 'video',
                'mimeType': 'video/x-matroska',
                'sizeBytes': 5 * 1024 * 1024 * 1024 + 17,
                'complete': true,
                'probeState': 'ready',
                'version': 1,
              }, specifiedType: const FullType(Media))!
              as Media;

      expect(result.seeders, isNull);
      expect(result.leechers, isNull);
      expect(media.sizeBytes, 5 * 1024 * 1024 * 1024 + 17);
    },
  );
}
