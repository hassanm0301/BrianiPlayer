// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'provider.g.dart';

/// Provider
///
/// Properties:
/// * [id] 
/// * [name] 
/// * [enabled] 
/// * [supportsSearch] 
/// * [supportsRecent] 
/// * [categories] 
/// * [state] 
/// * [warning] 
@BuiltValue()
abstract class Provider implements Built<Provider, ProviderBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'enabled')
  bool get enabled;

  @BuiltValueField(wireName: r'supportsSearch')
  bool get supportsSearch;

  @BuiltValueField(wireName: r'supportsRecent')
  bool get supportsRecent;

  @BuiltValueField(wireName: r'categories')
  BuiltList<int> get categories;

  @BuiltValueField(wireName: r'state')
  ProviderStateEnum get state;
  // enum stateEnum {  healthy,  degraded,  unavailable,  unknown,  };

  @BuiltValueField(wireName: r'warning')
  String? get warning;

  Provider._();

  factory Provider([void updates(ProviderBuilder b)]) = _$Provider;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ProviderBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Provider> get serializer => _$ProviderSerializer();
}

class _$ProviderSerializer implements PrimitiveSerializer<Provider> {
  @override
  final Iterable<Type> types = const [Provider, _$Provider];

  @override
  final String wireName = r'Provider';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Provider object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'enabled';
    yield serializers.serialize(
      object.enabled,
      specifiedType: const FullType(bool),
    );
    yield r'supportsSearch';
    yield serializers.serialize(
      object.supportsSearch,
      specifiedType: const FullType(bool),
    );
    yield r'supportsRecent';
    yield serializers.serialize(
      object.supportsRecent,
      specifiedType: const FullType(bool),
    );
    yield r'categories';
    yield serializers.serialize(
      object.categories,
      specifiedType: const FullType(BuiltList, [FullType(int)]),
    );
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(ProviderStateEnum),
    );
    if (object.warning != null) {
      yield r'warning';
      yield serializers.serialize(
        object.warning,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    Provider object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ProviderBuilder result,
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
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'enabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.enabled = valueDes;
          break;
        case r'supportsSearch':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.supportsSearch = valueDes;
          break;
        case r'supportsRecent':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.supportsRecent = valueDes;
          break;
        case r'categories':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(int)]),
          ) as BuiltList<int>;
          result.categories.replace(valueDes);
          break;
        case r'state':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ProviderStateEnum),
          ) as ProviderStateEnum;
          result.state = valueDes;
          break;
        case r'warning':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.warning = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Provider deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ProviderBuilder();
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


class ProviderStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'healthy')
  static const ProviderStateEnum healthy = _$providerStateEnum_healthy;
  @BuiltValueEnumConst(wireName: r'degraded')
  static const ProviderStateEnum degraded = _$providerStateEnum_degraded;
  @BuiltValueEnumConst(wireName: r'unavailable')
  static const ProviderStateEnum unavailable = _$providerStateEnum_unavailable;
  @BuiltValueEnumConst(wireName: r'unknown')
  static const ProviderStateEnum unknown = _$providerStateEnum_unknown;

  static Serializer<ProviderStateEnum> get serializer => _$providerStateEnumSerializer;

  const ProviderStateEnum._(String name): super(name);

  static BuiltSet<ProviderStateEnum> get values => _$providerStateEnumValues;
  static ProviderStateEnum valueOf(String name) => _$providerStateEnumValueOf(name);
}

