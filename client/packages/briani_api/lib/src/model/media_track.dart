// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'media_track.g.dart';

/// MediaTrack
///
/// Properties:
/// * [id] 
/// * [kind] 
/// * [codec] 
/// * [language] 
/// * [title] 
/// * [default_] 
@BuiltValue()
abstract class MediaTrack implements Built<MediaTrack, MediaTrackBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'kind')
  MediaTrackKindEnum get kind;
  // enum kindEnum {  video,  audio,  subtitle,  };

  @BuiltValueField(wireName: r'codec')
  String? get codec;

  @BuiltValueField(wireName: r'language')
  String? get language;

  @BuiltValueField(wireName: r'title')
  String? get title;

  @BuiltValueField(wireName: r'default')
  bool? get default_;

  MediaTrack._();

  factory MediaTrack([void updates(MediaTrackBuilder b)]) = _$MediaTrack;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MediaTrackBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MediaTrack> get serializer => _$MediaTrackSerializer();
}

class _$MediaTrackSerializer implements PrimitiveSerializer<MediaTrack> {
  @override
  final Iterable<Type> types = const [MediaTrack, _$MediaTrack];

  @override
  final String wireName = r'MediaTrack';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MediaTrack object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(MediaTrackKindEnum),
    );
    if (object.codec != null) {
      yield r'codec';
      yield serializers.serialize(
        object.codec,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.language != null) {
      yield r'language';
      yield serializers.serialize(
        object.language,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.title != null) {
      yield r'title';
      yield serializers.serialize(
        object.title,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.default_ != null) {
      yield r'default';
      yield serializers.serialize(
        object.default_,
        specifiedType: const FullType(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    MediaTrack object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MediaTrackBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(MediaTrackKindEnum),
          ) as MediaTrackKindEnum;
          result.kind = valueDes;
          break;
        case r'codec':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.codec = valueDes;
          break;
        case r'language':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.language = valueDes;
          break;
        case r'title':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.title = valueDes;
          break;
        case r'default':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.default_ = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MediaTrack deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MediaTrackBuilder();
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


class MediaTrackKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'video')
  static const MediaTrackKindEnum video = _$mediaTrackKindEnum_video;
  @BuiltValueEnumConst(wireName: r'audio')
  static const MediaTrackKindEnum audio = _$mediaTrackKindEnum_audio;
  @BuiltValueEnumConst(wireName: r'subtitle')
  static const MediaTrackKindEnum subtitle = _$mediaTrackKindEnum_subtitle;

  static Serializer<MediaTrackKindEnum> get serializer => _$mediaTrackKindEnumSerializer;

  const MediaTrackKindEnum._(String name): super(name);

  static BuiltSet<MediaTrackKindEnum> get values => _$mediaTrackKindEnumValues;
  static MediaTrackKindEnum valueOf(String name) => _$mediaTrackKindEnumValueOf(name);
}

