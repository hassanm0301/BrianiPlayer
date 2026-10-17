// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'indexer_create.g.dart';

/// IndexerCreate
///
/// Properties:
/// * [definition] 
/// * [name] 
/// * [enabled] - Defaults to true. A disabled indexer is saved without a test.
/// * [settings] - Setting name to value as text, using names from getIndexerDefinition. Omitted settings keep Prowlarr's defaults. Values are never echoed.
@BuiltValue()
abstract class IndexerCreate implements Built<IndexerCreate, IndexerCreateBuilder> {
  @BuiltValueField(wireName: r'definition')
  String get definition;

  @BuiltValueField(wireName: r'name')
  String? get name;

  /// Defaults to true. A disabled indexer is saved without a test.
  @BuiltValueField(wireName: r'enabled')
  bool? get enabled;

  /// Setting name to value as text, using names from getIndexerDefinition. Omitted settings keep Prowlarr's defaults. Values are never echoed.
  @BuiltValueField(wireName: r'settings')
  BuiltMap<String, String>? get settings;

  IndexerCreate._();

  factory IndexerCreate([void updates(IndexerCreateBuilder b)]) = _$IndexerCreate;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IndexerCreateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IndexerCreate> get serializer => _$IndexerCreateSerializer();
}

class _$IndexerCreateSerializer implements PrimitiveSerializer<IndexerCreate> {
  @override
  final Iterable<Type> types = const [IndexerCreate, _$IndexerCreate];

  @override
  final String wireName = r'IndexerCreate';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IndexerCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'definition';
    yield serializers.serialize(
      object.definition,
      specifiedType: const FullType(String),
    );
    if (object.name != null) {
      yield r'name';
      yield serializers.serialize(
        object.name,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.enabled != null) {
      yield r'enabled';
      yield serializers.serialize(
        object.enabled,
        specifiedType: const FullType.nullable(bool),
      );
    }
    if (object.settings != null) {
      yield r'settings';
      yield serializers.serialize(
        object.settings,
        specifiedType: const FullType.nullable(BuiltMap, [FullType(String), FullType(String)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    IndexerCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IndexerCreateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'definition':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.definition = valueDes;
          break;
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.name = valueDes;
          break;
        case r'enabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.enabled = valueDes;
          break;
        case r'settings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltMap, [FullType(String), FullType(String)]),
          ) as BuiltMap<String, String>?;
          if (valueDes == null) continue;
          result.settings.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  IndexerCreate deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IndexerCreateBuilder();
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


