// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_pending.g.dart';

/// DevicePending
///
/// Properties:
/// * [state] 
/// * [retryAfterSeconds] 
@BuiltValue()
abstract class DevicePending implements Built<DevicePending, DevicePendingBuilder> {
  @BuiltValueField(wireName: r'state')
  DevicePendingStateEnum get state;
  // enum stateEnum {  pending,  expired,  denied,  };

  @BuiltValueField(wireName: r'retryAfterSeconds')
  int? get retryAfterSeconds;

  DevicePending._();

  factory DevicePending([void updates(DevicePendingBuilder b)]) = _$DevicePending;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DevicePendingBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DevicePending> get serializer => _$DevicePendingSerializer();
}

class _$DevicePendingSerializer implements PrimitiveSerializer<DevicePending> {
  @override
  final Iterable<Type> types = const [DevicePending, _$DevicePending];

  @override
  final String wireName = r'DevicePending';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DevicePending object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(DevicePendingStateEnum),
    );
    if (object.retryAfterSeconds != null) {
      yield r'retryAfterSeconds';
      yield serializers.serialize(
        object.retryAfterSeconds,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    DevicePending object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DevicePendingBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'state':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DevicePendingStateEnum),
          ) as DevicePendingStateEnum;
          result.state = valueDes;
          break;
        case r'retryAfterSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.retryAfterSeconds = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DevicePending deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DevicePendingBuilder();
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


class DevicePendingStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'pending')
  static const DevicePendingStateEnum pending = _$devicePendingStateEnum_pending;
  @BuiltValueEnumConst(wireName: r'expired')
  static const DevicePendingStateEnum expired = _$devicePendingStateEnum_expired;
  @BuiltValueEnumConst(wireName: r'denied')
  static const DevicePendingStateEnum denied = _$devicePendingStateEnum_denied;

  static Serializer<DevicePendingStateEnum> get serializer => _$devicePendingStateEnumSerializer;

  const DevicePendingStateEnum._(String name): super(name);

  static BuiltSet<DevicePendingStateEnum> get values => _$devicePendingStateEnumValues;
  static DevicePendingStateEnum valueOf(String name) => _$devicePendingStateEnumValueOf(name);
}

