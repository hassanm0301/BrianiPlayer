// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/download_source_one_of.dart';
import 'package:briani_api/src/model/download_source_one_of2.dart';
import 'package:briani_api/src/model/download_source_one_of1.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:one_of/one_of.dart';

part 'download_source.g.dart';

/// Exactly one tagged source. A value is not an arbitrary fetch URL.
///
/// Properties:
/// * [kind] 
/// * [value] 
@BuiltValue()
abstract class DownloadSource implements Built<DownloadSource, DownloadSourceBuilder> {
  /// One Of [DownloadSourceOneOf], [DownloadSourceOneOf1], [DownloadSourceOneOf2]
  OneOf get oneOf;

  DownloadSource._();

  factory DownloadSource([void updates(DownloadSourceBuilder b)]) = _$DownloadSource;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadSourceBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadSource> get serializer => _$DownloadSourceSerializer();
}

class _$DownloadSourceSerializer implements PrimitiveSerializer<DownloadSource> {
  @override
  final Iterable<Type> types = const [DownloadSource, _$DownloadSource];

  @override
  final String wireName = r'DownloadSource';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadSource object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
  }

  @override
  Object serialize(
    Serializers serializers,
    DownloadSource object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final oneOf = object.oneOf;
    return serializers.serialize(oneOf.value, specifiedType: FullType(oneOf.valueType))!;
  }

  @override
  DownloadSource deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadSourceBuilder();
    Object? oneOfDataSrc;
    final targetType = const FullType(OneOf, [FullType(DownloadSourceOneOf), FullType(DownloadSourceOneOf1), FullType(DownloadSourceOneOf2), ]);
    oneOfDataSrc = serialized;
    result.oneOf = serializers.deserialize(oneOfDataSrc, specifiedType: targetType) as OneOf;
    return result.build();
  }
}


class DownloadSourceKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'torrentUpload')
  static const DownloadSourceKindEnum torrentUpload = _$downloadSourceKindEnum_torrentUpload;

  static Serializer<DownloadSourceKindEnum> get serializer => _$downloadSourceKindEnumSerializer;

  const DownloadSourceKindEnum._(String name): super(name);

  static BuiltSet<DownloadSourceKindEnum> get values => _$downloadSourceKindEnumValues;
  static DownloadSourceKindEnum valueOf(String name) => _$downloadSourceKindEnumValueOf(name);
}

