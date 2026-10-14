// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_code_preview.g.dart';

/// DeviceCodePreview
///
/// Properties:
/// * [deviceName] 
/// * [expiresAt] 
@BuiltValue()
abstract class DeviceCodePreview implements Built<DeviceCodePreview, DeviceCodePreviewBuilder> {
  @BuiltValueField(wireName: r'deviceName')
  String get deviceName;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  DeviceCodePreview._();

  factory DeviceCodePreview([void updates(DeviceCodePreviewBuilder b)]) = _$DeviceCodePreview;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceCodePreviewBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceCodePreview> get serializer => _$DeviceCodePreviewSerializer();
}

class _$DeviceCodePreviewSerializer implements PrimitiveSerializer<DeviceCodePreview> {
  @override
  final Iterable<Type> types = const [DeviceCodePreview, _$DeviceCodePreview];

  @override
  final String wireName = r'DeviceCodePreview';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceCodePreview object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'deviceName';
    yield serializers.serialize(
      object.deviceName,
      specifiedType: const FullType(String),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceCodePreview object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceCodePreviewBuilder result,
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
        case r'expiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceCodePreview deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceCodePreviewBuilder();
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


