// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/download_source.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_create.g.dart';

/// DownloadCreate
///
/// Properties:
/// * [libraryId] 
/// * [source_] 
@BuiltValue()
abstract class DownloadCreate implements Built<DownloadCreate, DownloadCreateBuilder> {
  @BuiltValueField(wireName: r'libraryId')
  String get libraryId;

  @BuiltValueField(wireName: r'source')
  DownloadSource get source_;

  DownloadCreate._();

  factory DownloadCreate([void updates(DownloadCreateBuilder b)]) = _$DownloadCreate;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadCreateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadCreate> get serializer => _$DownloadCreateSerializer();
}

class _$DownloadCreateSerializer implements PrimitiveSerializer<DownloadCreate> {
  @override
  final Iterable<Type> types = const [DownloadCreate, _$DownloadCreate];

  @override
  final String wireName = r'DownloadCreate';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'libraryId';
    yield serializers.serialize(
      object.libraryId,
      specifiedType: const FullType(String),
    );
    yield r'source';
    yield serializers.serialize(
      object.source_,
      specifiedType: const FullType(DownloadSource),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DownloadCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadCreateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'libraryId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.libraryId = valueDes;
          break;
        case r'source':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadSource),
          ) as DownloadSource;
          result.source_.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DownloadCreate deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadCreateBuilder();
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


