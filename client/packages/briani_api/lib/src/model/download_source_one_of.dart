// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_source_one_of.g.dart';

/// DownloadSourceOneOf
///
/// Properties:
/// * [kind] 
/// * [value] 
@BuiltValue()
abstract class DownloadSourceOneOf implements Built<DownloadSourceOneOf, DownloadSourceOneOfBuilder> {
  @BuiltValueField(wireName: r'kind')
  DownloadSourceOneOfKindEnum get kind;
  // enum kindEnum {  discoveryResult,  };

  @BuiltValueField(wireName: r'value')
  String get value;

  DownloadSourceOneOf._();

  factory DownloadSourceOneOf([void updates(DownloadSourceOneOfBuilder b)]) = _$DownloadSourceOneOf;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadSourceOneOfBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadSourceOneOf> get serializer => _$DownloadSourceOneOfSerializer();
}

class _$DownloadSourceOneOfSerializer implements PrimitiveSerializer<DownloadSourceOneOf> {
  @override
  final Iterable<Type> types = const [DownloadSourceOneOf, _$DownloadSourceOneOf];

  @override
  final String wireName = r'DownloadSourceOneOf';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadSourceOneOf object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(DownloadSourceOneOfKindEnum),
    );
    yield r'value';
    yield serializers.serialize(
      object.value,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DownloadSourceOneOf object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadSourceOneOfBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadSourceOneOfKindEnum),
          ) as DownloadSourceOneOfKindEnum;
          result.kind = valueDes;
          break;
        case r'value':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.value = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DownloadSourceOneOf deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadSourceOneOfBuilder();
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


class DownloadSourceOneOfKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'discoveryResult')
  static const DownloadSourceOneOfKindEnum discoveryResult = _$downloadSourceOneOfKindEnum_discoveryResult;

  static Serializer<DownloadSourceOneOfKindEnum> get serializer => _$downloadSourceOneOfKindEnumSerializer;

  const DownloadSourceOneOfKindEnum._(String name): super(name);

  static BuiltSet<DownloadSourceOneOfKindEnum> get values => _$downloadSourceOneOfKindEnumValues;
  static DownloadSourceOneOfKindEnum valueOf(String name) => _$downloadSourceOneOfKindEnumValueOf(name);
}

