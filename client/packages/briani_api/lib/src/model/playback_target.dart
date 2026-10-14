// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'playback_target.g.dart';

/// PlaybackTarget
///
/// Properties:
/// * [kind] 
/// * [id] 
@BuiltValue()
abstract class PlaybackTarget implements Built<PlaybackTarget, PlaybackTargetBuilder> {
  @BuiltValueField(wireName: r'kind')
  PlaybackTargetKindEnum get kind;
  // enum kindEnum {  media,  downloadFile,  };

  @BuiltValueField(wireName: r'id')
  String get id;

  PlaybackTarget._();

  factory PlaybackTarget([void updates(PlaybackTargetBuilder b)]) = _$PlaybackTarget;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PlaybackTargetBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PlaybackTarget> get serializer => _$PlaybackTargetSerializer();
}

class _$PlaybackTargetSerializer implements PrimitiveSerializer<PlaybackTarget> {
  @override
  final Iterable<Type> types = const [PlaybackTarget, _$PlaybackTarget];

  @override
  final String wireName = r'PlaybackTarget';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PlaybackTarget object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(PlaybackTargetKindEnum),
    );
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PlaybackTarget object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PlaybackTargetBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(PlaybackTargetKindEnum),
          ) as PlaybackTargetKindEnum;
          result.kind = valueDes;
          break;
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PlaybackTarget deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PlaybackTargetBuilder();
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


class PlaybackTargetKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'media')
  static const PlaybackTargetKindEnum media = _$playbackTargetKindEnum_media;
  @BuiltValueEnumConst(wireName: r'downloadFile')
  static const PlaybackTargetKindEnum downloadFile = _$playbackTargetKindEnum_downloadFile;

  static Serializer<PlaybackTargetKindEnum> get serializer => _$playbackTargetKindEnumSerializer;

  const PlaybackTargetKindEnum._(String name): super(name);

  static BuiltSet<PlaybackTargetKindEnum> get values => _$playbackTargetKindEnumValues;
  static PlaybackTargetKindEnum valueOf(String name) => _$playbackTargetKindEnumValueOf(name);
}

