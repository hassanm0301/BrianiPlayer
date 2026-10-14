// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_code_request.g.dart';

/// DeviceCodeRequest
///
/// Properties:
/// * [deviceName] 
@BuiltValue()
abstract class DeviceCodeRequest implements Built<DeviceCodeRequest, DeviceCodeRequestBuilder> {
  @BuiltValueField(wireName: r'deviceName')
  String get deviceName;

  DeviceCodeRequest._();

  factory DeviceCodeRequest([void updates(DeviceCodeRequestBuilder b)]) = _$DeviceCodeRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceCodeRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceCodeRequest> get serializer => _$DeviceCodeRequestSerializer();
}

class _$DeviceCodeRequestSerializer implements PrimitiveSerializer<DeviceCodeRequest> {
  @override
  final Iterable<Type> types = const [DeviceCodeRequest, _$DeviceCodeRequest];

  @override
  final String wireName = r'DeviceCodeRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceCodeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'deviceName';
    yield serializers.serialize(
      object.deviceName,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceCodeRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceCodeRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'deviceName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.deviceName = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceCodeRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceCodeRequestBuilder();
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


