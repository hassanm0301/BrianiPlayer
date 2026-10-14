// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'service_health.g.dart';

/// ServiceHealth
///
/// Properties:
/// * [service] 
/// * [state] 
/// * [detail] 
/// * [checkedAt] 
@BuiltValue()
abstract class ServiceHealth implements Built<ServiceHealth, ServiceHealthBuilder> {
  @BuiltValueField(wireName: r'service')
  String get service;

  @BuiltValueField(wireName: r'state')
  ServiceHealthStateEnum get state;
  // enum stateEnum {  healthy,  degraded,  unavailable,  unknown,  };

  @BuiltValueField(wireName: r'detail')
  String? get detail;

  @BuiltValueField(wireName: r'checkedAt')
  DateTime get checkedAt;

  ServiceHealth._();

  factory ServiceHealth([void updates(ServiceHealthBuilder b)]) = _$ServiceHealth;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ServiceHealthBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ServiceHealth> get serializer => _$ServiceHealthSerializer();
}

class _$ServiceHealthSerializer implements PrimitiveSerializer<ServiceHealth> {
  @override
  final Iterable<Type> types = const [ServiceHealth, _$ServiceHealth];

  @override
  final String wireName = r'ServiceHealth';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ServiceHealth object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'service';
    yield serializers.serialize(
      object.service,
      specifiedType: const FullType(String),
    );
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(ServiceHealthStateEnum),
    );
    if (object.detail != null) {
      yield r'detail';
      yield serializers.serialize(
        object.detail,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'checkedAt';
    yield serializers.serialize(
      object.checkedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ServiceHealth object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ServiceHealthBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'service':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.service = valueDes;
          break;
        case r'state':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ServiceHealthStateEnum),
          ) as ServiceHealthStateEnum;
          result.state = valueDes;
          break;
        case r'detail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.detail = valueDes;
          break;
        case r'checkedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.checkedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ServiceHealth deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServiceHealthBuilder();
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


class ServiceHealthStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'healthy')
  static const ServiceHealthStateEnum healthy = _$serviceHealthStateEnum_healthy;
  @BuiltValueEnumConst(wireName: r'degraded')
  static const ServiceHealthStateEnum degraded = _$serviceHealthStateEnum_degraded;
  @BuiltValueEnumConst(wireName: r'unavailable')
  static const ServiceHealthStateEnum unavailable = _$serviceHealthStateEnum_unavailable;
  @BuiltValueEnumConst(wireName: r'unknown')
  static const ServiceHealthStateEnum unknown = _$serviceHealthStateEnum_unknown;

  static Serializer<ServiceHealthStateEnum> get serializer => _$serviceHealthStateEnumSerializer;

  const ServiceHealthStateEnum._(String name): super(name);

  static BuiltSet<ServiceHealthStateEnum> get values => _$serviceHealthStateEnumValues;
  static ServiceHealthStateEnum valueOf(String name) => _$serviceHealthStateEnumValueOf(name);
}

