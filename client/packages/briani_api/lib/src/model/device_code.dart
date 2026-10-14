// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_code.g.dart';

/// DeviceCode
///
/// Properties:
/// * [deviceSecret] 
/// * [userCode] 
/// * [expiresAt] 
/// * [pollIntervalSeconds] 
@BuiltValue()
abstract class DeviceCode implements Built<DeviceCode, DeviceCodeBuilder> {
  @BuiltValueField(wireName: r'deviceSecret')
  String get deviceSecret;

  @BuiltValueField(wireName: r'userCode')
  String get userCode;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'pollIntervalSeconds')
  int get pollIntervalSeconds;

  DeviceCode._();

  factory DeviceCode([void updates(DeviceCodeBuilder b)]) = _$DeviceCode;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceCodeBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceCode> get serializer => _$DeviceCodeSerializer();
}

class _$DeviceCodeSerializer implements PrimitiveSerializer<DeviceCode> {
  @override
  final Iterable<Type> types = const [DeviceCode, _$DeviceCode];

  @override
  final String wireName = r'DeviceCode';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceCode object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'deviceSecret';
    yield serializers.serialize(
      object.deviceSecret,
      specifiedType: const FullType(String),
    );
    yield r'userCode';
    yield serializers.serialize(
      object.userCode,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'pollIntervalSeconds';
    yield serializers.serialize(
      object.pollIntervalSeconds,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceCode object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceCodeBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'deviceSecret':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.deviceSecret = valueDes;
          break;
        case r'userCode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userCode = valueDes;
          break;
        case r'expiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        case r'pollIntervalSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.pollIntervalSeconds = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceCode deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceCodeBuilder();
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


