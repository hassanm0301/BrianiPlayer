// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'discovery_result.g.dart';

/// DiscoveryResult
///
/// Properties:
/// * [id] 
/// * [title] 
/// * [sizeBytes] 
/// * [seeders] 
/// * [leechers] 
/// * [peers] 
/// * [providerId] 
/// * [providerName] 
/// * [publishedAt] 
/// * [fetchedAt] 
/// * [stale] 
/// * [downloadable] 
/// * [categories] 
@BuiltValue()
abstract class DiscoveryResult implements Built<DiscoveryResult, DiscoveryResultBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'title')
  String get title;

  @BuiltValueField(wireName: r'sizeBytes')
  int? get sizeBytes;

  @BuiltValueField(wireName: r'seeders')
  int? get seeders;

  @BuiltValueField(wireName: r'leechers')
  int? get leechers;

  @BuiltValueField(wireName: r'peers')
  int? get peers;

  @BuiltValueField(wireName: r'providerId')
  String get providerId;

  @BuiltValueField(wireName: r'providerName')
  String get providerName;

  @BuiltValueField(wireName: r'publishedAt')
  DateTime? get publishedAt;

  @BuiltValueField(wireName: r'fetchedAt')
  DateTime get fetchedAt;

  @BuiltValueField(wireName: r'stale')
  bool get stale;

  @BuiltValueField(wireName: r'downloadable')
  bool get downloadable;

  @BuiltValueField(wireName: r'categories')
  BuiltList<int>? get categories;

  DiscoveryResult._();

  factory DiscoveryResult([void updates(DiscoveryResultBuilder b)]) = _$DiscoveryResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DiscoveryResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DiscoveryResult> get serializer => _$DiscoveryResultSerializer();
}

class _$DiscoveryResultSerializer implements PrimitiveSerializer<DiscoveryResult> {
  @override
  final Iterable<Type> types = const [DiscoveryResult, _$DiscoveryResult];

  @override
  final String wireName = r'DiscoveryResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DiscoveryResult object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'title';
    yield serializers.serialize(
      object.title,
      specifiedType: const FullType(String),
    );
    yield r'sizeBytes';
    yield object.sizeBytes == null ? null : serializers.serialize(
      object.sizeBytes,
      specifiedType: const FullType.nullable(int),
    );
    yield r'seeders';
    yield object.seeders == null ? null : serializers.serialize(
      object.seeders,
      specifiedType: const FullType.nullable(int),
    );
    yield r'leechers';
    yield object.leechers == null ? null : serializers.serialize(
      object.leechers,
      specifiedType: const FullType.nullable(int),
    );
    yield r'peers';
    yield object.peers == null ? null : serializers.serialize(
      object.peers,
      specifiedType: const FullType.nullable(int),
    );
    yield r'providerId';
    yield serializers.serialize(
      object.providerId,
      specifiedType: const FullType(String),
    );
    yield r'providerName';
    yield serializers.serialize(
      object.providerName,
      specifiedType: const FullType(String),
    );
    yield r'publishedAt';
    yield object.publishedAt == null ? null : serializers.serialize(
      object.publishedAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'fetchedAt';
    yield serializers.serialize(
      object.fetchedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'stale';
    yield serializers.serialize(
      object.stale,
      specifiedType: const FullType(bool),
    );
    yield r'downloadable';
    yield serializers.serialize(
      object.downloadable,
      specifiedType: const FullType(bool),
    );
    if (object.categories != null) {
      yield r'categories';
      yield serializers.serialize(
        object.categories,
        specifiedType: const FullType(BuiltList, [FullType(int)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    DiscoveryResult object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DiscoveryResultBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'title':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.title = valueDes;
          break;
        case r'sizeBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.sizeBytes = valueDes;
          break;
        case r'seeders':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.seeders = valueDes;
          break;
        case r'leechers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.leechers = valueDes;
          break;
        case r'peers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.peers = valueDes;
          break;
        case r'providerId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.providerId = valueDes;
          break;
        case r'providerName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.providerName = valueDes;
          break;
        case r'publishedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.publishedAt = valueDes;
          break;
        case r'fetchedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.fetchedAt = valueDes;
          break;
        case r'stale':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.stale = valueDes;
          break;
        case r'downloadable':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.downloadable = valueDes;
          break;
        case r'categories':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(int)]),
          ) as BuiltList<int>?;
          if (valueDes == null) continue;
          result.categories.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DiscoveryResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DiscoveryResultBuilder();
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


