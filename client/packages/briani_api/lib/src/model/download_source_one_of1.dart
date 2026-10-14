// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_source_one_of1.g.dart';

/// DownloadSourceOneOf1
///
/// Properties:
/// * [kind] 
/// * [value] 
@BuiltValue()
abstract class DownloadSourceOneOf1 implements Built<DownloadSourceOneOf1, DownloadSourceOneOf1Builder> {
  @BuiltValueField(wireName: r'kind')
  DownloadSourceOneOf1KindEnum get kind;
  // enum kindEnum {  magnet,  };

  @BuiltValueField(wireName: r'value')
  String get value;

  DownloadSourceOneOf1._();

  factory DownloadSourceOneOf1([void updates(DownloadSourceOneOf1Builder b)]) = _$DownloadSourceOneOf1;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadSourceOneOf1Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadSourceOneOf1> get serializer => _$DownloadSourceOneOf1Serializer();
}

class _$DownloadSourceOneOf1Serializer implements PrimitiveSerializer<DownloadSourceOneOf1> {
  @override
  final Iterable<Type> types = const [DownloadSourceOneOf1, _$DownloadSourceOneOf1];

  @override
  final String wireName = r'DownloadSourceOneOf1';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadSourceOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(DownloadSourceOneOf1KindEnum),
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
    DownloadSourceOneOf1 object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadSourceOneOf1Builder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadSourceOneOf1KindEnum),
          ) as DownloadSourceOneOf1KindEnum;
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
  DownloadSourceOneOf1 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadSourceOneOf1Builder();
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


class DownloadSourceOneOf1KindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'magnet')
  static const DownloadSourceOneOf1KindEnum magnet = _$downloadSourceOneOf1KindEnum_magnet;

  static Serializer<DownloadSourceOneOf1KindEnum> get serializer => _$downloadSourceOneOf1KindEnumSerializer;

  const DownloadSourceOneOf1KindEnum._(String name): super(name);

  static BuiltSet<DownloadSourceOneOf1KindEnum> get values => _$downloadSourceOneOf1KindEnumValues;
  static DownloadSourceOneOf1KindEnum valueOf(String name) => _$downloadSourceOneOf1KindEnumValueOf(name);
}

