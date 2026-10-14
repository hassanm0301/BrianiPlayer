// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_settings.g.dart';

/// DownloadSettings
///
/// Properties:
/// * [version] 
/// * [downloadLimitBytesPerSecond] 
/// * [uploadLimitBytesPerSecond] 
/// * [ratioLimit] 
/// * [seedTimeMinutes] 
/// * [queuePosition] 
/// * [tags] 
@BuiltValue()
abstract class DownloadSettings implements Built<DownloadSettings, DownloadSettingsBuilder> {
  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'downloadLimitBytesPerSecond')
  int? get downloadLimitBytesPerSecond;

  @BuiltValueField(wireName: r'uploadLimitBytesPerSecond')
  int? get uploadLimitBytesPerSecond;

  @BuiltValueField(wireName: r'ratioLimit')
  double? get ratioLimit;

  @BuiltValueField(wireName: r'seedTimeMinutes')
  int? get seedTimeMinutes;

  @BuiltValueField(wireName: r'queuePosition')
  int? get queuePosition;

  @BuiltValueField(wireName: r'tags')
  BuiltList<String>? get tags;

  DownloadSettings._();

  factory DownloadSettings([void updates(DownloadSettingsBuilder b)]) = _$DownloadSettings;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadSettingsBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadSettings> get serializer => _$DownloadSettingsSerializer();
}

class _$DownloadSettingsSerializer implements PrimitiveSerializer<DownloadSettings> {
  @override
  final Iterable<Type> types = const [DownloadSettings, _$DownloadSettings];

  @override
  final String wireName = r'DownloadSettings';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadSettings object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
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
    if (object.ratioLimit != null) {
      yield r'ratioLimit';
      yield serializers.serialize(
        object.ratioLimit,
        specifiedType: const FullType.nullable(double),
      );
    }
    if (object.seedTimeMinutes != null) {
      yield r'seedTimeMinutes';
      yield serializers.serialize(
        object.seedTimeMinutes,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.queuePosition != null) {
      yield r'queuePosition';
      yield serializers.serialize(
        object.queuePosition,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.tags != null) {
      yield r'tags';
      yield serializers.serialize(
        object.tags,
        specifiedType: const FullType(BuiltList, [FullType(String)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    DownloadSettings object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadSettingsBuilder result,
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
        case r'ratioLimit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(double),
          ) as double?;
          if (valueDes == null) continue;
          result.ratioLimit = valueDes;
          break;
        case r'seedTimeMinutes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.seedTimeMinutes = valueDes;
          break;
        case r'queuePosition':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.queuePosition = valueDes;
          break;
        case r'tags':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(String)]),
          ) as BuiltList<String>?;
          if (valueDes == null) continue;
          result.tags.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DownloadSettings deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadSettingsBuilder();
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


