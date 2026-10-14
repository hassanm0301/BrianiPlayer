// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'admin_settings.g.dart';

/// Curated administrator settings, not an arbitrary qBittorrent/Prowlarr configuration proxy. Validate deployment-origin policy before accepting publicBaseUrl.
///
/// Properties:
/// * [version] 
/// * [serverName] 
/// * [publicBaseUrl] 
/// * [activeDownloads] 
/// * [activeDownloadsPerUser] 
/// * [activeSeeds] 
/// * [globalConnections] 
/// * [connectionsPerTorrent] 
/// * [downloadLimitBytesPerSecond] 
/// * [uploadLimitBytesPerSecond] 
/// * [defaultRatioLimit] 
/// * [defaultSeedTimeMinutes] 
/// * [defaultUserQuotaBytes] 
/// * [lowDiskFloorBytes] 
/// * [lowDiskFloorFraction] 
/// * [thumbnailCacheMaxBytes] 
/// * [auditRetentionDays] 
/// * [enabledProviderIds] 
/// * [enabledCategoryIds] 
/// * [libraryScanIntervalSeconds] 
/// * [discoveryCacheSeconds] 
/// * [discoveryRecentRefreshSeconds] 
@BuiltValue()
abstract class AdminSettings implements Built<AdminSettings, AdminSettingsBuilder> {
  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'serverName')
  String? get serverName;

  @BuiltValueField(wireName: r'publicBaseUrl')
  String? get publicBaseUrl;

  @BuiltValueField(wireName: r'activeDownloads')
  int? get activeDownloads;

  @BuiltValueField(wireName: r'activeDownloadsPerUser')
  int? get activeDownloadsPerUser;

  @BuiltValueField(wireName: r'activeSeeds')
  int? get activeSeeds;

  @BuiltValueField(wireName: r'globalConnections')
  int? get globalConnections;

  @BuiltValueField(wireName: r'connectionsPerTorrent')
  int? get connectionsPerTorrent;

  @BuiltValueField(wireName: r'downloadLimitBytesPerSecond')
  int? get downloadLimitBytesPerSecond;

  @BuiltValueField(wireName: r'uploadLimitBytesPerSecond')
  int? get uploadLimitBytesPerSecond;

  @BuiltValueField(wireName: r'defaultRatioLimit')
  double? get defaultRatioLimit;

  @BuiltValueField(wireName: r'defaultSeedTimeMinutes')
  int? get defaultSeedTimeMinutes;

  @BuiltValueField(wireName: r'defaultUserQuotaBytes')
  int? get defaultUserQuotaBytes;

  @BuiltValueField(wireName: r'lowDiskFloorBytes')
  int? get lowDiskFloorBytes;

  @BuiltValueField(wireName: r'lowDiskFloorFraction')
  double? get lowDiskFloorFraction;

  @BuiltValueField(wireName: r'thumbnailCacheMaxBytes')
  int? get thumbnailCacheMaxBytes;

  @BuiltValueField(wireName: r'auditRetentionDays')
  int? get auditRetentionDays;

  @BuiltValueField(wireName: r'enabledProviderIds')
  BuiltList<String>? get enabledProviderIds;

  @BuiltValueField(wireName: r'enabledCategoryIds')
  BuiltList<int>? get enabledCategoryIds;

  @BuiltValueField(wireName: r'libraryScanIntervalSeconds')
  int? get libraryScanIntervalSeconds;

  @BuiltValueField(wireName: r'discoveryCacheSeconds')
  int? get discoveryCacheSeconds;

  @BuiltValueField(wireName: r'discoveryRecentRefreshSeconds')
  int? get discoveryRecentRefreshSeconds;

  AdminSettings._();

  factory AdminSettings([void updates(AdminSettingsBuilder b)]) = _$AdminSettings;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AdminSettingsBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AdminSettings> get serializer => _$AdminSettingsSerializer();
}

class _$AdminSettingsSerializer implements PrimitiveSerializer<AdminSettings> {
  @override
  final Iterable<Type> types = const [AdminSettings, _$AdminSettings];

