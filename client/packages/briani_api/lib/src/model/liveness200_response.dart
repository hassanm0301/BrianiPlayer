// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'liveness200_response.g.dart';

/// Liveness200Response
///
/// Properties:
/// * [status] 
@BuiltValue()
abstract class Liveness200Response implements Built<Liveness200Response, Liveness200ResponseBuilder> {
  @BuiltValueField(wireName: r'status')
  Liveness200ResponseStatusEnum get status;
  // enum statusEnum {  ok,  unavailable,  };

  Liveness200Response._();

  factory Liveness200Response([void updates(Liveness200ResponseBuilder b)]) = _$Liveness200Response;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(Liveness200ResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Liveness200Response> get serializer => _$Liveness200ResponseSerializer();
}

class _$Liveness200ResponseSerializer implements PrimitiveSerializer<Liveness200Response> {
  @override
  final Iterable<Type> types = const [Liveness200Response, _$Liveness200Response];

  @override
  final String wireName = r'Liveness200Response';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Liveness200Response object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(Liveness200ResponseStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Liveness200Response object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required Liveness200ResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Liveness200ResponseStatusEnum),
          ) as Liveness200ResponseStatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Liveness200Response deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = Liveness200ResponseBuilder();
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


class Liveness200ResponseStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'ok')
  static const Liveness200ResponseStatusEnum ok = _$liveness200ResponseStatusEnum_ok;
  @BuiltValueEnumConst(wireName: r'unavailable')
  static const Liveness200ResponseStatusEnum unavailable = _$liveness200ResponseStatusEnum_unavailable;

  static Serializer<Liveness200ResponseStatusEnum> get serializer => _$liveness200ResponseStatusEnumSerializer;

  const Liveness200ResponseStatusEnum._(String name): super(name);

  static BuiltSet<Liveness200ResponseStatusEnum> get values => _$liveness200ResponseStatusEnumValues;
  static Liveness200ResponseStatusEnum valueOf(String name) => _$liveness200ResponseStatusEnumValueOf(name);
}

