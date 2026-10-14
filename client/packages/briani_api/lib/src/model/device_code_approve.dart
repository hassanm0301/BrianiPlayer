// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_code_approve.g.dart';

/// DeviceCodeApprove
///
/// Properties:
/// * [userCode] 
@BuiltValue()
abstract class DeviceCodeApprove implements Built<DeviceCodeApprove, DeviceCodeApproveBuilder> {
  @BuiltValueField(wireName: r'userCode')
  String get userCode;

  DeviceCodeApprove._();

  factory DeviceCodeApprove([void updates(DeviceCodeApproveBuilder b)]) = _$DeviceCodeApprove;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceCodeApproveBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceCodeApprove> get serializer => _$DeviceCodeApproveSerializer();
}

class _$DeviceCodeApproveSerializer implements PrimitiveSerializer<DeviceCodeApprove> {
  @override
  final Iterable<Type> types = const [DeviceCodeApprove, _$DeviceCodeApprove];

  @override
  final String wireName = r'DeviceCodeApprove';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceCodeApprove object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'userCode';
    yield serializers.serialize(
      object.userCode,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceCodeApprove object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceCodeApproveBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'userCode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userCode = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceCodeApprove deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceCodeApproveBuilder();
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


