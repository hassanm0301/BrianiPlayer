// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_source_one_of2.g.dart';

/// DownloadSourceOneOf2
///
/// Properties:
/// * [kind] 
/// * [value] 
@BuiltValue()
abstract class DownloadSourceOneOf2 implements Built<DownloadSourceOneOf2, DownloadSourceOneOf2Builder> {
  @BuiltValueField(wireName: r'kind')
  DownloadSourceOneOf2KindEnum get kind;
  // enum kindEnum {  torrentUpload,  };

  @BuiltValueField(wireName: r'value')
  String get value;

  DownloadSourceOneOf2._();

  factory DownloadSourceOneOf2([void updates(DownloadSourceOneOf2Builder b)]) = _$DownloadSourceOneOf2;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadSourceOneOf2Builder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadSourceOneOf2> get serializer => _$DownloadSourceOneOf2Serializer();
}

class _$DownloadSourceOneOf2Serializer implements PrimitiveSerializer<DownloadSourceOneOf2> {
  @override
  final Iterable<Type> types = const [DownloadSourceOneOf2, _$DownloadSourceOneOf2];

  @override
  final String wireName = r'DownloadSourceOneOf2';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadSourceOneOf2 object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(DownloadSourceOneOf2KindEnum),
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
    DownloadSourceOneOf2 object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadSourceOneOf2Builder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadSourceOneOf2KindEnum),
          ) as DownloadSourceOneOf2KindEnum;
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
  DownloadSourceOneOf2 deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadSourceOneOf2Builder();
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


class DownloadSourceOneOf2KindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'torrentUpload')
  static const DownloadSourceOneOf2KindEnum torrentUpload = _$downloadSourceOneOf2KindEnum_torrentUpload;

  static Serializer<DownloadSourceOneOf2KindEnum> get serializer => _$downloadSourceOneOf2KindEnumSerializer;

  const DownloadSourceOneOf2KindEnum._(String name): super(name);

  static BuiltSet<DownloadSourceOneOf2KindEnum> get values => _$downloadSourceOneOf2KindEnumValues;
  static DownloadSourceOneOf2KindEnum valueOf(String name) => _$downloadSourceOneOf2KindEnumValueOf(name);
}