  @override
  final String wireName = r'AdminSettings';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AdminSettings object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
    if (object.serverName != null) {
      yield r'serverName';
      yield serializers.serialize(
        object.serverName,
        specifiedType: const FullType(String),
      );
    }
    if (object.publicBaseUrl != null) {
      yield r'publicBaseUrl';
      yield serializers.serialize(
        object.publicBaseUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.activeDownloads != null) {
      yield r'activeDownloads';
      yield serializers.serialize(
        object.activeDownloads,
        specifiedType: const FullType(int),
      );
    }
    if (object.activeDownloadsPerUser != null) {
      yield r'activeDownloadsPerUser';
      yield serializers.serialize(
        object.activeDownloadsPerUser,
        specifiedType: const FullType(int),
      );
    }
    if (object.activeSeeds != null) {
      yield r'activeSeeds';
      yield serializers.serialize(
        object.activeSeeds,
        specifiedType: const FullType(int),
      );
    }
    if (object.globalConnections != null) {
      yield r'globalConnections';
      yield serializers.serialize(
        object.globalConnections,
        specifiedType: const FullType(int),
      );
    }
    if (object.connectionsPerTorrent != null) {
      yield r'connectionsPerTorrent';
      yield serializers.serialize(
        object.connectionsPerTorrent,
        specifiedType: const FullType(int),
      );
    }
    if (object.downloadLimitBytesPerSecond != null) {
      yield r'downloadLimitBytesPerSecond';
      yield serializers.serialize(
        object.downloadLimitBytesPerSecond,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.uploadLimitBytesPerSecond != null) {
      yield r'uploadLimitBytesPerSecond';
      yield serializers.serialize(
        object.uploadLimitBytesPerSecond,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.defaultRatioLimit != null) {
      yield r'defaultRatioLimit';
      yield serializers.serialize(
        object.defaultRatioLimit,
        specifiedType: const FullType.nullable(double),
      );
    }
    if (object.defaultSeedTimeMinutes != null) {
      yield r'defaultSeedTimeMinutes';
      yield serializers.serialize(
        object.defaultSeedTimeMinutes,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.defaultUserQuotaBytes != null) {
      yield r'defaultUserQuotaBytes';
      yield serializers.serialize(
        object.defaultUserQuotaBytes,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.lowDiskFloorBytes != null) {
      yield r'lowDiskFloorBytes';
      yield serializers.serialize(
        object.lowDiskFloorBytes,
        specifiedType: const FullType(int),
      );
    }
    if (object.lowDiskFloorFraction != null) {
      yield r'lowDiskFloorFraction';
      yield serializers.serialize(
        object.lowDiskFloorFraction,
        specifiedType: const FullType(double),
      );
    }
    if (object.thumbnailCacheMaxBytes != null) {
      yield r'thumbnailCacheMaxBytes';
      yield serializers.serialize(
        object.thumbnailCacheMaxBytes,
        specifiedType: const FullType(int),
      );
    }
    if (object.auditRetentionDays != null) {
      yield r'auditRetentionDays';
      yield serializers.serialize(
        object.auditRetentionDays,
        specifiedType: const FullType(int),
      );
    }
    if (object.enabledProviderIds != null) {
      yield r'enabledProviderIds';
      yield serializers.serialize(
        object.enabledProviderIds,
        specifiedType: const FullType.nullable(BuiltList, [FullType(String)]),
      );
    }
    if (object.enabledCategoryIds != null) {
      yield r'enabledCategoryIds';
      yield serializers.serialize(
        object.enabledCategoryIds,
        specifiedType: const FullType.nullable(BuiltList, [FullType(int)]),
      );
    }
    if (object.libraryScanIntervalSeconds != null) {
      yield r'libraryScanIntervalSeconds';
      yield serializers.serialize(
        object.libraryScanIntervalSeconds,
        specifiedType: const FullType(int),
      );
    }
    if (object.discoveryCacheSeconds != null) {
      yield r'discoveryCacheSeconds';
      yield serializers.serialize(
        object.discoveryCacheSeconds,
        specifiedType: const FullType(int),
      );
    }
    if (object.discoveryRecentRefreshSeconds != null) {
      yield r'discoveryRecentRefreshSeconds';
      yield serializers.serialize(
        object.discoveryRecentRefreshSeconds,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    AdminSettings object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AdminSettingsBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        case r'serverName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.serverName = valueDes;
          break;
        case r'publicBaseUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.publicBaseUrl = valueDes;
          break;
        case r'activeDownloads':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.activeDownloads = valueDes;
          break;
        case r'activeDownloadsPerUser':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.activeDownloadsPerUser = valueDes;
          break;
        case r'activeSeeds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.activeSeeds = valueDes;
          break;
        case r'globalConnections':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.globalConnections = valueDes;
          break;
        case r'connectionsPerTorrent':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.connectionsPerTorrent = valueDes;
          break;
        case r'downloadLimitBytesPerSecond':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.downloadLimitBytesPerSecond = valueDes;
          break;
        case r'uploadLimitBytesPerSecond':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.uploadLimitBytesPerSecond = valueDes;
          break;
        case r'defaultRatioLimit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(double),
          ) as double?;
          if (valueDes == null) continue;
          result.defaultRatioLimit = valueDes;
          break;
        case r'defaultSeedTimeMinutes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.defaultSeedTimeMinutes = valueDes;
          break;
        case r'defaultUserQuotaBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.defaultUserQuotaBytes = valueDes;
          break;
        case r'lowDiskFloorBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.lowDiskFloorBytes = valueDes;
          break;
        case r'lowDiskFloorFraction':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(double),
          ) as double?;
          if (valueDes == null) continue;
          result.lowDiskFloorFraction = valueDes;
          break;
        case r'thumbnailCacheMaxBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.thumbnailCacheMaxBytes = valueDes;
          break;
        case r'auditRetentionDays':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.auditRetentionDays = valueDes;
          break;
        case r'enabledProviderIds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(String)]),
          ) as BuiltList<String>?;
          if (valueDes == null) continue;
          result.enabledProviderIds.replace(valueDes);
          break;
        case r'enabledCategoryIds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(int)]),
          ) as BuiltList<int>?;
          if (valueDes == null) continue;
          result.enabledCategoryIds.replace(valueDes);
          break;
        case r'libraryScanIntervalSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.libraryScanIntervalSeconds = valueDes;
          break;
        case r'discoveryCacheSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.discoveryCacheSeconds = valueDes;
          break;
        case r'discoveryRecentRefreshSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.discoveryRecentRefreshSeconds = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AdminSettings deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AdminSettingsBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


