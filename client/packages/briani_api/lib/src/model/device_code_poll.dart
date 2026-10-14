// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_code_poll.g.dart';

/// DeviceCodePoll
///
/// Properties:
/// * [deviceSecret] 
@BuiltValue()
abstract class DeviceCodePoll implements Built<DeviceCodePoll, DeviceCodePollBuilder> {
  @BuiltValueField(wireName: r'deviceSecret')
  String get deviceSecret;

  DeviceCodePoll._();

  factory DeviceCodePoll([void updates(DeviceCodePollBuilder b)]) = _$DeviceCodePoll;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceCodePollBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceCodePoll> get serializer => _$DeviceCodePollSerializer();
}

class _$DeviceCodePollSerializer implements PrimitiveSerializer<DeviceCodePoll> {
  @override
  final Iterable<Type> types = const [DeviceCodePoll, _$DeviceCodePoll];

  @override
  final String wireName = r'DeviceCodePoll';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceCodePoll object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'deviceSecret';
    yield serializers.serialize(
      object.deviceSecret,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceCodePoll object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceCodePollBuilder result,
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceCodePoll deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceCodePollBuilder();
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


